#!/usr/bin/env python3
"""Run the false-positive battery through POST /v1/sandbox/check.

Every item in scripts/benchmark/false_positive_battery/*.yaml (plus
prompts/safe_harbor.yaml) is text the engine must ALLOW. Each is posted to the
sandbox endpoint, which shares _evaluate_compliance with /v1/check, so the
verdict is the production verdict and nothing is recorded.

Three engines:

  local (default)  The real FastAPI app in-process, with a local OPA daemon
                   serving the WORKING-TREE rules. Private platform tree only
                   (scripts/validation/false_positive_local_engine.py).
  hosted           The deployed API over HTTP (sandbox, records nothing), to
                   see what production blocks today. Needs COMPLYEDGE_API_KEY.
                   Paced under the sandbox's 60/min throttle. The sandbox caps
                   each tenant at 1,000 checks a day, so a full run is done in
                   slices (--offset / --limit); on the cap it stops and prints
                   the offset to resume from, never sleeps until midnight.
  opa              The same packages and the same `result` documents the API
                   reads (OPAClient.PACKAGES, /v1/data/complyedge/<pkg>/result)
                   in ONE `opa eval` over the whole battery. No Python deps
                   beyond PyYAML: this is the CI guard in rules-validate.yml.

By default every item is checked under EU and US: benign text must pass in
both.

THE BASELINE ONLY SHRINKS. Rules still block some battery items today
(false_positive_baseline.json). CI runs with --baseline: a battery item that
blocks and is NOT in the baseline is a new false positive and fails the run;
a baseline entry that no longer blocks is stale and also fails, so the file
is trimmed in the same change that fixed it. Compared per rule: a baseline
item that starts blocking on a rule its entry does not list is new too. Rewrite it with
--write-baseline only after a rule change that removes entries.

THE MUST-BLOCK GUARD. With --engine opa, every `expected_decision: block`
item in prompts/*.yaml and true_positive_battery/*.yaml is checked under its
own jurisdiction and must block (on its target_rule when it names one). A
regex narrowed to fix a false positive cannot quietly stop catching the real
thing. Some benchmark prompts are written for the whole engine and have no
Rego rule (HIPAA, TCPA, CCPA...): OPA alone passes them today. They sit in
the baseline's `must_block_gaps`, which also only shrinks: a new miss fails,
and a gap that starts blocking must be removed from the list.

Usage:

    .venv/bin/python scripts/benchmark/false_positive_measure.py
    .venv/bin/python scripts/benchmark/false_positive_measure.py --engine hosted \\
        --base-url https://eu.api.complyedge.io

    python scripts/benchmark/false_positive_measure.py --engine opa \\
        --baseline scripts/benchmark/false_positive_baseline.json

Writes scripts/benchmark/results/false_positive_measure_<engine>_latest.json.
Exit code 1 when any item is blocked (outside the baseline when one is
given), when a baseline entry is stale, or when a must-block item passes.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import shutil
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

REPO = Path(__file__).resolve().parents[2]
BATTERY_DIR = Path(__file__).resolve().parent / "false_positive_battery"
SAFE_HARBOR = Path(__file__).resolve().parent / "prompts" / "safe_harbor.yaml"
PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"
MUST_BLOCK_DIR = Path(__file__).resolve().parent / "true_positive_battery"
BASELINE = Path(__file__).resolve().parent / "false_positive_baseline.json"
RESULTS = Path(__file__).resolve().parent / "results"
RULES = REPO / "rules" / "rego" / "complyedge"
JURISDICTIONS = ("EU", "US")
#: Must equal services/api/opa_client.py OPAClient.PACKAGES (asserted in
#: tests/unit/test_false_positive_measure.py). Kept here so the CI guard needs
#: no API dependencies.
PACKAGES = ("article5", "article50", "gpai", "article6", "highrisk", "prompt_security", "us_corpus")


def load_battery(battery_dir: Path = BATTERY_DIR) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in sorted(battery_dir.glob("*.yaml")) + [SAFE_HARBOR]:
        data = yaml.safe_load(path.read_text())
        for p in data["prompts"]:
            if p.get("expected_decision", "allow") != "allow":
                continue
            items.append({**p, "file": path.name, "domain": data.get("domain", path.stem)})
    ids = collections.Counter(i["id"] for i in items)
    dupes = [k for k, n in ids.items() if n > 1]
    if dupes:
        raise SystemExit(f"duplicate ids in battery: {dupes[:10]}")
    return items


def load_must_block(
    prompts_dir: Path = PROMPTS_DIR, must_block_dir: Path = MUST_BLOCK_DIR
) -> list[dict[str, Any]]:
    """Every item the engine must BLOCK: benchmark prompts + the must-block battery."""
    items: list[dict[str, Any]] = []
    for path in sorted(prompts_dir.glob("*.yaml")) + sorted(must_block_dir.glob("*.yaml")):
        data = yaml.safe_load(path.read_text())
        for p in data.get("prompts", []):
            if p.get("expected_decision") == "block":
                items.append({**p, "file": f"{path.parent.name}/{path.name}"})
    ids = collections.Counter(i["id"] for i in items)
    dupes = [k for k, n in ids.items() if n > 1]
    if dupes:
        raise SystemExit(f"duplicate ids in must-block items: {dupes[:10]}")
    return items


def must_block_failures(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Items that did not block, or blocked without their target_rule."""
    fired = opa_batch([(i["text"], i["jurisdiction"]) for i in items])
    failures = []
    for item, rules in zip(items, fired, strict=True):
        target = item.get("target_rule")
        if not rules or (target and target not in rules):
            failures.append(
                {"id": item["id"], "file": item["file"], "target_rule": target, "fired": rules}
            )
    return failures


