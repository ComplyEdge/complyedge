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


class TestRegoCitationsMatchTheRegulationCorpus:
    """The Rego `citation` string is what the API returns as
    `rule_description`, and it is what a buyer reads in the audit export.

    Incident: every one of the 40 Rego citations that had a regulation+article
    sibling in rules/regulations/ was a hand-written paraphrase, not the
    statutory text. For Article 5(1)(c) the shipped string dropped "over a
    certain period of time", "known, inferred or predicted", and the "either
    or both" (i)/(ii) structure. The substance of the block was right; the
    quoted law was not, which is the one claim a paid "regulator-ready" pack
    rests on. Counsel comparing an export to EUR-Lex would have found it.

    The YAML corpus is the audited source of truth for citations. This asserts
    the Rego copies have not drifted from it again.
    """

    @staticmethod
    def _yaml_citations():
        import yaml as _y

        out = {}
        for f in REGS.rglob("*.yaml"):
            d = _y.safe_load(f.read_text()) or {}
            src = d.get("source") or {}
            reg, art, cit = src.get("regulation"), src.get("article"), src.get("citation")
            if reg and art and cit:
                out.setdefault((str(reg).strip(), str(art).strip()), []).append((f.stem, cit))
        return out

    @staticmethod
    def _rego_files():
        return sorted((ROOT / "rules/rego/complyedge").rglob("*.rego"))

    def test_rego_citation_equals_its_regulation_sibling(self):
        import re as _re

        ymap = self._yaml_citations()
        drifted = []
        for f in self._rego_files():
            txt = f.read_text()
            m = _re.search(r'^citation := "(.*)"\s*$', txt, _re.M)
            if not m:
                continue
            head_m = _re.search(r"^# Legal citation:\s*(.+)$", txt, _re.M)
            head = head_m.group(1) if head_m else ""
            art_m = _re.search(r"(Article\s+[0-9]+(?:\([0-9a-z]+\))*)", head)
            art = art_m.group(1) if art_m else None
            reg = (
                "EU AI Act"
                if "2024/1689" in head
                else ("GDPR" if "GDPR" in head or "2016/679" in head else None)
            )
            cands = ymap.get((reg, art), [])
            if len(cands) > 1:
                cands = [c for c in cands if c[0].endswith(f.stem)]
            if len(cands) != 1:
                # No unambiguous sibling: not covered by the corpus, and not
                # something this test can invent an answer for.
                continue
            if cands[0][1] != m.group(1):
                drifted.append(f.name)
        assert not drifted, (
            "Rego citations no longer quote their regulation corpus sibling "
            f"(the API returns these verbatim as rule_description): {drifted}"
        )

    def test_the_article5_1c_citation_carries_the_clauses_that_were_dropped(self):
        """Anchored on the exact fragments the paraphrase omitted, so a future
        rewrite that is merely longer does not pass by accident."""
        import re as _re

        f = ROOT / "rules/rego/complyedge/article5/social_scoring.rego"
        cit = _re.search(r'^citation := "(.*)"\s*$', f.read_text(), _re.M).group(1)
        for fragment in (
            "over a certain period of time",
            "known, inferred or predicted",
            "either or both",
        ):
            assert fragment in cit, f"Article 5(1)(c) citation lost {fragment!r}"
