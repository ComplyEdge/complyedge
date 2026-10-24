"""TrustLint compliance engine — loads YAML rules and runs Tier 1 regex checks offline."""

from __future__ import annotations

import logging
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
    detection_scope: str = "all"  # all | user_input | ai_output


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


logger = logging.getLogger(__name__)


# Text normalisation, identical to rules/rego/complyedge/shared/normalize.rego and
# to the TypeScript engine (src/engine.ts). Patterns are matched against the
# normalised text, so the same words decide the same way whatever whitespace or
# quote characters they arrive with:
# - a run of spaces, tabs or Unicode spaces (no-break space and the other
#   Unicode space separators) becomes one space;
# - a line break (CR LF, CR, U+0085, U+2028, U+2029) with the spaces around it
#   becomes one LF, so `.` still stops at a line end and `^`/`$` with the m flag
#   still see it;
# - curly quotes become straight quotes;
# - a Unicode hyphen or dash (U+2010 to U+2015) becomes "-".
_SPACE_CHARS = "\t\x0b\x0c \u00a0\u1680\u2000-\u200a\u202f\u205f\u3000"
_LINE_BREAK_RE = re.compile(
    f"[{_SPACE_CHARS}]*(?:\r\n|[\n\r\u0085\u2028\u2029])[{_SPACE_CHARS}]*"
)
_LINE_SPACE_RE = re.compile(f"[{_SPACE_CHARS}]+")
_SINGLE_QUOTES_RE = re.compile("[\u2018\u2019\u201a\u201b]")
_DOUBLE_QUOTES_RE = re.compile("[\u201c\u201d\u201e\u201f]")
_HYPHENS_RE = re.compile("[\u2010-\u2015]")


def normalize_text(text: str) -> str:
    """Normalise whitespace and quote characters before matching."""
    text = _SINGLE_QUOTES_RE.sub("'", text)
    text = _DOUBLE_QUOTES_RE.sub('"', text)
    text = _HYPHENS_RE.sub("-", text)
    text = _LINE_BREAK_RE.sub("\n", text)
    return _LINE_SPACE_RE.sub(" ", text)


def jurisdiction_applies(rule_jurisdiction: str, requested: Optional[str]) -> bool:
    """Whether a rule tagged `rule_jurisdiction` applies to an end user in `requested`.

    `requested` is where the end user is. A GLOBAL rule applies everywhere; a
    rule applies in its own jurisdiction, in any sub-jurisdiction of it (a US
    rule applies in US-CA) and in any parent of it (a US-CA rule is in scope
    for a US-wide check). No requested jurisdiction means every rule.
    """
    if not requested:
        return True
    rule_j = (rule_jurisdiction or "").upper()
    want = requested.upper()
    if rule_j == "GLOBAL":
        return True
    return rule_j == want or want.startswith(rule_j + "-") or rule_j.startswith(want + "-")


#: detection_scope values that apply to each check direction. A rule with no
#: detection_scope, or `all`, applies to both.
_SCOPES_FOR_DIRECTION = {
    "input": {"all", "user_input"},
    "output": {"all", "ai_output"},
}


def scope_applies(detection_scope: Optional[str], direction: Optional[str]) -> bool:
    """Whether a rule's detection_scope covers text flowing in `direction`."""
    if not direction:
        return True
    scopes = _SCOPES_FOR_DIRECTION.get(direction.lower())
    if scopes is None:
        raise ValueError(f"direction must be 'input' or 'output', got {direction!r}")
    return (detection_scope or "all").lower() in scopes


class TrustLintEngine:
    """Loads YAML rules and evaluates text against Tier 1 regex patterns."""

    def __init__(self, rules_dir: Optional[str] = None):
        self.rules: list[Rule] = []
        #: (path, reason) for every rule file that failed to load. Exposed so a
        #: caller can assert the corpus loaded completely instead of trusting a
        #: silent count.
        self.skipped_files: list[tuple[str, str]] = []
        self._rules_dir = self._resolve_rules_dir(rules_dir)
        if self._rules_dir and self._rules_dir.exists():
            self._load_rules()

    @staticmethod
    def _resolve_rules_dir(rules_dir: Optional[str]) -> Optional[Path]:
        if rules_dir:
            return Path(rules_dir)

        # ~/.trustlint/rules is deliberately NOT read. `trustlint rules update` used
        # to fill it from a GitHub release (2026-07, 64 rules including a withdrawn
        # one) and, read first, it overrode the bundled rule set across every later
        # upgrade. The bundled rules ship with each release; --rules-dir covers a
        # custom corpus.

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
            except Exception as exc:
                # Warn, do not swallow. A malformed rule file used to vanish
                # with zero feedback, so a user following the README (whose
                # example used `pattern:` where the schema requires `value:`)
                # got a KeyError here, saw nothing, and believed their rule was
                # active. Silence on a compliance rule that failed to load is
                # the worst possible default: the corpus is quietly smaller
                # than the operator thinks it is.
                logger.warning(
                    "Skipping malformed rule file %s: %s: %s",
                    yaml_file,
                    type(exc).__name__,
                    exc,
                )
                self.skipped_files.append((str(yaml_file), f"{type(exc).__name__}: {exc}"))
                continue

    @staticmethod
    def _build_pattern_info(pattern: str, description: str, flags_str: str) -> Optional[dict]:
        """Compile a regex pattern at load time. Skip patterns that fail to compile."""
        flags = 0
        for letter, flag in (("i", re.IGNORECASE), ("m", re.MULTILINE), ("s", re.DOTALL), ("x", re.VERBOSE)):
            if letter in (flags_str or ""):
                flags |= flag
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
        if not citation:
            # Rules that rest on no single legal article (an industry standard,
            # a detection control) carry provision_label instead, which says so.
            # Every finding names its source rather than an empty citation.
            citation = source.get("provision_label", "")

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
            detection_scope=str(data.get("detection_scope") or "all"),
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
        direction: Optional[str] = None,
    ) -> LintResult:
        """Run Tier-1 checks. ``as_of`` + ``context`` drive dynamic-state
        (sanctions transition) evaluation: a matched rule may be carved out,
        expired, or in a wind-down window and carry transition guidance.

        ``jurisdiction`` is where the end user is (see jurisdiction_applies).
        ``direction`` is "input" (text a user sends) or "output" (text the AI
        produces); a rule whose detection_scope is user_input or ai_output runs
        only in its direction. None runs every rule."""
        result = LintResult(text=text)
        as_of = as_of or date.today()
        context = context or {}
        applicable = [
            r
            for r in self.rules
            if jurisdiction_applies(r.jurisdiction, jurisdiction)
            and scope_applies(r.detection_scope, direction)
        ]
        result.rules_evaluated = len(applicable)
        text_to_match = normalize_text(text)

        for rule in applicable:
            for pat_info in rule.regex_patterns:
                compiled = pat_info.get("compiled")
                if compiled is None:
                    continue  # skip patterns that failed to compile at load time
                if compiled.search(text_to_match):
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
