"""
OFFLINE — Validates the published benchmark results file (50 prompts, 6 categories).
No API key required.

Claims verified:
  - "50-prompt benchmark corpus"
  - "6 categories: Article 5, Article 50, GPAI, safe harbor, edge cases, US corpus"
  - "10/10 safe-harbor prompts returned 0 violations (zero false positives)"
  - "US corpus: all 10 prompts allowed by OPA"
  - Benchmark results file is present and well-formed
  - Every result has the required fields
"""
from __future__ import annotations

import json
import statistics
from pathlib import Path

import pytest

from conftest import BENCHMARK_RESULTS_DIR

BENCHMARK_FILE = BENCHMARK_RESULTS_DIR / "runtime_benchmark_latest.json"

EXPECTED_CATEGORIES = {"article5", "article50", "gpai", "safe_harbor", "edge", "us_corpus"}
REQUIRED_FIELDS = {"id", "category", "expected", "actual", "passed", "api_latency_ms", "violations"}


@pytest.fixture(scope="module")
def benchmark() -> dict:
    if not BENCHMARK_FILE.exists():
        pytest.fail(
            f"Benchmark results file not found: {BENCHMARK_FILE}. "
            "Run: python scripts/benchmark/run_benchmark.py"
        )
    with open(BENCHMARK_FILE) as f:
        return json.load(f)


@pytest.fixture(scope="module")
def results(benchmark) -> list[dict]:
    return benchmark["results"]


class TestBenchmarkIntegrity:
    """Validates the benchmark file is present and structurally correct."""

    def test_benchmark_file_exists(self):
        # Claim: benchmark data is publicly verifiable
        assert BENCHMARK_FILE.exists(), f"Benchmark file not found at {BENCHMARK_FILE}"

    def test_benchmark_has_50_results(self, results):
        # Claim: "50-prompt benchmark corpus"
        assert len(results) == 50, f"Expected 50 benchmark results, found {len(results)}"

    def test_benchmark_has_6_categories(self, results):
        # Claim: "6 categories"
        found = {r["category"] for r in results}
        assert found == EXPECTED_CATEGORIES, (
            f"Expected categories {EXPECTED_CATEGORIES}, found {found}"
        )

    def test_every_result_has_required_fields(self, results):
        # Structural: every result must carry the fields the API contract guarantees
        missing = []
        for r in results:
            absent = REQUIRED_FIELDS - set(r.keys())
            if absent:
                missing.append(f"{r['id']}: missing {absent}")
        assert missing == [], f"Results with missing fields:\n" + "\n".join(missing)

    def test_aggregate_false_positive_rate_is_zero(self, benchmark):
        # Claim: "10/10 safe-harbor prompts returned 0 violations"
        # The aggregate block tracks this explicitly.
        rate = benchmark["aggregate"]["false_positive_rate_safe_harbor"]
        assert rate == 0.0, f"False-positive rate on safe harbor should be 0.0, got {rate}"

    def test_aggregate_latency_p50_under_80ms(self, benchmark):
        # Claim: "full 50-prompt benchmark runs at median 73ms"
        p50 = benchmark["aggregate"]["api_latency_ms"]["p50"]
        assert p50 <= 80, f"Median API latency should be ≤80ms, got {p50}ms"

    def test_aggregate_latency_p99_under_150ms(self, benchmark):
        # Claim: "p99 135ms" (OPA-only, full 50-prompt run)
        p99 = benchmark["aggregate"]["api_latency_ms"]["p99"]
        assert p99 <= 150, f"p99 API latency should be ≤150ms, got {p99}ms"


class TestSafeHarbor:
    """Validates the zero-false-positives claim for safe-harbor prompts."""

    @pytest.fixture(scope="class")
    def safe_harbor_results(self, results):
        return [r for r in results if r["category"] == "safe_harbor"]

    def test_exactly_10_safe_harbor_prompts(self, safe_harbor_results):
        assert len(safe_harbor_results) == 10, (
            f"Expected 10 safe-harbor prompts, found {len(safe_harbor_results)}"
        )

    def test_zero_false_positives_in_safe_harbor(self, safe_harbor_results):
        # Claim: "10/10 safe-harbor prompts returned 0 violations"
        with_violations = [
            r["id"] for r in safe_harbor_results if r.get("violations")
        ]
        assert with_violations == [], (
            f"Safe-harbor prompts incorrectly flagged: {with_violations}"
        )

    def test_all_safe_harbor_allowed(self, safe_harbor_results):
        # Claim: safe-harbor = allow decision
        blocked = [r["id"] for r in safe_harbor_results if r["actual"] != "allow"]
        assert blocked == [], f"Safe-harbor prompts incorrectly blocked: {blocked}"


