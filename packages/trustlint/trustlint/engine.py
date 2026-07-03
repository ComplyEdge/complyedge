"""TrustLint compliance engine — loads YAML rules and runs Tier 1 regex checks offline."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import yaml


@dataclass
class Violation:
    rule_id: str
    title: str
    severity: str
    jurisdiction: str
    description: str
    citation: str
    pattern_matched: str
    remediation: str


@dataclass
class LintResult:
    text: str
    violations: list[Violation] = field(default_factory=list)
    rules_evaluated: int = 0

    @property
    def has_critical(self) -> bool:
        return any(v.severity in ("critical", "high") for v in self.violations)

    @property
    def clean(self) -> bool:
        return len(self.violations) == 0


@dataclass
class Rule:
    id: str
    title: str
    jurisdiction: str
    severity: str
    description: str
    category: str
    effective_date: str
    citation: str
    remediation_message: str
    regex_patterns: list[dict]  # [{pattern, description, flags}]
    tier: str = "community"  # community | developer | enterprise


class TrustLintEngine:
    """Loads YAML rules and evaluates text against Tier 1 regex patterns."""

    def __init__(self, rules_dir: Optional[str] = None):
        self.rules: list[Rule] = []
        self._rules_dir = self._resolve_rules_dir(rules_dir)
        if self._rules_dir and self._rules_dir.exists():
            self._load_rules()

    @staticmethod
    def _resolve_rules_dir(rules_dir: Optional[str]) -> Optional[Path]:
        if rules_dir:
            return Path(rules_dir)

        # Check ~/.trustlint/rules/ first
        home_rules = Path.home() / ".trustlint" / "rules"
        if home_rules.exists():
            return home_rules

        # Walk up from CWD looking for rules/regulations/ (dev-in-repo)
        cwd = Path.cwd()
        for parent in [cwd, *cwd.parents]:
            candidate = parent / "rules" / "regulations"
            if candidate.exists():
                return candidate
            # Stop at filesystem root
            if parent == parent.parent:
                break

        # Fallback: rules bundled inside the installed package. Populated at
        # build time from the canonical rules/regulations/ corpus (see
        # deploy-pip.sh). This is what lets `pip install trustlint` work in any
        # repo that has no local rules/ dir — the standalone-linter path.
        bundled = Path(__file__).parent / "rules"
        if bundled.exists():
            return bundled

        return None

    def _load_rules(self) -> None:
        if not self._rules_dir:
            return
        for yaml_file in sorted(self._rules_dir.rglob("*.yaml")):
            try:
                rule = self._parse_rule_file(yaml_file)
                if rule:
                    self.rules.append(rule)
            except Exception:
                continue  # Skip malformed files silently

    @staticmethod
    def _build_pattern_info(pattern: str, description: str, flags_str: str) -> Optional[dict]:
        """Compile a regex pattern at load time. Skip patterns that fail to compile."""
        flags = 0
        if "i" in (flags_str or ""):
            flags |= re.IGNORECASE
        try:
            compiled = re.compile(pattern, flags)
        except re.error:
            return None
        return {
            "pattern": pattern,
            "description": description,
            "flags": flags_str,
            "compiled": compiled,
        }

    @classmethod
    def _parse_rule_file(cls, path: Path) -> Optional[Rule]:
        with open(path) as f:
            data = yaml.safe_load(f)

        if not isinstance(data, dict) or "id" not in data:
            return None

        # Extract regex patterns from conditions and PRE-COMPILE them.
        # Compilation is the dominant cost; doing it at load time keeps Layer 1
        # latency low and stable as the corpus grows.
        patterns = []
        for cond in data.get("conditions", []):
            cond_type = cond.get("type", "")

            if cond_type == "regex":
                pat_info = cls._build_pattern_info(
                    cond["value"], cond.get("description", ""), cond.get("flags", "")
                )
                if pat_info:
                    patterns.append(pat_info)

            elif cond_type == "hybrid_detection":
                tier1 = cond.get("tier1_config", {})
                for rp in tier1.get("risk_flag_patterns", []):
                    pat_info = cls._build_pattern_info(
                        rp["pattern"], rp.get("description", ""), rp.get("flags", "")
                    )
                    if pat_info:
                        patterns.append(pat_info)

        if not patterns:
            return None

        # Extract citation
        source = data.get("source", {})
        citation = source.get("citation", "")
        if not citation:
            citations = source.get("citations", [])
            citation = citations[0] if citations else ""

        # Extract remediation message
        remediation = data.get("remediation", {})
        remediation_msg = ""
        if isinstance(remediation, dict):
            remediation_msg = remediation.get("message", "")
        elif isinstance(remediation, str):
            remediation_msg = remediation

        return Rule(
            id=data["id"],
            title=data.get("title", data.get("description", "")[:60]),
            jurisdiction=data.get("jurisdiction", "UNKNOWN"),
            severity=data.get("severity", "medium"),
            description=data.get("description", ""),
            category=data.get("category", ""),
            effective_date=str(data.get("effective_date", "")),
            citation=citation,
            remediation_message=remediation_msg,
            regex_patterns=patterns,
            tier=(data.get("tier") or "community"),
        )

    def check(self, text: str, jurisdiction: Optional[str] = None) -> LintResult:
        result = LintResult(text=text)
        applicable = self.rules
        if jurisdiction:
            applicable = [r for r in self.rules if r.jurisdiction.upper() == jurisdiction.upper()]
        result.rules_evaluated = len(applicable)

        for rule in applicable:
            for pat_info in rule.regex_patterns:
                compiled = pat_info.get("compiled")
                if compiled is None:
                    continue  # skip patterns that failed to compile at load time
                if compiled.search(text):
                    result.violations.append(Violation(
                        rule_id=rule.id,
                        title=rule.title,
                        severity=rule.severity,
                        jurisdiction=rule.jurisdiction,
                        description=rule.description,
                        citation=rule.citation,
                        pattern_matched=pat_info.get("description", pat_info["pattern"][:60]),
                        remediation=rule.remediation_message,
                    ))
                    break  # One match per rule is enough

        return result
