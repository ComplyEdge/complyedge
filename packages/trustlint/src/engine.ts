/**
 * TrustLint compliance engine — loads YAML rules and runs Tier 1 regex checks offline.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import * as yaml from "js-yaml";

export interface RulePattern {
  pattern: string;
  description: string;
  flags: string;
}

export interface Rule {
  id: string;
  title: string;
  jurisdiction: string;
  severity: string;
  description: string;
  category: string;
  effectiveDate: string;
  citation: string;
  remediationMessage: string;
  regexPatterns: RulePattern[];
  /** all | user_input | ai_output */
  detectionScope: string;
}

export interface Violation {
  ruleId: string;
  title: string;
  severity: string;
  jurisdiction: string;
  description: string;
  citation: string;
  patternMatched: string;
  remediation: string;
}

export interface LintResult {
  text: string;
  violations: Violation[];
  rulesEvaluated: number;
  hasCritical: boolean;
  clean: boolean;
}

function parseRuleFile(filePath: string): Rule | null {
  const content = fs.readFileSync(filePath, "utf-8");
  const data = yaml.load(content) as Record<string, any>;

  if (!data || typeof data !== "object" || !data.id) {
    return null;
  }

  const patterns: RulePattern[] = [];
  for (const cond of data.conditions ?? []) {
    const condType = cond.type ?? "";

    if (condType === "regex") {
      {
        const norm = normalizePattern(String(cond.value), cond.flags ?? "");
        patterns.push({
          pattern: norm.pattern,
          description: cond.description ?? "",
          flags: norm.flags,
        });
      }
    } else if (condType === "hybrid_detection") {
      const tier1 = cond.tier1_config ?? {};
      for (const rp of tier1.risk_flag_patterns ?? []) {
        {
          const norm = normalizePattern(String(rp.pattern), rp.flags ?? "");
          patterns.push({
            pattern: norm.pattern,
            description: rp.description ?? "",
            flags: norm.flags,
          });
        }
      }
    }
  }

  if (patterns.length === 0) {
    return null;
  }

  const source = data.source ?? {};
  let citation = source.citation ?? "";
  if (!citation) {
    const citations = source.citations ?? [];
    citation = citations[0] ?? "";
  }
  if (!citation) {
    // Rules that rest on no single legal article (an industry standard, a
    // detection control) carry provision_label instead, which says so. Every
    // finding names its source rather than an empty citation.
    citation = source.provision_label ?? "";
  }

  const remediation = data.remediation ?? {};
  let remediationMsg = "";
  if (typeof remediation === "object") {
    remediationMsg = remediation.message ?? "";
  } else if (typeof remediation === "string") {
    remediationMsg = remediation;
  }

  return {
    id: data.id,
    title: data.title ?? (data.description ?? "").slice(0, 60),
    jurisdiction: data.jurisdiction ?? "UNKNOWN",
    severity: data.severity ?? "medium",
    description: data.description ?? "",
    category: data.category ?? "",
    effectiveDate: String(data.effective_date ?? ""),
    citation,
    remediationMessage: remediationMsg,
    regexPatterns: patterns,
    detectionScope: String(data.detection_scope ?? "all"),
  };
}

// Text normalisation, identical to rules/rego/complyedge/shared/normalize.rego and
// to the Python engine (trustlint/engine.py). Patterns are matched against the
// normalised text, so the same words decide the same way whatever whitespace or
// quote characters they arrive with:
// - a run of spaces, tabs or Unicode spaces (no-break space and the other
//   Unicode space separators) becomes one space;
// - a line break (CR LF, CR, U+0085, U+2028, U+2029) with the spaces around it
//   becomes one LF, so `.` still stops at a line end and `^`/`$` with the m flag
//   still see it;
// - curly quotes become straight quotes;
// - a Unicode hyphen or dash (U+2010 to U+2015) becomes "-".
const SPACE_CHARS = "\\t\\x0b\\x0c \\u00a0\\u1680\\u2000-\\u200a\\u202f\\u205f\\u3000";
const LINE_BREAK_RE = new RegExp(
  `[${SPACE_CHARS}]*(?:\\r\\n|[\\n\\r\\u0085\\u2028\\u2029])[${SPACE_CHARS}]*`,
  "g"
);
const LINE_SPACE_RE = new RegExp(`[${SPACE_CHARS}]+`, "g");

export function normalizeText(text: string): string {
  return text
    .replace(/[\u2018\u2019\u201a\u201b]/g, "'")
    .replace(/[\u201c\u201d\u201e\u201f]/g, '"')
    .replace(/[\u2010-\u2015]/g, "-")
    .replace(LINE_BREAK_RE, "\n")
    .replace(LINE_SPACE_RE, " ");
}

/**
 * Whether a rule tagged `ruleJurisdiction` applies to an end user in
 * `requested`. GLOBAL rules apply everywhere; a rule applies in its own
 * jurisdiction, in any sub-jurisdiction of it (a US rule applies in US-CA) and
 * in any parent of it (a US-CA rule is in scope for a US-wide check). No
 * requested jurisdiction means every rule. Same rule as the Python engine.
 */
export function jurisdictionApplies(ruleJurisdiction: string, requested?: string): boolean {
  if (!requested) return true;
  const rule = (ruleJurisdiction ?? "").toUpperCase();
  const want = requested.toUpperCase();
  if (rule === "GLOBAL") return true;
  return rule === want || want.startsWith(rule + "-") || rule.startsWith(want + "-");
}

export type Direction = "input" | "output";

const SCOPES_FOR_DIRECTION: Record<Direction, string[]> = {
  input: ["all", "user_input"],
  output: ["all", "ai_output"],
};

