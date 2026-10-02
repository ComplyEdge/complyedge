#!/usr/bin/env python3
"""Measure the rule-hit confirmer: false positives it lifts, real blocks it keeps.

Runs services/api/rule_hit_confirmer.review_hits in-process, the function
/v1/check calls on Layer 2 when a rule fires. No API, no tenant, no audit
record. Two sets:

  false positives  every entry in false_positive_baseline.json: battery text
                   a rule still blocks. The confirmer SHOULD clear these.
  must block       true_positive_battery/*.yaml plus the benchmark prompts
                   OPA blocks. The confirmer must clear NONE of them.

Each text is judged once on the rules OPA fired for it. The answers are kept
with their confidence, so every clear threshold is evaluated from one run:
CE_CONFIRM_CLEAR_MIN is the lowest threshold at which no must-block item is
cleared.

Cost is hard-capped (--max-usd, default $5) through llm_budget, and the
projected worst case is printed before the first call.

Usage:

    set -a; . ./.env; set +a
    .venv/bin/python scripts/benchmark/confirm_measure.py
    .venv/bin/python scripts/benchmark/confirm_measure.py --limit 20   # smoke

Writes scripts/benchmark/results/confirm_measure_latest.json.
Exit code 1 when any must-block item is cleared at the shipped CLEAR_MIN, or
when the judge failed to answer on more than 2% of texts.
"""

from __future__ import annotations

import argparse
import asyncio
import collections
import json
import statistics
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import structlog

REPO = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO / "services" / "api"))
sys.path.insert(0, str(HERE))

import false_positive_measure as fpm  # noqa: E402

OUT = HERE / "results" / "confirm_measure_latest.json"
THRESHOLDS = (0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 0.96, 0.97, 0.98, 0.99)

_usage: list[dict[str, Any]] = []


def _capture_usage(_, __, event_dict):
    if event_dict.get("event") == "LLM API call completed" and event_dict.get("usage"):
        _usage.append({"model": event_dict.get("model"), **event_dict["usage"]})
    raise structlog.DropEvent


def false_positive_cases(baseline: Path) -> list[dict[str, Any]]:
    by_id = {i["id"]: i for i in fpm.load_battery()}
    cases = []
    for key, rules in fpm.load_baseline(baseline).items():
        item_id, jur = key.split("|")
        item = by_id[item_id]
        cases.append(
            {"set": "false_positive", "id": key, "domain": item["domain"], "jurisdiction": jur,
             "text": item["text"], "fired": rules}
        )
    return cases


def must_block_cases() -> list[dict[str, Any]]:
    items = fpm.load_must_block()
    fired = fpm.opa_batch([(i["text"], i["jurisdiction"]) for i in items])
    return [
        {"set": "must_block", "id": i["id"], "domain": i["file"], "jurisdiction": i["jurisdiction"],
         "framing": i.get("framing", "benchmark"), "text": i["text"],
         "fired": rules}
        for i, rules in zip(items, fired, strict=True)
        if rules  # items OPA passes are known gaps: nothing for the confirmer to lift
    ]


def projected_worst_case_micros(cases: list[dict[str, Any]], model: str) -> int:
    import llm_budget
    import prompt_injection_classifier as pic
    import rule_hit_confirmer as rhc

    ps_ids = rhc.prompt_security_rule_ids()
    inj_system = len(pic._system_prompt(pic.load_categories(), "0" * 16).encode())
    total = 0
    for c in cases:
        msgs = rhc.messages_for(c["text"], c["fired"], "0" * 16)
        total += llm_budget.max_cost_micros(model, msgs, rhc.MAX_COMPLETION_TOKENS)
        if any(r in ps_ids for r in c["fired"]):
            for chunk in pic.chunks(c["text"]):
                total += llm_budget.max_cost_for_bytes(model, inj_system + len(chunk.encode()) + 64, 2, 400)
    return total


async def _run(cases: list[dict[str, Any]], model: str, concurrency: int) -> list[dict[str, Any]]:
    import rule_hit_confirmer as rhc

    sem = asyncio.Semaphore(concurrency)
    rows: list[dict[str, Any]] = []

    async def one(c: dict[str, Any]) -> None:
        async with sem:
            t0 = time.perf_counter()
            review = await rhc.review_hits(c["text"], c["fired"], model=model)
            ms = (time.perf_counter() - t0) * 1000
        verdicts = (
            [{"rule_id": v.rule_id, "decision": v.decision, "confidence": v.confidence, "reason": v.reason}
             for v in review.confirm.verdicts]
            if review.confirm is not None
            else []
        )
        inj = review.injection
        rows.append({
            **{k: v for k, v in c.items() if k != "text"},
            "text": c["text"][:300],
            "answered": review.answered,
            "confirm_error": review.confirm.error if review.confirm is not None else None,
            "verdicts": verdicts,
            "injection": None if inj is None else {
                "available": inj.available,
                "category": inj.category.rule_id if inj.category else None,
                "confidence": inj.confidence,
                "reason": inj.reason,
            },
            "cleared_at": {str(t): review.cleared(t) for t in THRESHOLDS},
            "latency_ms": round(ms),
        })

    await asyncio.gather(*(one(c) for c in cases))
    rows.sort(key=lambda r: (r["set"], r["id"]))
    return rows


