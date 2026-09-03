#!/usr/bin/env python3
"""Phase 1 measurement: injection-detection gap fixtures against /v1/check.

Runs each fixture twice — use_semantic_fallback false, then true — and writes
a JSON report under scripts/benchmark/results/.

Usage (local API with OPA + DEV_API_KEY):

    export DEV_API_KEY=ce_dev_key_123456789
    ./run.sh api   # separate terminal
    .venv/bin/python scripts/benchmark/injection_gap_measure.py \\
        --base-url http://127.0.0.1:18800 \\
        --api-key "$DEV_API_KEY"

Cost note: the semantic=true arm is one LLM call per fixture (~11 calls).
Price before a live-API run; prefer local.
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

import httpx
import yaml

REPO = Path(__file__).resolve().parents[2]
FIXTURE = REPO / "tests" / "fixtures" / "injection_detection_gap.yaml"
RESULTS = Path(__file__).resolve().parent / "results"
OUT = RESULTS / "injection_gap_measure_latest.json"

# Rough gpt-4o-mini input+output for evaluate_fast (~700 tokens in, ~80 out).
# Operator-facing estimate only — not a billing oracle.
USD_PER_SEMANTIC_CALL = 0.00015


def _load_fixtures() -> list[dict]:
    raw = yaml.safe_load(FIXTURE.read_text(encoding="utf-8"))
    return list(raw["fixtures"])


def _check(
    client: httpx.Client,
    *,
    text: str,
    semantic: bool,
    jurisdiction: str = "EU",
) -> dict:
    started = time.perf_counter()
    resp = client.post(
        "/v1/check",
        json={
            "text": text,
            "jurisdiction": jurisdiction,
            "agent_id": "injection-gap-measure",
            "use_semantic_fallback": semantic,
        },
    )
    latency_ms = (time.perf_counter() - started) * 1000
    try:
        body = resp.json()
    except Exception:
        body = {"raw": resp.text[:500]}
    allowed = body.get("allowed")
    if allowed is True:
        verdict = "allow"
    elif allowed is False:
        verdict = "block"
    else:
        verdict = "unavailable"
    rule_ids = [
        v.get("rule_id")
        for v in (body.get("violations") or [])
        if isinstance(v, dict)
    ]
    return {
        "http_status": resp.status_code,
        "verdict": verdict,
        "allowed": allowed,
        "engine_path": body.get("engine_path"),
        "rule_ids": rule_ids,
        "evaluated_rules": body.get("evaluated_rules"),
        "error": body.get("error"),
        "latency_ms": round(latency_ms, 1),
    }


def _arm_summary(rows: list[dict], arm: str, switch: str) -> dict:
    subset = [r for r in rows if r["arm"] == arm and r["switch"] == switch]
    if not subset:
        return {"n": 0, "detection_rate": None, "false_positive_rate": None}
    if arm == "D":
        # Benign: FP = blocked when should allow
        fp = sum(1 for r in subset if r["result"]["verdict"] == "block")
        return {
            "n": len(subset),
            "false_positive_rate": round(fp / len(subset), 3),
            "detection_rate": None,
        }
    # A/B/C attack arms: detection = blocked when expected_semantic is block
    # (for opa switch, use expected_opa)
    key = "expected_opa" if switch == "opa" else "expected_semantic"
    attack = [r for r in subset if r[key] == "block"]
    if not attack:
        return {"n": len(subset), "detection_rate": None, "false_positive_rate": None}
    hits = sum(1 for r in attack if r["result"]["verdict"] == "block")
    return {
        "n": len(subset),
        "detection_rate": round(hits / len(attack), 3),
        "false_positive_rate": None,
        "hits": hits,
        "expected_blocks": len(attack),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-url",
        default=os.getenv("COMPLYEDGE_BASE_URL", "http://127.0.0.1:18800"),
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("DEV_API_KEY") or os.getenv("COMPLYEDGE_API_KEY", ""),
    )
    parser.add_argument("--timeout", type=float, default=60.0)
    args = parser.parse_args()
    if not args.api_key:
        print("Need --api-key or DEV_API_KEY / COMPLYEDGE_API_KEY", file=sys.stderr)
        return 2

    fixtures = _load_fixtures()
    n_semantic = len(fixtures)
    est = n_semantic * USD_PER_SEMANTIC_CALL
    print(
        f"Fixtures: {len(fixtures)} × 2 switches. "
        f"Semantic arm ≈ {n_semantic} LLM calls ≈ ${est:.4f} "
        f"(estimate @ ${USD_PER_SEMANTIC_CALL}/call)."
    )
    print(f"Target: {args.base_url}")

    rows: list[dict] = []
    latencies: list[float] = []
    with httpx.Client(
        base_url=args.base_url.rstrip("/"),
        headers={
            "Authorization": f"Bearer {args.api_key}",
            "Content-Type": "application/json",
        },
        timeout=args.timeout,
    ) as client:
        health = client.get("/health")
        print(f"GET /health → {health.status_code}")
        if health.status_code != 200:
            print(health.text[:300], file=sys.stderr)
            return 1

        for fix in fixtures:
            for semantic, switch in ((False, "opa"), (True, "semantic")):
                result = _check(
                    client,
                    text=fix["text"],
                    semantic=semantic,
                )
                latencies.append(result["latency_ms"])
                row = {
                    "id": fix["id"],
                    "arm": fix["arm"],
                    "language": fix["language"],
                    "expected_opa": fix["expected_opa"],
                    "expected_semantic": fix["expected_semantic"],
                    "switch": switch,
                    "result": result,
                    "match_opa_expect": (
                        result["verdict"] == fix["expected_opa"]
                        if switch == "opa"
                        else None
                    ),
                    "match_semantic_expect": (
                        result["verdict"] == fix["expected_semantic"]
                        if switch == "semantic"
                        else None
                    ),
                }
                rows.append(row)
                print(
                    f"{fix['id']:36} {switch:8} → {result['verdict']:12} "
                    f"path={result.get('engine_path')} "
                    f"rules={result.get('rule_ids')} "
                    f"{result['latency_ms']:.0f}ms"
                )

    by_arm = {}
    for arm in ("A", "B", "C", "D"):
        by_arm[arm] = {
            "opa": _arm_summary(rows, arm, "opa"),
            "semantic": _arm_summary(rows, arm, "semantic"),
        }

    report = {
        "run_id": datetime.now(UTC).isoformat(),
        "base_url": args.base_url,
        "fixture_path": str(FIXTURE.relative_to(REPO)),
        "fixture_count": len(fixtures),
        "cost_estimate_usd_semantic_arm": round(est, 4),
        "latency_ms": {
            "p50": round(statistics.median(latencies), 1) if latencies else None,
            "p95": (
                round(sorted(latencies)[max(0, int(len(latencies) * 0.95) - 1)], 1)
                if latencies
                else None
            ),
            "max": round(max(latencies), 1) if latencies else None,
        },
        "summary_by_arm": by_arm,
        "rows": rows,
        "notes": [
            "Live production was not used; prefer local so unpushed fail-closed code is under test.",
            "evaluate_fast truncates text to 4000 chars; longer invoices may lose the payload.",
            "Arm D realism still needs operator eyeball on false-positive fixtures.",
        ],
    }
    RESULTS.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote {OUT.relative_to(REPO)}")
    print(json.dumps(by_arm, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
