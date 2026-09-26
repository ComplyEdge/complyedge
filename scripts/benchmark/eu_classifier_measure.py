#!/usr/bin/env python3
"""Measure the EU AI Act classifier on its case fixture and the safe-harbor set.

Calls the classifier in-process (services/api/eu_ai_act_classifier.py). No API,
no tenant, no audit record. One LLM call per case; the run prints calls,
tokens and latency so the cost of the default-on path is visible.

Usage:

    set -a; . ./.env; set +a
    .venv/bin/python scripts/benchmark/eu_classifier_measure.py --model gpt-5.4

Writes scripts/benchmark/results/eu_classifier_measure_latest.json.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import statistics
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

import structlog
import yaml

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "services" / "api"))

CASES = REPO / "tests" / "fixtures" / "eu_ai_act_classifier_cases.yaml"
SAFE_HARBOR = REPO / "scripts" / "benchmark" / "prompts" / "safe_harbor.yaml"
OUT = Path(__file__).resolve().parent / "results" / "eu_classifier_measure_latest.json"

_usage: list[dict] = []


def _capture_usage(_, __, event_dict):
    if event_dict.get("event") == "LLM API call completed" and event_dict.get("usage"):
        _usage.append(event_dict["usage"])
    raise structlog.DropEvent


def _cases() -> list[dict]:
    cases = list(yaml.safe_load(CASES.read_text())["cases"])
    for p in yaml.safe_load(SAFE_HARBOR.read_text())["prompts"]:
        cases.append({"id": p["id"], "expected": "none", "text": p["text"], "basis": "safe_harbor"})
    return cases


async def _run(model: str, concurrency: int) -> dict:
    import eu_ai_act_classifier as clf

    sem = asyncio.Semaphore(concurrency)
    rows: list[dict] = []

    async def one(case: dict) -> None:
        async with sem:
            t0 = time.perf_counter()
            v = await clf.classify(case["text"], model=model)
            ms = (time.perf_counter() - t0) * 1000
        expected = case["expected"]
        allowed = expected if isinstance(expected, list) else [expected]
        got = v.category.rule_id if v.category else "none"
        rows.append({
            "id": case["id"], "expected": expected, "got": got,
            "available": v.available, "correct": v.available and got in allowed,
            "confidence": v.confidence, "reason": v.reason, "latency_ms": round(ms),
        })

    await asyncio.gather(*(one(c) for c in _cases()))
    rows.sort(key=lambda r: r["id"])
    blocks = [r for r in rows if r["expected"] != "none"]
    passes = [r for r in rows if r["expected"] == "none"]
    lat = [r["latency_ms"] for r in rows]
    return {
        "model": model,
        "run_at": datetime.now(UTC).isoformat(),
        "calls": len(rows),
        "unavailable": sum(not r["available"] for r in rows),
        "should_block_caught": f"{sum(r['correct'] for r in blocks)}/{len(blocks)}",
        "should_pass_passed": f"{sum(r['correct'] for r in passes)}/{len(passes)}",
        "latency_ms_p50": statistics.median(lat),
        "latency_ms_max": max(lat),
        "prompt_tokens_mean": round(statistics.mean(u.get("prompt_tokens", 0) for u in _usage)) if _usage else None,
        "completion_tokens_mean": round(statistics.mean(u.get("completion_tokens", 0) for u in _usage)) if _usage else None,
        "cached_tokens_mean": round(statistics.mean((u.get("prompt_tokens_details") or {}).get("cached_tokens", 0) for u in _usage)) if _usage else None,
        "rows": rows,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--concurrency", type=int, default=4)
    args = ap.parse_args()
    structlog.configure(processors=[_capture_usage])
    report = asyncio.run(_run(args.model, args.concurrency))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2) + "\n")
    for r in report["rows"]:
        mark = "ok " if r["correct"] else "BAD"
        print(f"{mark} {r['id']:<38} expected={r['expected']!s:<34} got={r['got']:<26} {r['latency_ms']}ms")
    summary = {k: v for k, v in report.items() if k != "rows"}
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