def _rate(rows: list[dict[str, Any]], t: float) -> int:
    return sum(r["cleared_at"][str(t)] for r in rows)


def main() -> int:
    import llm_budget
    import rule_hit_confirmer as rhc

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--model", default=rhc.CONFIRM_MODEL)
    ap.add_argument("--concurrency", type=int, default=8)
    ap.add_argument("--max-usd", type=float, default=5.0, help="hard cap on this run's model spend")
    ap.add_argument("--baseline", type=Path, default=fpm.BASELINE)
    ap.add_argument("--limit", type=int, help="first N cases of each set (smoke run)")
    args = ap.parse_args()

    fp, mb = false_positive_cases(args.baseline), must_block_cases()
    if args.limit:
        fp, mb = fp[: args.limit], mb[: args.limit]
    cases = fp + mb
    worst = projected_worst_case_micros(cases, args.model)
    print(
        f"{len(fp)} false positives + {len(mb)} must-block texts on {args.model}. "
        f"Worst case ${worst / 1e6:.2f}; hard cap ${args.max_usd:.2f}."
    )

    structlog.configure(processors=[_capture_usage])
    budget = llm_budget.run_budget(OUT.stem, args.max_usd)
    started = time.monotonic()
    with llm_budget.bound(budget):
        rows = asyncio.run(_run(cases, args.model, args.concurrency))
    spent = budget.store.spent(budget.tenant_id, budget.period)

    fp_rows = [r for r in rows if r["set"] == "false_positive"]
    mb_rows = [r for r in rows if r["set"] == "must_block"]
    unanswered = [r for r in rows if not r["answered"]]
    safe = [t for t in THRESHOLDS if _rate(mb_rows, t) == 0]
    recommended = min(safe) if safe else None

    by_domain: dict[str, list[int]] = collections.defaultdict(lambda: [0, 0])
    t_ship = rhc.CLEAR_MIN
    for r in fp_rows:
        by_domain[r["domain"]][1] += 1
        by_domain[r["domain"]][0] += r["cleared_at"].get(str(t_ship), False)
    leaks = [r for r in mb_rows if r["cleared_at"].get(str(t_ship), False)]
    lat = [r["latency_ms"] for r in rows]
    report = {
        "run_at": datetime.now(UTC).isoformat(),
        "model": args.model,
        "shipped_clear_min": t_ship,
        "recommended_clear_min": recommended,
        "texts": len(rows),
        "llm_calls": len(_usage),
        "unanswered": len(unanswered),
        "spent_usd": round(spent / 1e6, 4),
        "usd_per_text": round(spent / 1e6 / len(rows), 6) if rows else None,
        "prompt_tokens_mean": round(statistics.mean(u.get("prompt_tokens", 0) for u in _usage)) if _usage else None,
        "completion_tokens_mean": round(statistics.mean(u.get("completion_tokens", 0) for u in _usage)) if _usage else None,
        "latency_ms_p50": statistics.median(lat) if lat else None,
        "latency_ms_p95": sorted(lat)[int(0.95 * (len(lat) - 1))] if lat else None,
        "seconds": round(time.monotonic() - started, 1),
        "by_threshold": {
            str(t): {"false_positives_cleared": _rate(fp_rows, t), "must_block_cleared": _rate(mb_rows, t)}
            for t in THRESHOLDS
        },
        "false_positives_cleared_by_domain_at_shipped": {d: f"{c}/{n}" for d, (c, n) in sorted(by_domain.items())},
        "must_block_cleared_at_shipped": [r["id"] for r in leaks],
        "rows": rows,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")

    print(f"spent ${report['spent_usd']} over {report['llm_calls']} calls · ${report['usd_per_text']}/text")
    print(f"latency p50 {report['latency_ms_p50']}ms · p95 {report['latency_ms_p95']}ms · unanswered {len(unanswered)}")
    print("threshold  false positives cleared  must-block cleared")
    for t in THRESHOLDS:
        b = report["by_threshold"][str(t)]
        print(f"  {t:<8} {b['false_positives_cleared']:>5}/{len(fp_rows):<17} {b['must_block_cleared']}/{len(mb_rows)}")
    print(f"recommended CE_CONFIRM_CLEAR_MIN: {recommended} (shipped {t_ship})")
    for d, v in report["false_positives_cleared_by_domain_at_shipped"].items():
        print(f"  {d:<22} {v}")
    for r in leaks[:30]:
        print(f"  LEAK {r['id']} fired={r['fired']}")
    print(f"written {OUT.relative_to(REPO)}")
    too_many_unanswered = len(unanswered) > 0.02 * max(1, len(rows))
    return 1 if leaks or too_many_unanswered else 0


if __name__ == "__main__":
    sys.exit(main())
