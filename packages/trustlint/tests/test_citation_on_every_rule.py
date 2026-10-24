"""Every bundled rule gives its findings a citation.

Regression (2026-10-19): PCI_DSS_INPUT_001 and UNIVERSAL_PII_INPUT_001 rest on no
legal article (an industry standard and a detection control). They carry
provision_label but no citation, and the engine read only citation / citations, so a
card number came back with an empty citation.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from trustlint.engine import TrustLintEngine

BUNDLED = Path(__file__).resolve().parents[1] / "trustlint" / "rules"
CANONICAL = Path(__file__).resolve().parents[3] / "rules" / "regulations"


@pytest.mark.parametrize("rules_dir", [BUNDLED, CANONICAL])
def test_every_rule_has_a_citation(rules_dir: Path):
    engine = TrustLintEngine(rules_dir=str(rules_dir))
    assert len(engine.rules) > 50
    assert [r.id for r in engine.rules if not r.citation.strip()] == []


def test_card_number_finding_names_the_standard():
    engine = TrustLintEngine(rules_dir=str(BUNDLED))
    hits = [
        v
        for v in engine.check("Charge card 4111111111111111 for the order.").violations
        if v.rule_id == "PCI_DSS_INPUT_001"
    ]
    assert hits and "PCI DSS" in hits[0].citation and "not law" in hits[0].citation
