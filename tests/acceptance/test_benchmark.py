"""
OFFLINE — Validates the published benchmark results file (60 prompts, 7 categories).
No API key required.

The counts here were frozen at the 50-prompt/6-category snapshot and went red
when the prompt_security group landed and took runtime detection from 81.4% to
100%. A correct improvement should not fail an acceptance suite, so the size
assertions now check the file against ITS OWN declared aggregate (which catches
a truncated or stale artifact, the failure that actually matters) plus the
number published on the public surfaces, and the latency tests assert a sample
FLOOR rather than an exact n.

Claims verified:
  - "60-prompt benchmark corpus"
  - "7 categories: Article 5, Article 50, GPAI, prompt security, safe harbor,
    edge cases, US corpus"
  - "10/10 safe-harbor prompts returned 0 violations (zero false positives)"
  - "US corpus: all 10 prompts handled by hybrid/Layer 2 (0 on OPA path)"
  - Benchmark results file is present and well-formed
  - Every result has the required fields
"""
from __future__ import annotations

import json
import statistics

import pytest
from conftest import BENCHMARK_RESULTS_DIR

BENCHMARK_FILE = BENCHMARK_RESULTS_DIR / "runtime_benchmark_latest.json"

EXPECTED_CATEGORIES = {
    "article5",
    "article50",
    "gpai",
    "prompt_security",
    "safe_harbor",
    "edge",
    "us_corpus",
}

#: The count published on README/enterprise/blog. Keep in step with those
#: surfaces; a mismatch here means a public number is unbacked by the artifact.
PUBLISHED_PROMPT_COUNT = 60

#: Minimum true OPA fast-path blocks needed for the latency percentiles to mean
#: anything. A floor, not a snapshot: the corpus is expected to grow.
MIN_OPA_FAST_PATH_SAMPLES = 15
REQUIRED_FIELDS = {
    "id",
    "category",
    "expected",
    "actual",
    "passed",
    "api_latency_ms",
    "violations",
    "engine_path",
}


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

    def test_results_match_the_artifacts_own_declared_total(self, benchmark, results):
        """Internal consistency: the file must not disagree with itself.

        This is the assertion with teeth. A truncated or half-written artifact
        keeps a plausible aggregate while losing rows, and every percentile
        computed from it is then quietly wrong.
        """
        declared = benchmark["aggregate"]["total_prompts"]
        assert len(results) == declared, (
            f"artifact declares total_prompts={declared} but carries "
            f"{len(results)} result rows"
        )

    def test_result_count_matches_the_published_number(self, results):
        # Claim: "60-prompt benchmark corpus" on README/enterprise/blog.
        assert len(results) == PUBLISHED_PROMPT_COUNT, (
            f"benchmark holds {len(results)} prompts but public surfaces claim "
            f"{PUBLISHED_PROMPT_COUNT}; correct one or the other before shipping"
        )

    def test_benchmark_covers_every_expected_category(self, results):
        # Claim: "7 categories"
        found = {r["category"] for r in results}
        assert found == EXPECTED_CATEGORIES, (
            f"category set drift: missing {EXPECTED_CATEGORIES - found}, "
            f"unexpected {found - EXPECTED_CATEGORIES}"
        )

    def test_every_result_has_required_fields(self, results):
        # Structural: every result must carry the fields the API contract guarantees
        missing = []
        for r in results:
            absent = REQUIRED_FIELDS - set(r.keys())
            if absent:
                missing.append(f"{r['id']}: missing {absent}")
        assert missing == [], "Results with missing fields:\n" + "\n".join(missing)

    def test_aggregate_false_positive_rate_is_zero(self, benchmark):
        # Claim: "10/10 safe-harbor prompts returned 0 violations"
        # The aggregate block tracks this explicitly.
        rate = benchmark["aggregate"]["false_positive_rate_safe_harbor"]
        assert (
            rate == 0.0
        ), f"False-positive rate on safe harbor should be 0.0, got {rate}"

    def test_opa_fast_path_latency_median_under_200ms(self, results):
        # Claim: true OPA fast-path blocks stay sub-200ms median.
        # 2026-05-18: n=14, p50=62ms. 2026-07-11: n=15, p50=135ms (warm prod).
        blocked_opa = [
            r
            for r in results
            if r.get("engine_path") == "opa" and r.get("actual") == "block"
        ]
        latencies = [
            r["api_latency_ms"]
            for r in blocked_opa
            if r.get("api_latency_ms") is not None
        ]
        assert len(latencies) >= MIN_OPA_FAST_PATH_SAMPLES, (
            f"only {len(latencies)} OPA fast-path blocks; too few for the "
            "percentiles below to be meaningful"
        )
        p50 = statistics.median(latencies)
        assert (
            p50 <= 200
        ), f"OPA fast-path median API latency should be ≤200ms, got {p50}ms"

    def test_opa_fast_path_latency_p99_under_250ms(self, results):
        blocked_opa = [
            r
            for r in results
            if r.get("engine_path") == "opa" and r.get("actual") == "block"
        ]
        latencies = [
            r["api_latency_ms"]
            for r in blocked_opa
            if r.get("api_latency_ms") is not None
        ]
        assert len(latencies) >= MIN_OPA_FAST_PATH_SAMPLES
        p99 = statistics.quantiles(latencies, n=100)[98]
        assert (
            p99 <= 250
        ), f"OPA fast-path p99 API latency should be ≤250ms, got {p99}ms"


