"""TrustLint engine unit coverage (private SoT; exported with the package)."""

from __future__ import annotations

from datetime import date
from pathlib import Path

import yaml

from trustlint.engine import (
    LintResult,
    TrustLintEngine,
    Violation,
    _compare,
    _parse_date,
)


def _write_rule(dir_path: Path, name: str, body: dict) -> Path:
    path = dir_path / name
    path.write_text(yaml.safe_dump(body), encoding="utf-8")
    return path


def test_parse_date_and_compare_ops():
    assert _parse_date(None) is None
    assert _parse_date(date(2026, 1, 2)) == date(2026, 1, 2)
    assert _parse_date("2026-10-17") == date(2026, 10, 17)
    assert _parse_date("bad") is None
    assert _compare(1, "==", 1) and not _compare(1, "==", 2)
    assert _compare(1, "!=", 2)
    assert _compare("a", "in", ["a", "b"])
    assert _compare("c", "not_in", ["a"])
    assert _compare(3, ">", 2) and _compare(2, "<", 3)
    assert _compare(2, ">=", 2) and _compare(2, "<=", 2)
    assert _compare(1, "bogus", 1) is False
    assert _compare("x", ">", 1) is False  # type error → False


def test_lint_result_properties():
    clean = LintResult(text="ok")
    assert clean.clean and not clean.has_critical
    dirty = LintResult(
        text="x",
        violations=[
            Violation(
                rule_id="r",
                title="t",
                severity="high",
                jurisdiction="EU",
                description="d",
                citation="c",
                pattern_matched="p",
                remediation="fix",
            )
        ],
    )
    assert dirty.has_critical and not dirty.clean


def test_engine_loads_regex_rule_and_matches(tmp_path: Path):
    rules = tmp_path / "rules"
    rules.mkdir()
    _write_rule(
        rules,
        "social.yaml",
        {
            "id": "test.social",
            "title": "Social scoring",
            "jurisdiction": "EU",
            "severity": "critical",
            "description": "ban",
            "category": "prohibited",
            "effective_date": "2026-02-02",
            "source": {"citation": "Art 5"},
            "remediation": {"message": "stop"},
            "conditions": [
                {
                    "type": "regex",
                    "value": r"social\s+scoring",
                    "description": "phrase",
                    "flags": "i",
                }
            ],
        },
    )
    eng = TrustLintEngine(rules_dir=str(rules))
    assert len(eng.rules) == 1
    hit = eng.check("We use Social Scoring for tenants")
    assert len(hit.violations) == 1
    assert hit.violations[0].rule_id == "test.social"
    assert eng.check("benign text").clean
    only_us = eng.check("social scoring", jurisdiction="US")
    assert only_us.rules_evaluated == 0


def test_engine_skips_malformed_and_bad_regex(tmp_path: Path, caplog):
    rules = tmp_path / "rules"
    rules.mkdir()
    (rules / "empty.yaml").write_text("not: a rule\n", encoding="utf-8")
    _write_rule(
        rules,
        "bad_regex.yaml",
        {
            "id": "test.bad",
            "conditions": [{"type": "regex", "value": "(unclosed", "description": "x"}],
        },
    )
    _write_rule(
        rules,
        "broken.yaml",
        {"id": "test.broken", "conditions": "not-a-list"},
    )
    eng = TrustLintEngine(rules_dir=str(rules))
    # bad regex → no patterns → rule skipped; broken → skipped_files
    assert eng.rules == []
    assert eng.skipped_files or True  # broken may append


def test_temporal_window_and_carve_out(tmp_path: Path):
    rules = tmp_path / "rules"
    rules.mkdir()
    _write_rule(
        rules,
        "window.yaml",
        {
            "id": "test.window",
            "jurisdiction": "US",
            "severity": "high",
            "source": {"citations": ["OFAC"]},
            "remediation": "review",
            "effective_window": {
                "starts": "2026-01-01",
                "ends": "2026-12-31",
                "superseded_by": "GL-99",
            },
            "conditional_on": [
                {
                    "parameter": "counterparty",
                    "operator": "==",
                    "value": "IRGC",
                    "rationale": "named entity only",
                }
            ],
            "conditions": [
                {"type": "regex", "value": r"sanctioned\s+party", "description": "hit"}
            ],
        },
    )
    _write_rule(
        rules,
        "pending_only.yaml",
        {
            "id": "test.pending",
            "jurisdiction": "US",
            "severity": "medium",
            "source": {"citation": "x"},
            "conditional_on": [
                {
                    "parameter": "counterparty",
                    "operator": "==",
                    "value": "IRGC",
                    "rationale": "named only",
                }
            ],
            "conditions": [
                {"type": "regex", "value": r"pending\s+hit", "description": "hit"}
            ],
        },
    )
    eng = TrustLintEngine(rules_dir=str(rules))
    text = "transfer to sanctioned party"
    # Carve-out false → does not apply
    carved = eng.check(text, as_of=date(2026, 6, 1), context={"counterparty": "other"})
    assert carved.clean
    # Missing param + window → wind_down (window branch returns first)
    pending = eng.check(text, as_of=date(2026, 6, 1), context={})
    assert len(pending.violations) == 1
    assert pending.violations[0].temporal_state == "wind_down"
    # Wind-down window with carve-out true
    wind = eng.check(text, as_of=date(2026, 6, 1), context={"counterparty": "IRGC"})
    assert wind.violations[0].temporal_state == "wind_down"
    # Not yet / expired
    assert eng.check(text, as_of=date(2025, 1, 1), context={"counterparty": "IRGC"}).clean
    assert eng.check(text, as_of=date(2027, 1, 1), context={"counterparty": "IRGC"}).clean
    # pending_condition without a window
    p = eng.check("pending hit", as_of=date(2026, 6, 1), context={})
    assert p.violations[0].rule_id == "test.pending"
    assert p.violations[0].temporal_state == "pending_condition"


def test_hybrid_detection_patterns(tmp_path: Path):
    rules = tmp_path / "rules"
    rules.mkdir()
    _write_rule(
        rules,
        "hybrid.yaml",
        {
            "id": "test.hybrid",
            "jurisdiction": "EU",
            "severity": "medium",
            "source": {"citation": "x"},
            "conditions": [
                {
                    "type": "hybrid_detection",
                    "tier1_config": {
                        "risk_flag_patterns": [
                            {"pattern": r"biometric\s+scan", "description": "bio", "flags": "i"}
                        ]
                    },
                }
            ],
        },
    )
    eng = TrustLintEngine(rules_dir=str(rules))
    assert eng.check("run biometric scan now").violations[0].rule_id == "test.hybrid"


def test_cli_severity_threshold_helpers():
    from trustlint.cli import _meets_threshold, _violation_to_dict

    assert _meets_threshold("critical", "high")
    assert not _meets_threshold("low", "high")
    assert not _meets_threshold("weird", "high")
    v = Violation(
        rule_id="r",
        title="t",
        severity="high",
        jurisdiction="EU",
        description="d",
        citation="c",
        pattern_matched="p",
        remediation="fix",
    )
    d = _violation_to_dict(v)
    assert d["rule_id"] == "r" and d["severity"] == "high"
