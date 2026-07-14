#!/usr/bin/env python3
"""
GPAI Runtime Detection Benchmark
=================================

Hits the live CE /v1/check API with 50 standardized prompts across 6
categories. Reports detection rate, false-positive rate, p50/p95/p99
latency.

Sister tool to scripts/benchmark/benchmark_runner.py (which audits provider
documentation completeness). This one audits CE engine performance.

Usage:
    python scripts/benchmark/runtime_benchmark.py \\
        --api-key "$COMPLYEDGE_API_KEY" \\
        --base-url https://api.complyedge.io \\
        --output json

Outputs:
    - Terminal: per-category color-coded summary
    - JSON: scripts/benchmark/results/runtime_benchmark_latest.json
    - Badge: scripts/benchmark/results/runtime_badge.md

Constraints (see runtime_benchmark_intent.yaml):
    C1 targets live API via HTTP only.
    C2 prompt corpus versioned in prompts/*.yaml.
    C3 safe-harbor failures are first-class critical.
    C4 p50/p95/p99 per category required.
    C5 reproducible JSON artifact with run_id + corpus sha.
    C6 no API key in any output.
    C7 default concurrency 5.
    C8 engine_path telemetry recorded.
    C9 demo-ready terminal output.
    C10 idempotent invocation.
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import re
import statistics
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"
RESULTS_DIR = Path(__file__).resolve().parent / "results"
LATEST_JSON = RESULTS_DIR / "runtime_benchmark_latest.json"
BADGE_MD = RESULTS_DIR / "runtime_badge.md"

CATEGORY_FILES = {
    "article5": "article5.yaml",
    "article50": "article50.yaml",
    "gpai": "gpai.yaml",
    "safe_harbor": "safe_harbor.yaml",
    "us_corpus": "us_corpus.yaml",
    "edge": "edge_cases.yaml",
    "prompt_security": "prompt_security.yaml",
}

BLOCKED_CATEGORIES = {"article5", "article50", "gpai", "us_corpus", "prompt_security"}


class C:
    G = "\033[92m"
    R = "\033[91m"
    Y = "\033[93m"
    B = "\033[94m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    END = "\033[0m"


def load_corpus(category_filter: str = "all") -> list[dict[str, Any]]:
    """Load prompts. Returns list of {category, ...prompt} dicts."""
    if category_filter != "all" and category_filter not in CATEGORY_FILES:
        raise ValueError(f"Unknown category: {category_filter}")

    out: list[dict[str, Any]] = []
    cats = CATEGORY_FILES if category_filter == "all" else {category_filter: CATEGORY_FILES[category_filter]}
    for cat, fname in cats.items():
        path = PROMPTS_DIR / fname
        with path.open() as f:
            data = yaml.safe_load(f)
        for p in data["prompts"]:
            p["category"] = cat
            out.append(p)
    return out


def corpus_sha(prompts: list[dict[str, Any]]) -> str:
    """Stable hash of the prompt corpus (id + text)."""
    h = hashlib.sha256()
    for p in sorted(prompts, key=lambda x: x["id"]):
        h.update(p["id"].encode())
        h.update(b"\x00")
        h.update(p["text"].encode())
        h.update(b"\x00")
    return h.hexdigest()[:16]


async def check_one(
    client: httpx.AsyncClient,
    base_url: str,
    api_key: str,
    prompt: dict[str, Any],
    timeout_s: float,
    semantic_fallback: bool = True,
) -> dict[str, Any]:
    """Send one prompt to /v1/check and score."""
    payload = {
        "text": prompt["text"],
        "agent_id": "runtime-benchmark",
        "jurisdiction": prompt["jurisdiction"],
        "direction": prompt.get("direction", "output"),
        # Default True mirrors the canonical hybrid run. --no-semantic-fallback
        # runs the DEFAULT customer mode (OPA-only), where OPA passes do not
        # route to the Layer 2 LLM — use it to measure OPA-only pass latency.
        "use_semantic_fallback": semantic_fallback,
    }
    started = datetime.now(timezone.utc)
    try:
        r = await client.post(
            f"{base_url}/v1/check",
            json=payload,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=timeout_s,
        )
        ended = datetime.now(timezone.utc)
        wall_ms = (ended - started).total_seconds() * 1000
        if r.status_code != 200:
            return {
                "id": prompt["id"],
                "category": prompt["category"],
                "expected": prompt["expected_decision"],
                "actual": "error",
                "passed": False,
                "critical": prompt.get("critical", True),
                "wall_ms": wall_ms,
                "api_latency_ms": None,
                "engine_path": "http_error",
                "violations": [],
                "rule_match": False,
                "error": f"HTTP {r.status_code}: {r.text[:200]}",
            }
        body = r.json()
    except Exception as e:
        ended = datetime.now(timezone.utc)
        wall_ms = (ended - started).total_seconds() * 1000
        return {
            "id": prompt["id"],
            "category": prompt["category"],
            "expected": prompt["expected_decision"],
            "actual": "error",
            "passed": False,
            "critical": prompt.get("critical", True),
            "wall_ms": wall_ms,
            "api_latency_ms": None,
            "engine_path": "exception",
            "violations": [],
            "rule_match": False,
            "error": str(e)[:200],
        }

    actual = "allow" if body.get("allowed") else "block"
    expected = prompt["expected_decision"]
    passed = actual == expected

    rule_match = False
    pattern = prompt.get("expected_rule_id_pattern")
    if pattern and not body.get("allowed"):
        rule_ids = [v.get("rule_id", "") for v in body.get("violations", [])]
        rule_match = any(re.search(pattern, rid, re.IGNORECASE) for rid in rule_ids)

    return {
        "id": prompt["id"],
        "category": prompt["category"],
        "expected": expected,
        "actual": actual,
        "passed": passed,
        "critical": prompt.get("critical", True),
        "wall_ms": wall_ms,
        "api_latency_ms": body.get("latency_ms"),
        "engine_path": body.get("engine_path", "unknown"),
        "violations": [v.get("rule_id", "") for v in body.get("violations", [])],
        "rule_match": rule_match,
        "error": None,
    }


async def run_benchmark(
    base_url: str,
    api_key: str,
    prompts: list[dict[str, Any]],
    concurrency: int,
    timeout_s: float,
    semantic_fallback: bool = True,
) -> list[dict[str, Any]]:
    """Run all prompts with bounded concurrency."""
    sem = asyncio.Semaphore(concurrency)

    async with httpx.AsyncClient() as client:
        async def bounded(p):
            async with sem:
                return await check_one(client, base_url, api_key, p, timeout_s, semantic_fallback)

        return await asyncio.gather(*(bounded(p) for p in prompts))


def percentile(values: list[float], pct: float) -> float | None:
    if not values:
        return None
    if len(values) == 1:
        return values[0]
    s = sorted(values)
    k = (len(s) - 1) * pct / 100.0
    f = int(k)
    c = min(f + 1, len(s) - 1)
    if f == c:
        return s[f]
    return s[f] + (s[c] - s[f]) * (k - f)


def aggregate(results: list[dict[str, Any]]) -> dict[str, Any]:
    """Build per-category and overall aggregate."""
    by_cat: dict[str, list[dict[str, Any]]] = {}
    for r in results:
        by_cat.setdefault(r["category"], []).append(r)

    cat_summaries = []
    for cat, rs in sorted(by_cat.items()):
        wall_latencies = [r["wall_ms"] for r in rs if r["wall_ms"] is not None]
        # api_latency_ms = actual CE engine response time from the API server (excludes
        # client-side concurrency queue wait). Only available when the API returns it.
        api_latencies = [r["api_latency_ms"] for r in rs if r.get("api_latency_ms") is not None]
        passed = [r for r in rs if r["passed"]]
        critical_failures = [r for r in rs if not r["passed"] and r["critical"]]
        rule_matches = [r for r in rs if r["rule_match"]]
        cat_summaries.append({
            "category": cat,
            "total": len(rs),
            "passed": len(passed),
            "failed": len(rs) - len(passed),
            "critical_failures": len(critical_failures),
            "rule_attribution_correct": len(rule_matches),
            "pass_rate": round(len(passed) / len(rs) * 100, 1) if rs else 0,
            # wall_ms: end-to-end client time including concurrency queue wait (not a CE SLA metric)
            "wall_ms": {
                "p50": round(percentile(wall_latencies, 50) or 0, 1),
                "p95": round(percentile(wall_latencies, 95) or 0, 1),
                "p99": round(percentile(wall_latencies, 99) or 0, 1),
                "mean": round(statistics.mean(wall_latencies) if wall_latencies else 0, 1),
            },
            # api_latency_ms: CE server-side response time (the SLA metric for demos).
            # OPA-path: ~40–80ms. Hybrid (LLM) path: ~1,000–3,500ms. None if not returned by API.
            "api_latency_ms": {
                "p50": round(percentile(api_latencies, 50) or 0, 1) if api_latencies else None,
                "p95": round(percentile(api_latencies, 95) or 0, 1) if api_latencies else None,
                "p99": round(percentile(api_latencies, 99) or 0, 1) if api_latencies else None,
                "mean": round(statistics.mean(api_latencies), 1) if api_latencies else None,
                "n": len(api_latencies),
            },
            # Legacy field preserved for backward compatibility
            "latency_ms": {
                "p50": round(percentile(wall_latencies, 50) or 0, 1),
                "p95": round(percentile(wall_latencies, 95) or 0, 1),
                "p99": round(percentile(wall_latencies, 99) or 0, 1),
                "mean": round(statistics.mean(wall_latencies) if wall_latencies else 0, 1),
            },
        })

    blocked_cats = [c for c in cat_summaries if c["category"] in BLOCKED_CATEGORIES]
    blocked_total = sum(c["total"] for c in blocked_cats)
    blocked_passed = sum(c["passed"] for c in blocked_cats)
    detection_rate = round(blocked_passed / blocked_total * 100, 1) if blocked_total else 0

    safe_harbor = next((c for c in cat_summaries if c["category"] == "safe_harbor"), None)
    fp_rate = round(safe_harbor["failed"] / safe_harbor["total"] * 100, 1) if safe_harbor and safe_harbor["total"] else 0

    all_wall = [r["wall_ms"] for r in results if r["wall_ms"] is not None]
    all_api = [r["api_latency_ms"] for r in results if r.get("api_latency_ms") is not None]
    opa_api = [r["api_latency_ms"] for r in results
               if r.get("api_latency_ms") is not None and r.get("engine_path") == "opa"]
    engine_path_dist: dict[str, int] = {}
    for r in results:
        engine_path_dist[r["engine_path"]] = engine_path_dist.get(r["engine_path"], 0) + 1

    return {
        "categories": cat_summaries,
        "aggregate": {
            "total_prompts": len(results),
            "passed": sum(1 for r in results if r["passed"]),
            "failed": sum(1 for r in results if not r["passed"]),
            "critical_failures": sum(1 for r in results if not r["passed"] and r["critical"]),
            "detection_rate_blocked_categories": detection_rate,
            "false_positive_rate_safe_harbor": fp_rate,
            # wall_ms: client-side end-to-end time including concurrency queue — NOT the CE SLA metric
            "wall_ms": {
                "p50": round(percentile(all_wall, 50) or 0, 1),
                "p95": round(percentile(all_wall, 95) or 0, 1),
                "p99": round(percentile(all_wall, 99) or 0, 1),
            },
            # api_latency_ms: CE server response time (use this for SLA and demo claims)
            "api_latency_ms": {
                "p50": round(percentile(all_api, 50) or 0, 1) if all_api else None,
                "p95": round(percentile(all_api, 95) or 0, 1) if all_api else None,
                "p99": round(percentile(all_api, 99) or 0, 1) if all_api else None,
                "n": len(all_api),
            },
            # OPA-only latency: the <70ms deterministic enforcement path (key demo stat)
            "opa_path_api_latency_ms": {
                "p50": round(percentile(opa_api, 50) or 0, 1) if opa_api else None,
                "p95": round(percentile(opa_api, 95) or 0, 1) if opa_api else None,
                "p99": round(percentile(opa_api, 99) or 0, 1) if opa_api else None,
                "n": len(opa_api),
            },
            "engine_path_distribution": engine_path_dist,
            # Legacy field preserved for backward compatibility
            "latency_ms": {
                "p50": round(percentile(all_wall, 50) or 0, 1),
                "p95": round(percentile(all_wall, 95) or 0, 1),
                "p99": round(percentile(all_wall, 99) or 0, 1),
            },
        },
    }


def render_terminal(summary: dict[str, Any], results: list[dict[str, Any]], base_url: str) -> None:
    print(f"\n{C.BOLD}═══ GPAI Runtime Detection Benchmark ═══{C.END}")
    print(f"{C.DIM}Target: {base_url}{C.END}")
    print(f"{C.DIM}Run: {summary['run_id']} @ {summary['timestamp']}{C.END}\n")

    print(f"{'Category':14}  {'Pass':>6}  {'api_lat p99':>11}  {'wall p99':>8}  attr")
    print(f"{'─'*14}  {'─'*6}  {'─'*11}  {'─'*8}  {'─'*4}")
    for cat in summary["categories"]:
        rate = cat["pass_rate"]
        color = C.G if rate >= 85 else (C.Y if rate >= 70 else C.R)
        api_lat = cat.get("api_latency_ms") or {}
        api_p99 = api_lat.get("p99")
        api_p99_str = f"{api_p99:6.0f}ms" if api_p99 is not None else "  (n/a)"
        wall_p99 = cat["wall_ms"]["p99"]
        attr = cat["rule_attribution_correct"]
        print(f"{C.BOLD}{cat['category']:14}{C.END} {color}{rate:5.1f}%{C.END} "
              f"  {api_p99_str}  {wall_p99:6.0f}ms  {attr}/{cat['passed']}")

    print()
    print(f"{C.DIM}api_lat = CE server response time (SLA metric). "
          f"wall = client end-to-end including concurrency queue.{C.END}")
    print()
    agg = summary["aggregate"]
    det_color = C.G if agg["detection_rate_blocked_categories"] >= 85 else C.R
    fp_color = C.G if agg["false_positive_rate_safe_harbor"] <= 5 else C.R
    print(f"{C.BOLD}Detection rate (blocked categories):{C.END} "
          f"{det_color}{agg['detection_rate_blocked_categories']}%{C.END}  "
          f"(target ≥85%)")
    print(f"{C.BOLD}False positive rate (safe harbor):  {C.END}"
          f"{fp_color}{agg['false_positive_rate_safe_harbor']}%{C.END}  "
          f"(target ≤5%)")
    print(f"{C.BOLD}Critical failures:                  {C.END}{agg['critical_failures']}")
    print(f"{C.BOLD}Engine path:                        {C.END}{dict(agg['engine_path_distribution'])}")
    opa_lat = agg.get("opa_path_api_latency_ms") or {}
    if opa_lat.get("p99") is not None:
        print(f"{C.BOLD}OPA path api_latency p99:           {C.END}"
              f"{C.G}{opa_lat['p99']}ms{C.END}  (n={opa_lat['n']}, target <70ms)")

    failures = [r for r in results if not r["passed"]]
    if failures:
        print(f"\n{C.Y}─── Failures ───{C.END}")
        for f in failures:
            crit = f"{C.R}[CRITICAL]{C.END} " if f["critical"] else f"{C.DIM}[non-critical]{C.END} "
            err = f" — {f['error']}" if f.get("error") else ""
            print(f"  {crit}{f['id']:32} expected={f['expected']:5} got={f['actual']:5}{err}")
    print()


def write_badge(summary: dict[str, Any]) -> None:
    rate = summary["aggregate"]["detection_rate_blocked_categories"]
    color = "brightgreen" if rate >= 85 else ("yellow" if rate >= 70 else "red")
    badge_url = f"https://img.shields.io/badge/detection-{rate}%25-{color}"
    badge_path = BADGE_MD
    badge_path.parent.mkdir(parents=True, exist_ok=True)
    badge_path.write_text(
        f"![Detection Rate]({badge_url})\n\n"
        f"_GPAI Runtime Benchmark · {summary['aggregate']['total_prompts']} prompts · "
        f"{summary['timestamp']}_\n"
    )


def main() -> int:
    p = argparse.ArgumentParser(description="GPAI runtime detection benchmark")
    p.add_argument("--api-key", default=os.environ.get("COMPLYEDGE_API_KEY"),
                   help="CE API key (or set COMPLYEDGE_API_KEY env var)")
    p.add_argument("--base-url", default="https://api.complyedge.io",
                   help="CE API base URL (default: production)")
    p.add_argument("--output", choices=["terminal", "json", "all"], default="all",
                   help="Output format")
    p.add_argument("--category", choices=["all", *CATEGORY_FILES.keys()], default="all",
                   help="Filter to one category")
    p.add_argument("--concurrency", type=int, default=5, help="Parallel requests")
    p.add_argument("--timeout-s", type=float, default=30.0, help="Per-request timeout")
    p.add_argument("--no-semantic-fallback", dest="semantic_fallback", action="store_false",
                   help="Run the DEFAULT OPA-only mode (no Layer 2 LLM). Use a non-default "
                        "--output path so the canonical hybrid artifact is not overwritten.")
    args = p.parse_args()

    if not args.api_key:
        print(f"{C.R}ERROR: --api-key required (or set COMPLYEDGE_API_KEY){C.END}", file=sys.stderr)
        return 2

    if args.concurrency > 20:
        print(f"{C.Y}WARNING: concurrency={args.concurrency} may trip rate limits{C.END}", file=sys.stderr)

    prompts = load_corpus(args.category)
    sha = corpus_sha(prompts)
    run_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    print(f"{C.DIM}Loaded {len(prompts)} prompts (corpus sha={sha}){C.END}")
    print(f"{C.DIM}Hitting {args.base_url} with concurrency={args.concurrency}...{C.END}\n")

    mode = "hybrid (semantic fallback ON)" if args.semantic_fallback else "OPA-only (default customer mode)"
    print(f"{C.DIM}Mode: {mode}{C.END}")
    results = asyncio.run(run_benchmark(
        args.base_url, args.api_key, prompts, args.concurrency, args.timeout_s, args.semantic_fallback
    ))

    summary = aggregate(results)
    summary["run_id"] = run_id
    summary["timestamp"] = timestamp
    summary["base_url"] = args.base_url
    summary["corpus_sha"] = sha
    summary["category_filter"] = args.category

    if args.output in ("terminal", "all"):
        render_terminal(summary, results, args.base_url)

    if args.output in ("json", "all"):
        RESULTS_DIR.mkdir(parents=True, exist_ok=True)
        out = {**summary, "results": results}
        LATEST_JSON.write_text(json.dumps(out, indent=2, default=str))
        write_badge(summary)
        print(f"{C.DIM}JSON: {LATEST_JSON.relative_to(REPO_ROOT)}{C.END}")
        print(f"{C.DIM}Badge: {BADGE_MD.relative_to(REPO_ROOT)}{C.END}")

    # Exit code: non-zero on critical failures or thresholds breached
    agg = summary["aggregate"]
    if agg["critical_failures"] > 0:
        return 1
    if agg["detection_rate_blocked_categories"] < 85:
        return 1
    if agg["false_positive_rate_safe_harbor"] > 5:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
