#!/usr/bin/env node
/**
 * TrustLint CLI — offline compliance linter for AI agents.
 *
 * Usage:
 *   trustlint check <file>          Scan a file for compliance violations
 *   trustlint check --text "..."    Check a string
 *   trustlint rules list            Show all loaded rules
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { Command } from "commander";
import { jurisdictionApplies, TrustLintEngine, type LintResult, type Rule } from "./engine.js";
import { scanUrl } from "./scan-url.js";

// Single source of truth for the version: package.json. A hardcoded constant
// here read 2.0.0 while package.json said 2.0.1, so `trustlint --version`
// reported a release that was never published. The Python side hit the same
// bug and fixed it the same way — see the note in setup.py: the CLI and the
// published artifact must agree.
//
// dist/cli.js sits one level below the package root, so "../package.json"
// resolves correctly both in this repo and inside node_modules/trustlint.
const VERSION: string = require("../package.json").version;

// ANSI colors (no chalk dependency issues with ESM/CJS)
const RED = "\x1b[91m";
const YELLOW = "\x1b[93m";
const GREEN = "\x1b[92m";
const CYAN = "\x1b[96m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

const SEVERITY_COLORS: Record<string, string> = {
  critical: RED,
  high: RED,
  medium: YELLOW,
  low: DIM,
};

function printResult(result: LintResult, verbose: boolean): void {
  if (result.clean) {
    console.log(
      `\n${GREEN}${BOLD}✅ No violations found${RESET} (${result.rulesEvaluated} rules evaluated)`
    );
    return;
  }

  console.log(`\n${BOLD}TrustLint Report${RESET}`);
  console.log("─".repeat(60));

  for (const v of result.violations) {
    const color = SEVERITY_COLORS[v.severity] ?? "";
    console.log(
      `\n${color}${BOLD}[${v.severity.toUpperCase()}]${RESET} ${BOLD}${v.ruleId}${RESET}`
    );
    console.log(`  ${v.title}`);
    console.log(
      `  ${DIM}Jurisdiction: ${v.jurisdiction} | Matched: ${v.patternMatched}${RESET}`
    );
    if (verbose && v.citation) {
      const cit =
        v.citation.length > 120 ? v.citation.slice(0, 120) + "…" : v.citation;
      console.log(`  ${DIM}Citation: ${cit}${RESET}`);
    }
    if (verbose && v.remediation) {
      const rem =
        v.remediation.length > 120
          ? v.remediation.slice(0, 120) + "…"
          : v.remediation;
      console.log(`  ${CYAN}Remediation: ${rem}${RESET}`);
    }
  }

  const criticalCount = result.violations.filter(
    (v) => v.severity === "critical" || v.severity === "high"
  ).length;
  const warnCount = result.violations.filter(
    (v) => v.severity === "medium" || v.severity === "low"
  ).length;

  console.log(`\n${"─".repeat(60)}`);
  console.log(
    `${RED}${BOLD}${criticalCount} critical/high${RESET}, ` +
      `${YELLOW}${warnCount} medium/low${RESET} ` +
      `(${result.rulesEvaluated} rules evaluated)`
  );
}

const program = new Command();

program
  .name("trustlint")
  .description("TrustLint: offline compliance linter for AI agents")
  .version(VERSION)
  .option("--rules-dir <path>", "Path to rules directory");

program
  .command("check [target]")
  .description("Check text or file for compliance violations")
  .option("-t, --text <text>", "Text string to check")
  .option(
    "-j, --jurisdiction <code>",
    "Where the end user is (EU, US, US-CA, GLOBAL). Runs that jurisdiction's rules, its sub-jurisdictions (US includes US-CA) and GLOBAL rules."
  )
  .option(
    "--direction <direction>",
    "input = text a user sends, output = text the AI produces. Rules scoped to user input or AI output then run only in their direction. Default: all rules."
  )
  .option("-v, --verbose", "Show citations and remediation")
  .action(
    (
      target: string | undefined,
      opts: { text?: string; jurisdiction?: string; direction?: string; verbose?: boolean }
    ) => {
      if (opts.direction && !["input", "output"].includes(opts.direction.toLowerCase())) {
        console.error(`${RED}Error: --direction must be input or output${RESET}`);
        process.exit(2);
      }
      const rulesDir = program.opts().rulesDir;
      const engine = new TrustLintEngine(rulesDir);

      if (engine.rules.length === 0) {
        console.error(`${YELLOW}⚠ No rules loaded. Pass --rules-dir${RESET}`);
        process.exit(2);
      }

      let inputText: string;

      if (opts.text) {
        inputText = opts.text;
      } else if (target) {
        if (!fs.existsSync(target)) {
          console.error(`${RED}Error: file not found: ${target}${RESET}`);
          process.exit(2);
        }
        inputText = fs.readFileSync(target, "utf-8");
      } else if (!process.stdin.isTTY) {
        // Piped input, as the Python CLI accepts: echo "..." | trustlint check
        inputText = fs.readFileSync(0, "utf-8");
      } else {
        console.error(
          `${RED}Error: provide --text, a file path, or pipe stdin${RESET}`
        );
        process.exit(2);
      }

      const result = engine.check(inputText, opts.jurisdiction, opts.direction);
      printResult(result, opts.verbose ?? false);

      if (result.hasCritical) {
        process.exit(1);
      }
    }
  );

const rulesCmd = program
  .command("rules")
  .description("Manage compliance rules");

rulesCmd
  .command("list")
  .description("List all loaded compliance rules")
  .option(
    "-j, --jurisdiction <code>",
    "Rules that apply in this jurisdiction (includes sub-jurisdictions and GLOBAL)"
  )
  .action((opts: { jurisdiction?: string }) => {
    const rulesDir = program.opts().rulesDir;
    const engine = new TrustLintEngine(rulesDir);

    if (engine.rules.length === 0) {
      console.log(`${YELLOW}⚠ No rules loaded.${RESET}`);
      return;
    }

    let applicable: Rule[] = engine.rules;
    if (opts.jurisdiction) {
      applicable = engine.rules.filter((r) => jurisdictionApplies(r.jurisdiction, opts.jurisdiction));
    }

    console.log(`\n${BOLD}Loaded Rules (${applicable.length})${RESET}`);
    console.log("─".repeat(70));
    console.log(
      `${"ID".padEnd(40)} ${"Jurisdiction".padEnd(8)} ${"Severity".padEnd(10)} Category`
    );
    console.log("─".repeat(70));

    const sorted = [...applicable].sort((a, b) =>
      `${a.jurisdiction}${a.severity}${a.id}`.localeCompare(
        `${b.jurisdiction}${b.severity}${b.id}`
      )
    );

    for (const rule of sorted) {
      const color = SEVERITY_COLORS[rule.severity] ?? "";
      console.log(
        `${rule.id.padEnd(40)} ${rule.jurisdiction.padEnd(8)} ` +
          `${color}${rule.severity.padEnd(10)}${RESET} ${rule.category}`
      );
    }

    const jurisdictions = new Set(applicable.map((r) => r.jurisdiction));
    console.log(
      `\n${DIM}${applicable.length} rules across ${jurisdictions.size} jurisdictions${RESET}`
    );
  });

rulesCmd
  .command("update")
  .description("Explain how to update the rule set (it ships inside the package)")
  .action(async () => {
    const os = await import("node:os");
    console.log("The rule set ships inside the trustlint package. To update it:");
    console.log("  npm install trustlint@latest");
    const homeRules = path.join(os.homedir(), ".trustlint", "rules");
    if (fs.existsSync(homeRules)) {
      console.log(
        `${DIM}${homeRules} is no longer read (an older copy downloaded by this command); you can delete it.${RESET}`
      );
    }
  });

program
  .command("scan [target]")
  .description("Run the hosted ComplyEdge check (POST /v1/check), which writes an audit record")
  .option("-t, --text <text>", "Text string to check")
  .option(
    "--api-key <key>",
    "API key for the hosted check (writes an audit record)",
    process.env.COMPLYEDGE_API_KEY
  )
  .action(
    async (
      target: string | undefined,
      opts: { text?: string; apiKey?: string }
    ) => {
      let inputText: string;

      if (opts.text) {
        inputText = opts.text;
      } else if (target) {
        if (!fs.existsSync(target)) {
          console.error(`${RED}Error: file not found: ${target}${RESET}`);
          process.exit(2);
        }
        inputText = fs.readFileSync(target, "utf-8");
      } else {
        console.error(
          `${RED}Error: provide --text or a file path${RESET}`
        );
        process.exit(2);
      }

      if (!opts.apiKey) {
        console.error(
          `${YELLOW}⚠ No API key. Set COMPLYEDGE_API_KEY or --api-key.${RESET}`
        );
        console.error(`${DIM}Falling back to offline regex check.${RESET}`);
        const rulesDir = program.opts().rulesDir;
        const engine = new TrustLintEngine(rulesDir);
        const result = engine.check(inputText);
        printResult(result, true);
        if (result.hasCritical) process.exit(1);
        return;
      }

      try {
        const response = await fetch(scanUrl(opts.apiKey), {
          method: "POST",
          headers: {
            Authorization: `Bearer ${opts.apiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            text: inputText,
            jurisdiction: "EU",
            direction: "output",
          }),
        });

        const data = (await response.json()) as {
          allowed?: boolean;
          violations?: Array<{
            rule_id?: string;
            severity?: string;
            rule_description?: string;
          }>;
          latency_ms?: number;
        };

        if (data.allowed) {
          console.log(
            `\n${GREEN}${BOLD}✅ PASS${RESET}: no violations (${data.latency_ms}ms, API)`
          );
        } else {
          const violations = data.violations ?? [];
          console.log(
            `\n${RED}${BOLD}❌ BLOCKED${RESET}: ${violations.length} violation(s) (${data.latency_ms}ms, API)`
          );
          for (const v of violations) {
            console.log(
              `  ${RED}[${(v.severity ?? "?").toUpperCase()}]${RESET} ${v.rule_id ?? "?"}`
            );
            if (v.rule_description) {
              console.log(
                `    ${(v.rule_description ?? "").slice(0, 100)}`
              );
            }
          }
          process.exit(1);
        }
      } catch (e) {
        console.error(
          `${YELLOW}⚠ API unreachable, falling back to offline check${RESET}`
        );
        const rulesDir = program.opts().rulesDir;
        const engine = new TrustLintEngine(rulesDir);
        const result = engine.check(inputText);
        printResult(result, true);
        if (result.hasCritical) process.exit(1);
      }
    }
  );

program.parse();
