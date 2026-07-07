"""TrustLint compliance engine — loads YAML rules and runs Tier 1 regex checks offline."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any, Optional

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
    # Sanctions/transition support: temporal state of the rule at evaluation
    # time and customer-facing guidance when the rule is in a wind-down window
    # or gated on a conditional carve-out. `active` = ordinary in-force rule.
    temporal_state: str = "active"  # active | wind_down | pending_condition
    transition_guidance: Optional[str] = None


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
    # Dynamic-state sanctions fields (OFAC/EU transition rules). Absent on
    # ordinary static rules — the engine treats those as always-in-force.
    effective_window: Optional[dict] = None  # {starts, ends?, superseded_by?}
    conditional_on: Optional[list] = None  # [{parameter, operator, value, rationale}]
    supersedes: Optional[list] = None


def _parse_date(value: Any) -> Optional[date]:
    """Parse an ISO 'YYYY-MM-DD' date; return None on anything unparseable."""
    if not value:
        return None
    if isinstance(value, date):
        return value
    try:
        y, m, d = str(value).split("-")
        return date(int(y), int(m), int(d))
    except Exception:
        return None


def _compare(actual: Any, op: str, expected: Any) -> bool:
    """Evaluate a conditional_on comparison. Unknown ops / type errors → False."""
    try:
        if op == "==":
            return actual == expected
        if op == "!=":
            return actual != expected
        if op == "in":
            return actual in expected
        if op == "not_in":
            return actual not in expected
        if op == ">":
            return actual > expected
        if op == "<":
            return actual < expected
        if op == ">=":
            return actual >= expected
        if op == "<=":
            return actual <= expected
    except Exception:
        return False
    return False


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
            effective_window=data.get("effective_window"),
            conditional_on=data.get("conditional_on"),
            supersedes=data.get("supersedes"),
        )

    @staticmethod
    def _evaluate_temporal_state(
        rule: "Rule", as_of: date, context: dict
    ) -> tuple[bool, str, Optional[str]]:
        """Decide whether a (possibly dynamic-state) rule applies as of a date.

        Returns (applies, temporal_state, transition_guidance). Ordinary static
        rules (no effective_window / conditional_on) are always active and apply
        — this keeps behaviour identical for the existing corpus.
        """
        state = "active"
        guidance: Optional[str] = None

        # 1. Conditional carve-outs (e.g., an Iran sanction that survives only
        #    for IRGC-affiliated counterparties). The rule applies only when
        #    every condition holds for the transaction context.
        for cond in (rule.conditional_on or []):
            param = cond.get("parameter")
            op = cond.get("operator", "==")
            expected = cond.get("value")
            rationale = cond.get("rationale", "")
            if param in context:
                if not _compare(context[param], op, expected):
                    # A carve-out condition is false → the prohibition no longer
                    # applies to this counterparty/transaction.
                    return (False, "carved_out",
                            f"Permitted under carve-out: {rationale}".strip())
            else:
                # Cannot confirm the carve-out → conservatively keep the rule in
                # force and flag the missing parameter for verification.
                state = "pending_condition"
                guidance = (
                    f"Applies pending verification of '{param}' ({op} "
                    f"{expected}): {rationale}"
                ).strip()

        # 2. Effective window — General License wind-down / expiry / supersession.
        win = rule.effective_window or {}
        starts = _parse_date(win.get("starts"))
        ends = _parse_date(win.get("ends"))
        superseded_by = win.get("superseded_by")
        if starts and as_of < starts:
            return (False, "not_yet_effective",
                    f"Not yet in force; takes effect {starts.isoformat()}.")
        if ends and as_of > ends:
            g = f"Expired {ends.isoformat()}."
            if superseded_by:
                g += f" Superseded by {superseded_by}."
            return (False, "expired", g)
        if ends and (starts is None or starts <= as_of) and as_of <= ends:
            # Still in force, but a scheduled lift/supersession is dated — return
            # a forward-looking transition notice alongside the (blocking) verdict.
            g = f"In force; prohibition scheduled to lift on {ends.isoformat()}."
            if superseded_by:
                g += f" Superseded by {superseded_by} thereafter."
            return (True, "wind_down", g)

        return (True, state, guidance)

    def check(
        self,
        text: str,
        jurisdiction: Optional[str] = None,
        as_of: Optional[date] = None,
        context: Optional[dict] = None,
    ) -> LintResult:
        """Run Tier-1 checks. ``as_of`` + ``context`` drive dynamic-state
        (sanctions transition) evaluation: a matched rule may be carved out,
        expired, or in a wind-down window and carry transition guidance."""
        result = LintResult(text=text)
        as_of = as_of or date.today()
        context = context or {}
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
                    applies, state, guidance = self._evaluate_temporal_state(
                        rule, as_of, context
                    )
                    if not applies:
                        break  # carved out / not in force as of `as_of`
                    result.violations.append(Violation(
                        rule_id=rule.id,
                        title=rule.title,
                        severity=rule.severity,
                        jurisdiction=rule.jurisdiction,
                        description=rule.description,
                        citation=rule.citation,
                        pattern_matched=pat_info.get("description", pat_info["pattern"][:60]),
                        remediation=rule.remediation_message,
                        temporal_state=state,
                        transition_guidance=guidance,
                    ))
                    break  # One match per rule is enough

        return result
