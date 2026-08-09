"""Regression tests — statutes are cited from official sources, never mirrors.

Ledger: ledger/tenants/leocelis/feedback/complyedge/product_review_feedback.yaml
        :: PRV-058 (2026-08-06)

INCIDENT
--------
GDPR Art 5(1)(c) and EU AI Act Art 53 were quoted from an UNOFFICIAL MIRROR. The
product is sold on the accuracy of its regulatory citations, so a statute quoted from
a mirror is a defect in the artifact being sold: the mirror can drift from the Official
Journal without any signal, and the quote then misstates the law while looking sourced.

The fix re-pointed both at EUR-Lex and verified the stored quote verbatim against the
Official Journal (OJ L 119, 4.5.2016 p. 35; OJ L, 12.7.2024 p. 84).

THE PROPERTY
------------
Not "these two files were edited" — that is the symptom. The property is that NO
statute citation in the corpus resolves to a non-official host, so re-introducing a
mirror anywhere in the corpus fails, including in a rule added later.

Complements test_rules_corpus_regressions.py, which asserts citation COVERAGE
(every rule carries a verbatim citation). Coverage and provenance are different
claims: a rule can carry a verbatim citation that came from the wrong place.
"""

from __future__ import annotations

import os
import re

import pytest
import yaml

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", ".."))
_RULES = os.path.join(_REPO, "rules", "regulations")

#: Hosts that publish EU law itself, not a copy of it. The strict allowlist below
#: is scoped to the EU corpus because that is what PRV-058 actually re-pointed and
#: verified verbatim against the Official Journal.
_OFFICIAL_EU_HOSTS = {
    "eur-lex.europa.eu",       # Official Journal of the European Union
    "op.europa.eu",            # EU Publications Office
    "data.europa.eu",
}

#: EU rule files — the scope PRV-058 fixed and verified.
_EU_SUBDIR = os.path.join("regulations", "eu")

#: Known mirrors and secondary publishers. Readable, useful, NOT authoritative.
_KNOWN_MIRRORS = {
    "gdpr-info.eu",
    "www.gdpr-info.eu",
    "gdpr-text.com",
    "artificialintelligenceact.eu",
    "www.artificialintelligenceact.eu",
    "wikipedia.org",
    "en.wikipedia.org",
}

_URL = re.compile(r"https?://([A-Za-z0-9.\-]+)")


def _rule_files() -> list[str]:
    if not os.path.isdir(_RULES):
        pytest.skip(f"rules corpus not found at {_RULES}")
    out = []
    for root, _dirs, files in os.walk(_RULES):
        out += [os.path.join(root, f) for f in files if f.endswith((".yaml", ".yml"))]
    return sorted(out)


def _citation_hosts(path: str) -> set[str]:
    """Hosts appearing in the rule's SOURCE block — the provenance of the quote."""
    with open(path, encoding="utf-8") as fh:
        try:
            doc = yaml.safe_load(fh.read())
        except yaml.YAMLError:
            return set()
    if not isinstance(doc, dict):
        return set()
    source = doc.get("source") or {}
    blob = " ".join(str(v) for v in source.values()) if isinstance(source, dict) else str(source)
    return set(_URL.findall(blob))


class TestNoStatuteIsCitedFromAMirror:
    def test_corpus_is_not_empty(self):
        """Guards every assertion below from passing vacuously."""
        assert len(_rule_files()) > 10

    def test_no_rule_sources_a_known_mirror(self):
        offenders = {
            os.path.relpath(p, _REPO): sorted(hosts & _KNOWN_MIRRORS)
            for p in _rule_files()
            if (hosts := _citation_hosts(p)) & _KNOWN_MIRRORS
        }
        assert not offenders, (
            "statutes cited from unofficial mirrors — a mirror can drift from the "
            f"Official Journal with no signal: {offenders}"
        )

    def test_every_eu_rule_cites_an_official_eu_publisher(self):
        """Stronger than the mirror blocklist, and scoped to what PRV-058 verified.

        A blocklist alone only catches the mirrors that already burned us, which is
        exactly how PRV-058 happened. An allowlist catches the next one too.

        SCOPE: EU only. The US corpus currently cites Cornell LII
        (www.law.cornell.edu) for SOX, HIPAA, ECPA and TCPA — a secondary publisher,
        the same defect class PRV-058 fixed for the EU, still open. Widening this
        test to the US corpus today would make it fail on a defect nobody has
        decided to fix yet; it is logged as an open finding instead of being
        silently absorbed into an allowlist here.
        """
        eu_files = [p for p in _rule_files() if _EU_SUBDIR in p]
        assert eu_files, "no EU rule files found — the assertion below would be vacuous"
        unknown = {}
        for path in eu_files:
            extra = _citation_hosts(path) - _OFFICIAL_EU_HOSTS
            if extra:
                unknown[os.path.relpath(path, _REPO)] = sorted(extra)
        assert not unknown, (
            "EU rule sources cite hosts that are not official EU publishers. If one "
            "of these IS official, add it to _OFFICIAL_EU_HOSTS with a comment "
            f"naming the body that publishes it: {unknown}"
        )