class TestCategoryPassRates:
    """
    Validates the per-category Layer 1 (OPA) numbers from the blog post table.

    Blog table (why-opa-rego-eu-ai-act.md):
      Article 5   | 5/10  — OPA catches canonical phrasings
      Article 50  | 4/8   — Pattern coverage grows with community PRs
      GPAI        | 4/5   —
      Safe harbor | 10/10 — Zero false positives
      Edge cases  | 5/7   —
      US corpus   | 0/10  — All require use_semantic_fallback=True

    The `passed` field means expected == actual (OPA handled the prompt correctly,
    whether by correctly blocking a violation or correctly allowing a safe prompt).
    """

    def test_article5_layer1_pass_rate(self, results):
        # Blog: "Article 5 | 5/10"
        cat = [r for r in results if r["category"] == "article5"]
        passed = sum(1 for r in cat if r["passed"])
        assert len(cat) == 10, f"Expected 10 Article 5 prompts, found {len(cat)}"
        assert passed == 5, f"Expected Article 5 Layer 1 pass = 5/10, got {passed}/10"

    def test_article50_layer1_pass_rate(self, results):
        # Blog: "Article 50 | 4/8"
        cat = [r for r in results if r["category"] == "article50"]
        passed = sum(1 for r in cat if r["passed"])
        assert len(cat) == 8, f"Expected 8 Article 50 prompts, found {len(cat)}"
        assert passed == 4, f"Expected Article 50 Layer 1 pass = 4/8, got {passed}/8"

    def test_gpai_layer1_pass_rate(self, results):
        # Blog: "GPAI | 4/5"
        cat = [r for r in results if r["category"] == "gpai"]
        passed = sum(1 for r in cat if r["passed"])
        assert len(cat) == 5, f"Expected 5 GPAI prompts, found {len(cat)}"
        assert passed == 4, f"Expected GPAI Layer 1 pass = 4/5, got {passed}/5"

    def test_edge_layer1_pass_rate(self, results):
        # Blog: "Edge cases | 5/7"
        cat = [r for r in results if r["category"] == "edge"]
        passed = sum(1 for r in cat if r["passed"])
        assert len(cat) == 7, f"Expected 7 edge prompts, found {len(cat)}"
        assert passed == 5, f"Expected edge Layer 1 pass = 5/7, got {passed}/7"

    def test_us_corpus_layer1_pass_rate(self, results):
        # Blog: "US corpus | 0/10 OPA" — all require use_semantic_fallback=True
        cat = [r for r in results if r["category"] == "us_corpus"]
        passed = sum(1 for r in cat if r["passed"])
        assert len(cat) == 10, f"Expected 10 US corpus prompts, found {len(cat)}"
        assert passed == 0, f"Expected US corpus Layer 1 pass = 0/10, got {passed}/10"


class TestUsCorpus:
    """Validates the US corpus results."""

    @pytest.fixture(scope="class")
    def us_results(self, results):
        return [r for r in results if r["category"] == "us_corpus"]

    def test_exactly_10_us_corpus_prompts(self, us_results):
        assert len(us_results) == 10, (
            f"Expected 10 US corpus prompts, found {len(us_results)}"
        )

    def test_us_corpus_all_handled_by_opa(self, us_results):
        # Claim: "US corpus handled by OPA layer"
        non_opa = [r["id"] for r in us_results if r.get("engine_path") != "opa"]
        assert non_opa == [], (
            f"US corpus prompts NOT handled by OPA: {non_opa}"
        )

    def test_us_corpus_all_allowed(self, us_results):
        blocked = [r["id"] for r in us_results if r["actual"] != "allow"]
        assert blocked == [], f"US corpus prompts unexpectedly blocked: {blocked}"
