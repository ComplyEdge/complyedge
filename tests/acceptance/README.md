# ComplyEdge Acceptance Tests

These tests verify every claim made in the ComplyEdge public documentation and
launch articles. They are intentionally written for a **first-time reader**:
each test clearly states *what it checks* and *which public claim it backs*.

## Two tiers

| Tier | What | When |
|------|------|------|
| **offline** | Corpus files, Rego policies, SDK source, benchmark JSON | Always runs — no credentials needed |
| **live** | Real API calls with `COMPLYEDGE_API_KEY` | Runs when the env var is set; otherwise tests are skipped |

## Run offline suite only

```bash
pytest tests/acceptance/ -v
```

## Run full suite (offline + live)

```bash
COMPLYEDGE_API_KEY=<your-key> pytest tests/acceptance/ -v
```

## Files

| File | What it covers |
|------|---------------|
| `test_corpus.py` | Rule/policy counts, SDK defaults, decorator config |
| `test_api_shape.py` | API response shape, fields, and live enforcement behaviour |
| `test_latency.py` | Latency numbers from the published benchmark + one live call |
| `test_decorator.py` | `@compliance_check` decorator behaviour end-to-end |
| `test_benchmark.py` | Benchmark result integrity (50 prompts, 6 categories, safe-harbor) |

## Source of truth

The claims tested here come from:
- [Launch blog post](../../docs/blog/why-opa-rego-eu-ai-act.md)
