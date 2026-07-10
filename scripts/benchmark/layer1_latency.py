#!/usr/bin/env python3
"""Layer-1 (deterministic hot-path) latency microbenchmark.

Substantiates the public "<100ms p99 (Layer 1)" claim with a reproducible
artifact (PR-AP06). Layer 1 is the deterministic path: the OPA/Rego policy
bundle plus the TrustLint regex engine, with NO LLM. This benchmark measures
both in isolation, mirroring the production query path from
``services/api/opa_client.py`` (OPA runs as a long-lived server — the same
`opa run --server --bundle rules/rego` invocation as
``services/api/opa_supervisor.py`` — and each request POSTs to the four
aggregator packages ``complyedge/{article5,article6,article50,gpai}/result``).

It reports two OPA figures:
  * ``opa_per_request_sequential`` — sum of the four package queries done
    serially. Conservative upper bound.
  * ``opa_single_package`` — one package query. The production path issues the
    four in parallel (``evaluate()`` uses ``asyncio.gather``), so realized
    latency tracks the single-package figure, not the sequential sum.

Usage:  python3 scripts/benchmark/layer1_latency.py [--iterations N]
Writes: scripts/benchmark/results/layer1_latency_latest.json
        scripts/benchmark/results/layer1_latency_badge.md

Local reproducible microbenchmark — NOT prod telemetry. Production Layer-1
latency is tracked per request via the ``opa_latency_ms`` field emitted to
CloudWatch (see services/api/main.py).
"""
from __future__ import annotations

import argparse
import json
import shutil
import socket
import statistics
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BUNDLE = REPO / "rules" / "rego"
RESULTS = REPO / "scripts" / "benchmark" / "results"
PACKAGES = ["article5", "article6", "article50", "gpai"]

# Representative benign input (exercises the policy predicates without an early
# short-circuit that would understate work done).
SAMPLE_INPUT = {
    "input": {
        "text": "Our assistant summarises customer support tickets and drafts replies.",
        "jurisdiction": "EU",
    }
}


