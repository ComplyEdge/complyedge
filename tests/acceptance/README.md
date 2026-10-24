# ComplyEdge Acceptance Tests

These tests verify claims from ComplyEdge public documentation. They are
offline only: no live API calls, no audit-row writes, no email sends.

## Run

```bash
pytest tests/acceptance/ -v
```

## Files

| File | What it covers |
|------|---------------|
| `test_corpus.py` | Rule/policy counts, SDK defaults, decorator config |
| `test_latency.py` | Latency numbers from the published benchmark JSON |
| `test_decorator.py` | `@compliance_check` fail-open behaviour (no live API) |
| `test_benchmark.py` | Benchmark result integrity |

## Source of truth

The claims come from the [launch blog post](https://complyedge.io/blog/why-opa-rego-eu-ai-act.html).
The tests read the files those claims rest on: the rule corpus under `rules/`
and the benchmark results under `scripts/benchmark/results/`. Where a test
pins a number the post no longer prints (the per-category Layer 1 counts), its
docstring says so.
