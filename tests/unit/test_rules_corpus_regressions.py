"""Regression tests for the rules corpus cluster (D1-D6).

The corpus is the asset. A rule that states the wrong effective date is not a
harmless typo: it tells a deployer an obligation binds today when it does not,
which is exactly the overclaim the platform sells against.

- D1  10 Chapter III high-risk rules were dated 2026-08-02 while Reg (EU)
      2026/1744 postponed Annex III to 2027-12-02.
- D2  GUARD: the 5 Article 50 rules are CORRECTLY dated 2026-08-02 and must
      not be swept up by a bulk re-date.
- D3  5 GPAI rules were dated 2026-08-02; Chapter V obligations applied from
      2025-08-02. 2026-08-02 is when Art 101 fining powers became exercisable.
- D4  the public claim said EVERY rule carries a verbatim citation (57/64).
- D5  the universal PII rule cited complyedge.com as its own authority.
- D6  the README's custom-rule example used `pattern:`/`field:` where the
      schema requires `value:` with additionalProperties false, so a user
      following the docs produced a rule the linter silently dropped.
"""

from __future__ import annotations

import json
import pathlib
import re

import pytest

yaml = pytest.importorskip("yaml")

ROOT = pathlib.Path(__file__).resolve().parents[2]
EU = ROOT / "rules" / "regulations" / "eu"
REGS = ROOT / "rules" / "regulations"
SCHEMA = json.loads((ROOT / "rules" / "schemas" / "rule-schema.json").read_text())

HIGH_RISK = [
    "article6_high_risk_classification", "article9_risk_management",
    "article10_data_governance", "article12_record_keeping",
    "article13_transparency", "article14_human_oversight",
    "article15_accuracy_robustness", "article16_provider_obligations",
    "article26_deployer_obligations", "article27_fria",
]
GPAI = [
    "gpai_copyright_transparency", "gpai_downstream_obligations",
    "gpai_model_classification", "gpai_systemic_risk",
    "gpai_technical_documentation",
]


def _load(name):
    return yaml.safe_load((EU / f"eu_ai_act_{name}.yaml").read_text())


class TestHighRiskDatesReflectTheDeferral:
    """D1: Chapter III obligations bind 2027-12-02, not 2026-08-02."""

    @pytest.mark.parametrize("name", HIGH_RISK)
    def test_not_dated_as_binding_in_august_2026(self, name):
        d = _load(name)
        assert d["effective_date"] != "2026-08-02", (
            f"{name} claims a high-risk obligation bound on 2026-08-02; "
            "Reg (EU) 2026/1744 postponed Annex III to 2027-12-02"
        )

    @pytest.mark.parametrize("name", HIGH_RISK)
    def test_dated_to_the_deferred_date(self, name):
        assert _load(name)["effective_date"] == "2027-12-02"

    @pytest.mark.parametrize("name", HIGH_RISK)
    def test_carries_the_deferral_note(self, name):
        notes = " ".join(_load(name).get("compliance_notes") or [])
        assert "2026/1744" in notes and "2 December 2027" in notes, (
            f"{name} has the right date but no note explaining the deferral; "
            "a reader cannot tell readiness tooling from a live duty"
        )


class TestArticle50DatesAreUntouched:
    """D2: these are CORRECT. A bulk re-date must not move them."""

    def test_article50_rules_still_bind_august_2026(self):
        files = sorted(EU.glob("eu_ai_act_article50_*.yaml"))
        assert len(files) == 5, f"expected 5 Article 50 rules, found {len(files)}"
        for f in files:
            d = yaml.safe_load(f.read_text())
            assert d["effective_date"] == "2026-08-02", (
                f"{f.name} was moved off 2026-08-02; Article 50 transparency "
                "was NOT deferred and understating it loses a live obligation"
            )


class TestGpaiDatesMatchApplicability:
    """D3: Chapter V applied 2025-08-02; 2026 is the fining-power date."""

    @pytest.mark.parametrize("name", GPAI)
    def test_dated_to_applicability_not_enforcement(self, name):
        assert _load(name)["effective_date"] == "2025-08-02", (
            f"{name} conflates the Art 101 fining date with the date the "
            "obligation began"
        )

    def test_consistent_with_the_article53_sibling(self):
        art53 = yaml.safe_load(
            (EU / "eu_ai_act_article53_gpai_training_summary.yaml").read_text()
        )
        for name in GPAI:
            assert _load(name)["effective_date"] == art53["effective_date"], (
                "GPAI rules disagree with their own Article 53 sibling"
            )


class TestCitationClaimsAreTrue:
    """D4/D5: no overclaim, and no citing ourselves as the authority."""

    def test_every_eu_ai_act_rule_carries_a_citation(self):
        files = list(EU.glob("eu_ai_act_*.yaml"))
        missing = [
            f.name for f in files
            if not (yaml.safe_load(f.read_text()).get("source") or {}).get("citation")
        ]
        assert not missing, f"EU AI Act rules without a verbatim citation: {missing}"

    def test_readme_does_not_claim_every_rule_is_cited(self):
        txt = (ROOT / "README.md").read_text()
        assert "Every rule carries a verbatim citation" not in txt, (
            "README claims universal citation coverage; measured 57/64"
        )

    def test_no_rule_cites_complyedge_as_its_own_authority(self):
        offenders = []
        for f in REGS.rglob("*.yaml"):
            src = yaml.safe_load(f.read_text()).get("source") or {}
            if "complyedge.com" in str(src.get("url", "")):
                offenders.append(f.name)
        assert not offenders, (
            f"these rules cite ComplyEdge as the legal authority for themselves: "
            f"{offenders}"
        )


class TestReadmeExampleIsUsable:
    """D6: the documented example must actually load."""

    def test_readme_custom_rule_example_validates(self):
        jsonschema = pytest.importorskip("jsonschema")
        md = (ROOT / "README.md").read_text()
        m = re.search(r"```yaml\n(id: MY_CUSTOM_RULE_001.*?)```", md, re.S)
        assert m, "custom-rule example missing from README"
        jsonschema.validate(yaml.safe_load(m.group(1)), SCHEMA)

    def test_readme_example_does_not_use_the_rejected_keys(self):
        md = (ROOT / "README.md").read_text()
        m = re.search(r"```yaml\n(id: MY_CUSTOM_RULE_001.*?)```", md, re.S)
        block = m.group(1)
        assert "pattern:" not in block, (
            "README teaches `pattern:`; the schema requires `value:` and sets "
            "additionalProperties false, so the rule is silently dropped"
        )


class TestMalformedRulesAreNotSilent:
    """D6 second half: a rule that fails to load must say so."""

    def test_engine_records_skipped_files(self, tmp_path):
        import sys
        sys.path.insert(0, str(ROOT / "packages" / "trustlint"))
        from trustlint.engine import TrustLintEngine

        (tmp_path / "broken.yaml").write_text("id: X\nconditions:\n  - type: regex\n")
        eng = TrustLintEngine(rules_dir=str(tmp_path))
        assert hasattr(eng, "skipped_files"), (
            "engine swallows malformed rule files with no record; an operator "
            "cannot tell their corpus is smaller than they think"
        )

    def test_real_corpus_loads_with_nothing_skipped(self):
        import sys
        sys.path.insert(0, str(ROOT / "packages" / "trustlint"))
        from trustlint.engine import TrustLintEngine

        eng = TrustLintEngine(rules_dir=str(REGS))
        assert eng.skipped_files == [], f"rules failed to load: {eng.skipped_files}"
        assert len(eng.rules) == 64
