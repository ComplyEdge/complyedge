#!/usr/bin/env node
/**
 * TrustLint CLI — offline compliance linter for AI agents.
 *
 * Usage:
 *   trustlint check <file>          Scan a file for compliance violations
 *   trustlint check --text "..."    Check a string
 *   trustlint rules list            Show all loaded rules
 *   trustlint init                  Create .trustlint.yaml config
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { Command } from "commander";
import { TrustLintEngine, type LintResult, type Rule } from "./engine.js";

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
  .description("TrustLint — offline compliance linter for AI agents")
  .version(VERSION)
  .option("--rules-dir <path>", "Path to rules directory");

program
  .command("check [target]")
  .description("Check text or file for compliance violations")
  .option("-t, --text <text>", "Text string to check")
  .option("-j, --jurisdiction <code>", "Filter rules by jurisdiction (EU, US, GLOBAL)")
  .option("-v, --verbose", "Show citations and remediation")
  .action(
    (
      target: string | undefined,
      opts: { text?: string; jurisdiction?: string; verbose?: boolean }
    ) => {
      const rulesDir = program.opts().rulesDir;
      const engine = new TrustLintEngine(rulesDir);

      if (engine.rules.length === 0) {
        console.error(
          `${YELLOW}⚠ No rules loaded. Run 'trustlint init' or use --rules-dir${RESET}`
        );
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
      } else {
        console.error(
          `${RED}Error: provide --text or a file path${RESET}`
        );
        process.exit(2);
      }

      const result = engine.check(inputText, opts.jurisdiction);
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
  .option("-j, --jurisdiction <code>", "Filter by jurisdiction")
  .action((opts: { jurisdiction?: string }) => {
    const rulesDir = program.opts().rulesDir;
    const engine = new TrustLintEngine(rulesDir);

    if (engine.rules.length === 0) {
      console.log(`${YELLOW}⚠ No rules loaded.${RESET}`);
      return;
    }

    let applicable: Rule[] = engine.rules;
    if (opts.jurisdiction) {
      applicable = engine.rules.filter(
        (r) => r.jurisdiction.toUpperCase() === opts.jurisdiction!.toUpperCase()
      );
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

program
  .command("init")
  .description("Create a .trustlint.yaml config in the current directory")
  .option("-f, --force", "Overwrite existing config")
  .action((opts: { force?: boolean }) => {
    const configPath = path.join(process.cwd(), ".trustlint.yaml");

    if (fs.existsSync(configPath) && !opts.force) {
      console.log(
        `${YELLOW}⚠ .trustlint.yaml already exists. Use --force to overwrite.${RESET}`
      );
      return;
    }

    const configContent = `# TrustLint Configuration
# See: https://github.com/ComplyEdge/complyedge

# Rules directory (default: auto-detect from repo or ~/.trustlint/rules/)
# rules_dir: ./rules/regulations

# Default jurisdiction filter (optional)
# jurisdiction: EU

# Severity threshold — only report violations at this level or above
# severity_threshold: medium

# Files to check (glob patterns)
# include:
#   - "**/*.py"
#   - "**/*.ts"
#   - "**/*.yaml"

# Files to skip
# exclude:
#   - "node_modules/**"
#   - ".venv/**"
`;

    fs.writeFileSync(configPath, configContent, "utf-8");
    console.log(`${GREEN}✅ Created .trustlint.yaml${RESET}`);
  });

rulesCmd
  .command("update")
  .description("Download the latest rule corpus from GitHub releases")
  .action(async () => {
    const os = await import("node:os");
    const { execSync } = await import("node:child_process");

    const homeRules = path.join(os.homedir(), ".trustlint", "rules");
    const rulesReleaseRepo = "ComplyEdge/complyedge";
    const apiUrl = `https://api.github.com/repos/${rulesReleaseRepo}/releases/latest`;

    console.log(`${BOLD}Updating rules from GitHub...${RESET}`);

    try {
      const headers: Record<string, string> = {
        "User-Agent": "trustlint-cli",
        Accept: "application/vnd.github.v3+json",
      };
      const token = process.env.GITHUB_TOKEN;
      if (token) {
        headers["Authorization"] = `Bearer ${token}`;
      }

      // Fetch latest release metadata
      const releaseRes = await fetch(apiUrl, { headers });
      if (!releaseRes.ok) {
        throw new Error(`GitHub API returned ${releaseRes.status}`);
      }
      const release = (await releaseRes.json()) as {
        tag_name?: string;
        tarball_url?: string;
      };
      const tag = release.tag_name ?? "unknown";
      const tarballUrl = release.tarball_url;
      if (!tarballUrl) {
        console.error(`${RED}Error: no tarball_url in release${RESET}`);
        process.exit(2);
      }

      console.log(`  Latest release: ${tag}`);

      // Download tarball
      const tarballRes = await fetch(tarballUrl, { headers, redirect: "follow" });
      if (!tarballRes.ok) {
        throw new Error(`Tarball download failed: ${tarballRes.status}`);
      }
      const tarballBuf = Buffer.from(await tarballRes.arrayBuffer());

      // Write to temp file and extract YAML rules
      const tmpDir = os.tmpdir();
      const tmpTar = path.join(tmpDir, "trustlint-rules.tar.gz");
      fs.writeFileSync(tmpTar, tarballBuf);

      // Ensure destination exists
      fs.mkdirSync(homeRules, { recursive: true });

      // Extract only rules/regulations/**/*.yaml from the tarball
      const tmpExtract = path.join(tmpDir, "trustlint-extract");
      fs.mkdirSync(tmpExtract, { recursive: true });
      execSync(`tar xzf "${tmpTar}" -C "${tmpExtract}"`, { stdio: "pipe" });

      // Find and copy rule YAML files
      let copied = 0;
      function walkDir(dir: string): void {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const full = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            walkDir(full);
          } else if (entry.name.endsWith(".yaml")) {
            const idx = full.indexOf("/rules/regulations/");
            if (idx !== -1) {
              const relative = full.slice(idx + "/rules/regulations/".length);
              const dest = path.join(homeRules, relative);
              fs.mkdirSync(path.dirname(dest), { recursive: true });
              fs.copyFileSync(full, dest);
              copied++;
            }
          }
        }
      }
      walkDir(tmpExtract);

      // Cleanup
      fs.rmSync(tmpTar, { force: true });
      fs.rmSync(tmpExtract, { recursive: true, force: true });

      console.log(
        `${GREEN}✅ Updated ${copied} rules to ~/.trustlint/rules/ (release ${tag})${RESET}`
      );
    } catch (e) {
      console.error(
        `${RED}Error updating rules: ${e instanceof Error ? e.message : e}${RESET}`
      );
      process.exit(2);
    }
  });

program
  .command("scan [target]")
  .description("Run Tier 2 LLM compliance analysis via ComplyEdge API")
  .option("-t, --text <text>", "Text string to check")
  .option(
    "--api-key <key>",
    "API key for Tier 2 LLM analysis",
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
        const response = await fetch("https://api.complyedge.io/v1/check", {
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
            `\n${GREEN}${BOLD}✅ PASS${RESET} — no violations (${data.latency_ms}ms, API)`
          );
        } else {
          const violations = data.violations ?? [];
          console.log(
            `\n${RED}${BOLD}❌ BLOCKED${RESET} — ${violations.length} violation(s) (${data.latency_ms}ms, API)`
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