class TestSafeHarbor:
    """Validates the zero-false-positives claim for safe-harbor prompts."""

    @pytest.fixture(scope="class")
    def safe_harbor_results(self, results):
        return [r for r in results if r["category"] == "safe_harbor"]

    def test_exactly_10_safe_harbor_prompts(self, safe_harbor_results):
        assert (
            len(safe_harbor_results) == 10
        ), f"Expected 10 safe-harbor prompts, found {len(safe_harbor_results)}"

    def test_zero_false_positives_in_safe_harbor(self, safe_harbor_results):
        # Claim: "10/10 safe-harbor prompts returned 0 violations"
        with_violations = [r["id"] for r in safe_harbor_results if r.get("violations")]
        assert (
            with_violations == []
        ), f"Safe-harbor prompts incorrectly flagged: {with_violations}"

    def test_all_safe_harbor_allowed(self, safe_harbor_results):
        # Claim: safe-harbor = allow decision
        blocked = [r["id"] for r in safe_harbor_results if r["actual"] != "allow"]
        assert blocked == [], f"Safe-harbor prompts incorrectly blocked: {blocked}"


class TestCategoryPassRates:
    """
    Validates the per-category Layer 1 (OPA) numbers from the blog post table.

    Blog table (complyedge.io/blog/why-opa-rego-eu-ai-act.html) — refresh 2026-07-11:
      Article 5   | 6/10  — OPA catches canonical phrasings (+1 vs May)
      Article 50  | 4/8   — Pattern coverage grows with community PRs
      GPAI        | 4/5   —
      Safe harbor | 10/10 — Zero false positives
      Edge cases  | 5/7   — (+1 vs May); one non-critical miss remains
      US corpus   | 0/10  — All require use_semantic_fallback=True

    Layer 1 = prompts in category correctly handled on the OPA path, over category size.
    Example: Article 5 → 6/10 (6 on OPA path, all passed; 4 routed to Layer 2).
    """

    @staticmethod
    def _layer1_passed(results, category: str) -> tuple[int, int]:
        cat_rows = [r for r in results if r["category"] == category]
        opa_pass = sum(
            1 for r in cat_rows if r.get("engine_path") == "opa" and r["passed"]
        )
        return opa_pass, len(cat_rows)

    def test_article5_layer1_pass_rate(self, results):
        passed, total = self._layer1_passed(results, "article5")
        assert total == 10, f"Expected 10 Article 5 prompts, found {total}"
        assert passed == 6, f"Expected Article 5 Layer 1 pass = 6/10, got {passed}/10"

    def test_article50_layer1_pass_rate(self, results):
        passed, total = self._layer1_passed(results, "article50")
        assert total == 8, f"Expected 8 Article 50 prompts, found {total}"
        assert passed == 4, f"Expected Article 50 Layer 1 pass = 4/8, got {passed}/8"

    def test_gpai_layer1_pass_rate(self, results):
        passed, total = self._layer1_passed(results, "gpai")
        assert total == 5, f"Expected 5 GPAI prompts, found {total}"
        assert passed == 4, f"Expected GPAI Layer 1 pass = 4/5, got {passed}/4"

    def test_edge_layer1_pass_rate(self, results):
        passed, total = self._layer1_passed(results, "edge")
        assert total == 7, f"Expected 7 edge prompts, found {total}"
        assert passed == 5, f"Expected edge Layer 1 pass = 5/7, got {passed}/7"

    def test_us_corpus_layer1_pass_rate(self, results):
        passed, total = self._layer1_passed(results, "us_corpus")
        assert total == 10, f"Expected 10 US corpus prompts, found {total}"
        assert passed == 0, f"Expected US corpus Layer 1 pass = 0/10, got {passed}/10"


class TestUsCorpus:
    """Validates the US corpus results."""

    @pytest.fixture(scope="class")
    def us_results(self, results):
        return [r for r in results if r["category"] == "us_corpus"]

    def test_exactly_10_us_corpus_prompts(self, us_results):
        assert (
            len(us_results) == 10
        ), f"Expected 10 US corpus prompts, found {len(us_results)}"

    def test_us_corpus_all_handled_by_hybrid(self, us_results):
        # Blog: US corpus requires Layer 2 (use_semantic_fallback=True)
        non_hybrid = [r["id"] for r in us_results if r.get("engine_path") != "hybrid"]
        assert (
            non_hybrid == []
        ), f"US corpus prompts NOT handled by hybrid/Layer 2: {non_hybrid}"

    def test_us_corpus_end_to_end_pass(self, us_results):
        failed = [r["id"] for r in us_results if not r["passed"]]
        assert failed == [], f"US corpus prompts failed end-to-end: {failed}"