def _free_port() -> int:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def _pctl(xs: list[float], p: float) -> float:
    if not xs:
        return 0.0
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    lo, hi = int(k), min(int(k) + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def _summary(samples_ms: list[float]) -> dict:
    return {
        "n": len(samples_ms),
        "p50": round(_pctl(samples_ms, 0.50), 3),
        "p95": round(_pctl(samples_ms, 0.95), 3),
        "p99": round(_pctl(samples_ms, 0.99), 3),
        "mean": round(statistics.fmean(samples_ms), 3),
        "max": round(max(samples_ms), 3),
    }


def _query(base_url: str, pkg: str, body: bytes) -> None:
    req = urllib.request.Request(
        f"{base_url}/v1/data/complyedge/{pkg}/result",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=2.0) as resp:  # noqa: S310 loopback
        resp.read()


def bench_opa(iterations: int) -> dict:
    opa = shutil.which("opa")
    if not opa:
        raise SystemExit("opa binary not found on PATH — cannot benchmark Layer-1 OPA")
    port = _free_port()
    addr = f"127.0.0.1:{port}"
    base_url = f"http://{addr}"
    proc = subprocess.Popen(
        [opa, "run", "--server", "--addr", addr, "--log-level", "error", "--bundle", str(BUNDLE)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    try:
        # wait for health
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(f"{base_url}/health", timeout=0.2) as r:  # noqa: S310
                    if r.status == 200:
                        break
            except Exception:
                time.sleep(0.05)
        else:
            raise SystemExit("opa server did not become healthy")

        body = json.dumps(SAMPLE_INPUT).encode()
        # warmup
        for _ in range(20):
            for pkg in PACKAGES:
                _query(base_url, pkg, body)

        seq_ms: list[float] = []
        single_ms: list[float] = []
        for _ in range(iterations):
            t0 = time.perf_counter()
            for pkg in PACKAGES:
                ts = time.perf_counter()
                _query(base_url, pkg, body)
                single_ms.append((time.perf_counter() - ts) * 1000)
            seq_ms.append((time.perf_counter() - t0) * 1000)
        return {
            "opa_version": subprocess.run([opa, "version"], capture_output=True, text=True).stdout.split("\n")[0],
            "opa_per_request_sequential_ms": _summary(seq_ms),
            "opa_single_package_ms": _summary(single_ms),
        }
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


def bench_trustlint(iterations: int) -> dict:
    sys.path.insert(0, str(REPO / "packages" / "trustlint"))
    try:
        from trustlint.engine import TrustLintEngine  # type: ignore
    except Exception as e:  # pragma: no cover
        return {"error": f"trustlint engine import failed: {e}"}
    # Force the live dev corpus. TrustLintEngine's default resolution checks
    # ~/.trustlint/rules/ FIRST — if that's ever been populated (e.g. by a
    # `trustlint` CLI bootstrap, see leocelis/ivd's check.sh), it silently
    # shadows this repo's rules/regulations/ with a possibly-stale public
    # release snapshot, understating rules_loaded and skewing the benchmark.
    eng = TrustLintEngine(rules_dir=str(REPO / "rules" / "regulations"))
    text = SAMPLE_INPUT["input"]["text"]
    for _ in range(20):
        eng.check(text)
    ms: list[float] = []
    for _ in range(iterations):
        t0 = time.perf_counter()
        eng.check(text)
        ms.append((time.perf_counter() - t0) * 1000)
    return {"rules_loaded": len(getattr(eng, "rules", []) or []), "trustlint_regex_ms": _summary(ms)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--iterations", type=int, default=500)
    args = ap.parse_args()
    RESULTS.mkdir(parents=True, exist_ok=True)

    opa = bench_opa(args.iterations)
    tl = bench_trustlint(args.iterations)

    single_p99 = opa["opa_single_package_ms"]["p99"]
    seq_p99 = opa["opa_per_request_sequential_ms"]["p99"]
    tl_p99 = tl.get("trustlint_regex_ms", {}).get("p99", 0.0)
    # Realized Layer-1 hot-path p99: parallel OPA (≈ single package) + regex engine.
    layer1_p99 = round(single_p99 + tl_p99, 3)

    out = {
        "benchmark": "layer1_latency",
        "kind": "local_reproducible_microbenchmark",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "iterations": args.iterations,
        "note": (
            "Local reproducible microbenchmark of the deterministic hot path "
            "(OPA/Rego bundle + TrustLint regex, no LLM). Prod latency is "
            "tracked per request via opa_latency_ms -> CloudWatch."
        ),
        "opa": opa,
        "trustlint": tl,
        "layer1_hotpath_p99_ms_parallel": layer1_p99,
        "under_100ms_p99": layer1_p99 < 100 and seq_p99 < 100,
    }
    (RESULTS / "layer1_latency_latest.json").write_text(json.dumps(out, indent=2))

    verdict = "PASS" if out["under_100ms_p99"] else "FAIL"
    badge = (
        f"![Layer-1 p99](https://img.shields.io/badge/Layer--1_p99-{layer1_p99}ms-brightgreen)\n\n"
        f"_Layer-1 deterministic hot path (OPA/Rego + TrustLint regex, no LLM) · "
        f"{args.iterations} iterations · {out['generated_at']}_\n\n"
        f"- OPA single-package p99 (parallel path): {single_p99} ms\n"
        f"- OPA 4-package sequential p99 (conservative): {seq_p99} ms\n"
        f"- TrustLint regex p99: {tl_p99} ms\n"
        f"- **Realized Layer-1 hot-path p99: {layer1_p99} ms** — <100ms claim: {verdict}\n"
    )
    (RESULTS / "layer1_latency_badge.md").write_text(badge)
    print(badge)


if __name__ == "__main__":
    main()
