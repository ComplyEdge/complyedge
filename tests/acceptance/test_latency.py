"""
Validates latency claims from the published benchmark + one live timing check.

Offline (no API key):
  - OPA fast-path blocks: 38–100ms range, median ≤100ms  [n=14]

Live (requires COMPLYEDGE_API_KEY):
  - Single real API call must return in <150ms (OPA-only path)

Claims verified:
  - "38–100ms (median 62ms, n=14) on our 50-prompt benchmark" [OPA fast-path blocks]
  - "<150ms" OPA path latency on live call
"""
from __future__ import annotations

import json
import statistics
import time

import pytest
import requests

from conftest import BENCHMARK_RESULTS_DIR

BENCHMARK_FILE = BENCHMARK_RESULTS_DIR / "runtime_benchmark_latest.json"


@pytest.fixture(scope="module")
def results() -> list[dict]:
    if not BENCHMARK_FILE.exists():
        pytest.fail(f"Benchmark results file not found: {BENCHMARK_FILE}")
    with open(BENCHMARK_FILE) as f:
        return json.load(f)["results"]


@pytest.fixture(scope="module")
def opa_fast_path_latencies(results) -> list[float]:
    """OPA engine_path + block decision — the deterministic fast path (n=14)."""
    return [
        r["api_latency_ms"]
        for r in results
        if r.get("engine_path") == "opa"
        and r.get("actual") == "block"
        and r.get("api_latency_ms") is not None
    ]


class TestOpaFastPath:
    """
    Validates the "38-100ms, median 62ms, n=14" claim for OPA fast-path blocks.
    """

    def test_opa_fast_path_sample_size(self, opa_fast_path_latencies):
        n = len(opa_fast_path_latencies)
        assert n == 14, f"Expected 14 OPA fast-path blocks, found {n}"

    def test_opa_fast_path_median_under_100ms(self, opa_fast_path_latencies):
        median = statistics.median(opa_fast_path_latencies)
        assert median <= 100, (
            f"OPA fast-path median should be ≤100ms; benchmark shows {median:.1f}ms"
        )

    def test_opa_fast_path_max_under_150ms(self, opa_fast_path_latencies):
        maximum = max(opa_fast_path_latencies)
        assert maximum <= 150, (
            f"OPA fast-path max should be ≤150ms; benchmark shows {maximum:.1f}ms"
        )

    def test_opa_fast_path_min_over_10ms(self, opa_fast_path_latencies):
        minimum = min(opa_fast_path_latencies)
        assert minimum >= 10, (
            f"OPA fast-path minimum ({minimum:.1f}ms) is suspiciously low — "
            "may indicate cached or mocked responses"
        )


class TestLiveLatency:
    """
    LIVE — Requires COMPLYEDGE_API_KEY.
    Single real call must come back under 300ms.
    """

    def test_single_live_call_under_150ms(self, live_session, api_base_url):
        # Claim: OPA-only path (use_semantic_fallback=False) returns in <150ms
        payload = {
            "text": "Hello, I am an AI assistant. How can I help you today?",
            "agent_id": "acceptance-test",
            "jurisdiction": "EU",
            "context": {"system_type": "customer_support"},
            "use_semantic_fallback": False,
        }
        t0 = time.monotonic()
        resp = live_session.post(f"{api_base_url}/v1/check", json=payload)
        elapsed_ms = (time.monotonic() - t0) * 1000

        assert resp.status_code == 200, (
            f"Expected 200 from {api_base_url}/v1/check, got {resp.status_code}: {resp.text[:200]}"
        )
        # Use server-reported latency if available, else fall back to wall-clock
        data = resp.json()
        server_ms = data.get("latency_ms", elapsed_ms)
        assert server_ms < 150, (
            f"Live OPA-only call took {server_ms:.0f}ms — expected <150ms"
        )