/** Whether a rule's detection_scope covers text flowing in `direction`. */
export function scopeApplies(detectionScope: string | undefined, direction?: string): boolean {
  if (!direction) return true;
  const scopes = SCOPES_FOR_DIRECTION[direction.toLowerCase() as Direction];
  if (!scopes) {
    throw new Error(`direction must be 'input' or 'output', got '${direction}'`);
  }
  return scopes.includes((detectionScope || "all").toLowerCase());
}

/**
 * Translate a YAML pattern into a JS-compatible pattern + flags.
 *
 * The corpus is authored for Python/PCRE, where an inline `(?i)` / `(?im)`
 * prefix sets flags. JavaScript's RegExp REJECTS that construct outright
 * ("Invalid group"), so every rule authored with an inline prefix threw at
 * compile time and was silently skipped by the catch in check(). That is why
 * `npm install trustlint` loaded all 10 prompt_security rules and matched none
 * of them, including the simplest direct-override rule.
 *
 * Only a LEADING prefix is stripped; an inline group elsewhere in the pattern
 * is left alone. Flags not supported by JS are dropped rather than passed on.
 */
export function normalizePattern(
  raw: string,
  declaredFlags = ""
): { pattern: string; flags: string } {
  let pattern = raw;
  let collected = declaredFlags;
  const leading = pattern.match(/^\(\?([a-zA-Z]+)\)/);
  if (leading) {
    collected += leading[1];
    pattern = pattern.slice(leading[0].length);
  }
  const flags = [...new Set(collected.split(""))]
    .filter((c) => "imsu".includes(c))
    .join("");
  return { pattern, flags };
}

function findYamlFiles(dir: string): string[] {
  const results: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findYamlFiles(full));
    } else if (entry.name.endsWith(".yaml") || entry.name.endsWith(".yml")) {
      results.push(full);
    }
  }
  return results.sort();
}

function resolveRulesDir(rulesDir?: string): string | null {
  if (rulesDir) {
    return fs.existsSync(rulesDir) ? rulesDir : null;
  }

  // ~/.trustlint/rules is deliberately NOT read. `trustlint rules update` used to
  // fill it from a GitHub release (2026-07, 64 rules including a withdrawn one)
  // and, read first, it overrode the bundled rule set across every later
  // upgrade. The bundled rules ship with each release; --rules-dir covers a
  // custom corpus. Same order as the Python engine.

  // Walk up from CWD looking for rules/regulations/
  let dir = process.cwd();
  while (true) {
    const candidate = path.join(dir, "rules", "regulations");
    if (fs.existsSync(candidate)) {
      return candidate;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  // Fallback: rules bundled inside the installed package, copied from the
  // canonical rules/regulations/ corpus at build time by scripts/copy-rules.mjs.
  // This is what lets `npm install trustlint` work in a repo with no local
  // rules/ dir — the standalone-linter path.
  //
  // Deliberately LAST, matching the Python engine's _resolve_rules_dir order.
  // Bundled-first would be install-true too, but it would also override a
  // developer's live rules/regulations/ with whatever snapshot was baked at
  // build time — silently linting against stale rules is the failure that
  // shipped an August 2026 Article 12 clock once already. The two engines are
  // one product; their resolution order has to agree.
  const bundled = path.join(__dirname, "rules");
  if (fs.existsSync(bundled)) {
    return bundled;
  }

  return null;
}

export class TrustLintEngine {
  public rules: Rule[] = [];
  private rulesDir: string | null;
  /** Patterns that failed to compile. Empty is the only healthy state. */
  readonly patternErrors: string[] = [];

  constructor(rulesDir?: string) {
    this.rulesDir = resolveRulesDir(rulesDir);
    if (this.rulesDir) {
      this.loadRules();
    }
  }

  private loadRules(): void {
    if (!this.rulesDir) return;
    for (const yamlFile of findYamlFiles(this.rulesDir)) {
      try {
        const rule = parseRuleFile(yamlFile);
        if (rule) {
          this.rules.push(rule);
        }
      } catch {
        // Skip malformed files
      }
    }
  }

  /**
   * `jurisdiction` is where the end user is (see jurisdictionApplies).
   * `direction` is "input" (text a user sends) or "output" (text the AI
   * produces); a rule scoped to user_input or ai_output runs only in its
   * direction. Omitted runs every rule.
   */
  check(text: string, jurisdiction?: string, direction?: string): LintResult {
    const applicable = this.rules.filter(
      (r) => jurisdictionApplies(r.jurisdiction, jurisdiction) && scopeApplies(r.detectionScope, direction)
    );
    const textToMatch = normalizeText(text);

    const violations: Violation[] = [];

    for (const rule of applicable) {
      for (const pat of rule.regexPatterns) {
        try {
          const regex = new RegExp(pat.pattern, pat.flags);
          if (regex.test(textToMatch)) {
            violations.push({
              ruleId: rule.id,
              title: rule.title,
              severity: rule.severity,
              jurisdiction: rule.jurisdiction,
              description: rule.description,
              citation: rule.citation,
              patternMatched: pat.description || pat.pattern.slice(0, 60),
              remediation: rule.remediationMessage,
            });
            break; // One match per rule is enough
          }
        } catch (err) {
          // A pattern that will not compile must never fail silently — that is
          // how 10 prompt_security rules sat dead in the shipped package.
          this.patternErrors.push(
            `${rule.id}: ${(err as Error).message}`
          );
        }
      }
    }

    const hasCritical = violations.some(
      (v) => v.severity === "critical" || v.severity === "high"
    );

    return {
      text,
      violations,
      rulesEvaluated: applicable.length,
      hasCritical,
      clean: violations.length === 0,
    };
  }
}
