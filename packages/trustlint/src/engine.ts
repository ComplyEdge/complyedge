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
  };
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

  // Check ~/.trustlint/rules/
  const homeRules = path.join(
    process.env.HOME ?? process.env.USERPROFILE ?? "",
    ".trustlint",
    "rules"
  );
  if (fs.existsSync(homeRules)) {
    return homeRules;
  }

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

  check(text: string, jurisdiction?: string): LintResult {
    let applicable = this.rules;
    if (jurisdiction) {
      applicable = this.rules.filter(
        (r) => r.jurisdiction.toUpperCase() === jurisdiction.toUpperCase()
      );
    }

    const violations: Violation[] = [];

    for (const rule of applicable) {
      for (const pat of rule.regexPatterns) {
        try {
          const regex = new RegExp(pat.pattern, pat.flags);
          if (regex.test(text)) {
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
