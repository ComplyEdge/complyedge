"""Every Rego rule meets the RULE_STANDARD §4.1 test minimum.

§4.1 asks each rule for at least two true positives, one true negative and,
where it applies to one jurisdiction, a jurisdiction guard. On 2026-10-21, 48 of
the 75 approved leaves were short (35 had one true positive or none, 17 had no
jurisdiction guard, SOX had no true negative) while the standard said every
approved rule conformed.

Counting by test name or by text does not work: many tests reach a rule
through its package aggregator or a helper. So the count is by execution, on a
copy of rules/rego:

    true positive   fails when the rule's `violation` can never be true
    negative        fails when the rule's `violation` is always true
    guard           fails when the rule's jurisdiction condition is replaced by
                    `true` (the aggregator's, when the rule has none of its own)

A negative that is not a guard is a true negative. A rule with no jurisdiction
condition anywhere (prompt injection, Article 15(5)) applies everywhere and
needs no guard.
"""

from __future__ import annotations

import json
import pathlib
import re
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
REGO = ROOT / "rules" / "rego"
OPA = shutil.which("opa")

pytestmark = pytest.mark.skipif(OPA is None, reason="opa is not installed")

_GATE = re.compile(
    r'input\.jurisdiction\s*==\s*"[A-Z]+"|startswith\(input\.jurisdiction,\s*"[A-Z]+"\)'
)


def _leaves() -> list[pathlib.Path]:
    return sorted(
        f
        for f in REGO.rglob("*.rego")
        if "/test/" not in f.as_posix()
        and re.search(r"^rule_id\s*:?=", f.read_text(), re.M)
    )


def _never(src: str) -> str:
    return re.sub(
        r"^violation(\s+(?:if|contains|:=|=))", r"_off_violation\1", src, flags=re.M
    )


def _always(src: str) -> str:
    return _never(src).replace(
        "default violation := false", "default violation := true"
    )


@pytest.fixture(scope="module")
def corpus(tmp_path_factory):
    work = tmp_path_factory.mktemp("rego") / "rego"
    shutil.copytree(REGO, work)

    def failing(path: pathlib.Path, new_src: str) -> set[str]:
        target = work / path.relative_to(REGO)
        original = target.read_text()
        target.write_text(new_src)
        try:
            out = subprocess.run(
                [OPA, "test", str(work), "--format", "json"],
                capture_output=True,
                text=True,
            ).stdout
        finally:
            target.write_text(original)
        return {r["name"] for r in json.loads(out) if r.get("fail") or r.get("error")}

    return failing


@pytest.mark.parametrize(
    "leaf", _leaves(), ids=lambda p: p.relative_to(REGO / "complyedge").as_posix()
)
def test_rule_meets_the_test_minimum(corpus, leaf):
    src = leaf.read_text()
    assert (
        "default violation := false" in src
    ), "the count needs `default violation := false`"
    positives = corpus(leaf, _never(src))
    negatives = corpus(leaf, _always(src))

    aggregator = leaf.parent / f"{leaf.parent.name}.rego"
    if _GATE.search(src):
        guards = corpus(leaf, _GATE.sub("true", src))
    elif _GATE.search(aggregator.read_text()):
        guards = corpus(aggregator, _GATE.sub("true", aggregator.read_text()))
    else:
        guards = None  # applies in every jurisdiction

    assert len(positives) >= 2, f"true positives: {sorted(positives)}"
    assert negatives - (guards or set()), "no true negative"
    if guards is not None:
        assert guards, "no jurisdiction guard"