def baseline_key(item_id: str, jurisdiction: str) -> str:
    return f"{item_id}|{jurisdiction}"


def load_baseline(path: Path) -> dict[str, list[str]]:
    return json.loads(path.read_text())["blocked"]


def load_gaps(path: Path) -> list[str]:
    return json.loads(path.read_text()).get("must_block_gaps", [])


def compare_to_baseline(
    blocked: list[dict[str, Any]], baseline: dict[str, list[str]], *, every_package: bool = True
) -> tuple[list[str], list[str]]:
    """(new false positives, stale baseline entries).

    Compared per rule, not per item: an item in the baseline that now blocks
    on a rule its entry does not list is a NEW false positive (key|rule).
    Comparing item keys alone let a known item pick up a second rule unnoticed.

    every_package=True (the opa engine, which reads every package): a listed
    rule that no longer fires is STALE. The API engines report only the first
    violating package's hits, so for them only an item that no longer blocks
    at all is stale."""
    now = {
        f"{baseline_key(b['id'], b['jurisdiction'])}|{rule}" for b in blocked for rule in set(b["rules"])
    }
    then = {f"{key}|{rule}" for key, rules in baseline.items() for rule in rules}
    if every_package:
        return sorted(now - then), sorted(then - now)
    keys_now = {baseline_key(b["id"], b["jurisdiction"]) for b in blocked}
    return sorted(now - then), sorted(set(baseline) - keys_now)


def _local_engine() -> Any:
    """scripts/validation/false_positive_local_engine.py: private, not exported."""
    sys.path.insert(0, str(REPO / "scripts" / "validation"))
    try:
        from false_positive_local_engine import LocalEngine
    except ImportError as e:
        raise SystemExit(
            "the local engine needs the private platform tree; use --engine opa or hosted"
        ) from e
    return LocalEngine()


def opa_batch(checks: list[tuple[str, str]]) -> list[list[str]]:
    """Rule ids that block each (text, jurisdiction), in one opa process."""
    import subprocess

    opa = shutil.which("opa")
    if not opa:
        raise SystemExit("opa binary not found on PATH")
    query = (
        "x := [ids | some inp in input.items; "
        "ids := [v.rule_id | some p in input.packages; "
        "r := data.complyedge[p].result with input as inp; "
        "r.violation == true; some v in r.violations]]"
    )
    doc = {
        "packages": list(PACKAGES),
        "items": [
            {"text": t, "jurisdiction": j, "law_enforcement_authorised": False}
            for t, j in checks
        ],
    }
    proc = subprocess.run(
        [opa, "eval", "-f", "json", "-d", str(RULES), "--ignore", "*_test.rego", "-I", query],
        input=json.dumps(doc),
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(proc.stdout)["result"][0]["bindings"]["x"]


class DailyCapReached(RuntimeError):
    """The sandbox's per-tenant daily cap answered 429 (it resets at 00:00 UTC)."""


#: The hosted sandbox's per-tenant daily cap (API reference, /v1/sandbox/check).
#: A full run is ~2,370 checks: run it in slices with --offset / --limit.
HOSTED_DAILY_CHECKS = 1000


class HostedEngine:
    """The deployed API's sandbox over HTTP. Records nothing."""

    def __init__(self, base_url: str) -> None:
        import httpx

        key = os.environ.get("COMPLYEDGE_API_KEY")
        if not key:
            raise SystemExit("COMPLYEDGE_API_KEY is not set")
        self._http = httpx.Client(
            base_url=base_url, timeout=30, headers={"Authorization": f"Bearer {key}"}
        )
        self._last = 0.0
        self.label = f"hosted {base_url} /v1/sandbox/check"

    def check(self, text: str, jurisdiction: str) -> dict[str, Any]:
        for _ in range(5):
            wait = 1.1 - (time.monotonic() - self._last)  # under 60/min
            if wait > 0:
                time.sleep(wait)
            self._last = time.monotonic()
            r = self._http.post(
                "/v1/sandbox/check",
                json={"text": text, "agent_id": "fp-measure", "jurisdiction": jurisdiction},
            )
            if r.status_code == 429:
                try:
                    detail = (r.json() or {}).get("detail") or {}
                except ValueError:  # a 429 from the gateway, not the API: not JSON
                    detail = {}
                if isinstance(detail, dict) and detail.get("error") == "sandbox_daily_limit_exceeded":
                    # Never sleep until midnight: stop and say where to resume.
                    raise DailyCapReached(r.headers.get("Retry-After", ""))
                time.sleep(int(r.headers.get("Retry-After", "60")))
                continue
            r.raise_for_status()
            return r.json()
        raise RuntimeError("sandbox kept returning 429")

    def close(self) -> None:
        self._http.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--engine", choices=("local", "hosted", "opa"), default="local")
    ap.add_argument("--base-url", default="https://eu.api.complyedge.io")
    ap.add_argument(
        "--own-jurisdiction-only",
        action="store_true",
        help="check each item only under its own jurisdiction (default: EU and US)",
    )
    ap.add_argument("--battery-dir", type=Path, default=BATTERY_DIR)
    ap.add_argument(
        "--baseline",
        type=Path,
        help="fail only on blocks outside this baseline, and on stale baseline entries",
    )
    ap.add_argument("--offset", type=int, default=0, help="skip the first N checks")
    ap.add_argument("--limit", type=int, help=f"run at most N checks (hosted: at most {HOSTED_DAILY_CHECKS} a day)")
    ap.add_argument(
        "--write-baseline",
        type=Path,
        help="write today's blocked items to this file as the new baseline",
    )
    args = ap.parse_args()

    items = load_battery(args.battery_dir)
    pairs = [
        (item, jur)
        for item in items
        for jur in ((item["jurisdiction"],) if args.own_jurisdiction_only else JURISDICTIONS)
    ]
    total_pairs = len(pairs)
    pairs = pairs[args.offset :][: args.limit] if args.limit is not None else pairs[args.offset :]
    if args.engine == "hosted" and len(pairs) > HOSTED_DAILY_CHECKS:
        raise SystemExit(
            f"{len(pairs)} checks exceed the sandbox's {HOSTED_DAILY_CHECKS}/day cap: "
            f"run slices, e.g. --offset 0 --limit {HOSTED_DAILY_CHECKS}, then "
            f"--offset {HOSTED_DAILY_CHECKS} the next day"
        )
    partial = len(pairs) != total_pairs
    if partial and (args.baseline or args.write_baseline):
        raise SystemExit("--baseline / --write-baseline need the whole battery (no --offset / --limit)")
    blocked: list[dict[str, Any]] = []
    by_rule: collections.Counter[str] = collections.Counter()
    errors: list[dict[str, Any]] = []
    started = time.monotonic()

    def record(item: dict[str, Any], jur: str, rules: list[str], engine_path: str | None) -> None:
        by_rule.update(rules)
        blocked.append(
            {
                "id": item["id"],
                "domain": item["domain"],
                "jurisdiction": jur,
                "rules": rules,
                "engine_path": engine_path,
                "text": item["text"],
            }
        )

    if args.engine == "opa":
        label = f"opa eval over {RULES.relative_to(REPO)} (OPAClient packages)"
        for (item, jur), rules in zip(
            pairs, opa_batch([(i["text"], j) for i, j in pairs]), strict=True
        ):
            if rules:
                record(item, jur, rules, "opa")
    else:
        engine = _local_engine() if args.engine == "local" else HostedEngine(args.base_url)
        label = engine.label
        try:
            for n, (item, jur) in enumerate(pairs):
                try:
                    res = engine.check(item["text"], jur)
                except DailyCapReached:
                    resume = args.offset + n
                    print(f"sandbox daily cap reached: resume tomorrow with --offset {resume}")
                    errors.extend(
                        {"id": i["id"], "jurisdiction": j, "error": "not checked: sandbox daily cap reached"}
                        for i, j in pairs[n:]
                    )
                    break
                except Exception as e:  # noqa: BLE001 - recorded, never counted as allow
                    errors.append({"id": item["id"], "jurisdiction": jur, "error": str(e)[:200]})
                    continue
                if not res.get("allowed", True):
                    record(item, jur, [v["rule_id"] for v in res.get("violations", [])], res.get("engine_path"))
        finally:
            engine.close()
    checks = len(pairs)

    summary = {
        "run_at": datetime.now(UTC).isoformat(),
        "engine": label,
        "items": len(items),
        "checks": checks,
        "offset": args.offset,
        "battery_checks": total_pairs,
        "blocked": len(blocked),
        "errors": len(errors),
        "false_positive_rate": round(len(blocked) / checks, 4) if checks else None,
        "blocked_by_rule": dict(by_rule.most_common()),
        "seconds": round(time.monotonic() - started, 1),
    }
    RESULTS.mkdir(exist_ok=True)
    out = RESULTS / f"false_positive_measure_{args.engine}_latest.json"
    out.write_text(json.dumps({**summary, "blocked_items": blocked, "error_items": errors}, indent=2))

    print(f"{summary['engine']}")
    print(f"items {summary['items']} · checks {checks} · blocked {len(blocked)} · errors {len(errors)}")
    for rule, n in by_rule.most_common():
        print(f"  {n:4d}  {rule}")
    print(f"written {out.relative_to(REPO)}")

    failed = bool(errors)
    misses: list[dict[str, Any]] = []
    must: list[dict[str, Any]] = []
    if args.engine == "opa":
        must = load_must_block()
        misses = must_block_failures(must)
    if args.write_baseline:
        doc = {
            "note": "Battery items the rules still block. May only shrink: see false_positive_measure.py.",
            "engine": label,
            "blocked": {
                baseline_key(b["id"], b["jurisdiction"]): sorted(b["rules"])
                for b in sorted(blocked, key=lambda b: (b["id"], b["jurisdiction"]))
            },
            "must_block_gaps": sorted(f["id"] for f in misses if f["file"].startswith("prompts/")),
        }
        args.write_baseline.write_text(json.dumps(doc, indent=1, sort_keys=False) + "\n")
        print(f"baseline written: {len(doc['blocked'])} entries -> {args.write_baseline}")
    elif args.baseline:
        new, stale = compare_to_baseline(
            blocked, load_baseline(args.baseline), every_package=args.engine == "opa"
        )
        print(f"baseline {args.baseline.name}: new false positives {len(new)} · stale entries {len(stale)}")
        for k in new[:50]:
            print(f"  NEW   {k}")
        for k in stale[:50]:
            print(f"  STALE {k} (no longer blocks: remove it from the baseline)")
        failed = failed or bool(new or stale)
    else:
        failed = failed or bool(blocked)

    if args.engine == "opa":
        gaps = set(load_gaps(args.baseline)) if args.baseline else set()
        new_misses = [f for f in misses if f["id"] not in gaps]
        closed = sorted(gaps - {f["id"] for f in misses})
        print(
            f"must-block items {len(must)} · passed through {len(misses)} · "
            f"known gaps {len(gaps)} · new misses {len(new_misses)} · closed gaps {len(closed)}"
        )
        for f in new_misses[:50]:
            print(f"  MISSED {f['id']} ({f['file']}) target={f['target_rule']} fired={f['fired']}")
        for g in closed:
            print(f"  CLOSED {g} (blocks now: remove it from must_block_gaps)")
        if not args.write_baseline:
            failed = failed or bool(new_misses or closed)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
