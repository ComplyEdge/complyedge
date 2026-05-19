# HN Draft — Show HN: ComplyEdge — runtime EU AI Act enforcement for Python

<!-- SUBMIT TO: https://news.ycombinator.com/submit -->
<!-- Title (use exactly, 62 chars): Show HN: ComplyEdge — runtime EU AI Act enforcement for Python -->
<!-- URL: https://github.com/ComplyEdge/complyedge -->
<!-- Timing: Tuesday 2026-05-19, 9–10 AM ET -->

---

We built an enforcement layer for AI agents: OPA/Rego on the hot path, LLM on the long tail, never the other way around. The design choice comes down to what a regulator actually needs — not a probability score, an audit trail.

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt):
    return llm.generate(prompt)  # every input/output checked
```

When Article 5(1)(c) fires on a social-scoring prompt:

```json
{
  "allowed": false,
  "violations": [{
    "rule_id": "rego-art5-1c-001",
    "rule_description": "Regulation (EU) 2024/1689, Article 5(1)(c): Prohibits AI systems that evaluate or classify natural persons based on their social behaviour or personal characteristics, with the social score leading to detrimental or unfavourable treatment.",
    "severity": "critical",
    "confidence": 1.0,
    "text_excerpt": "We use social credit scoring to evaluate loan applicants in the EU"
  }],
  "bundle_version": "opa-rego-v1",
  "engine_path": "opa",
  "latency_ms": 53,
  "opa_latency_ms": 48.77,
  "audit_logged": true
}
```

When OPA detects a violation it returns immediately: 38–96ms (median 58ms, n=14) on our 50-prompt benchmark. Pass `use_semantic_fallback=False` to skip Layer 2 entirely — the full 50-prompt run then comes in at median 73ms, p99 135ms. Default SDK behavior is OPA-only (`use_semantic_fallback=False` on the decorator and `check()`). Pass `use_semantic_fallback=True` per-request to enable LLM Layer 2 for ambiguous cases.

The corpus is curated, not adversarial: 19 Rego policies + 53 YAML rules across 4 jurisdictions. The benchmark runner and prompt YAMLs are in the repo — reproducible with any API key. What this is not: a model, a risk scorer, or a substitute for legal review. It evaluates rules.

Why OPA instead of an LLM for the blocking decision? The architectural rationale is in the blog post: https://github.com/ComplyEdge/complyedge/blob/main/docs/blog/why-opa-rego-eu-ai-act.md

Article 5 is already law. The deadline is not a deadline — it passed.

---

## Comment Response Prep (first 30 min)

**"Why not just use an LLM for compliance?"**
Regulators need citation chains, not probability scores. Article 5(1)(c) is a binary legal classification, not a confidence interval. TraceGov ran LLM-as-judge on the same corpus: 60–67% accuracy. A rule engine that says "Article 5(1)(c), rule rego-art5-1c-001, timestamp, input hash" is auditable. "The model said 0.87" isn't. The blog post covers this in depth.

**"Article 5(1)(c) is a binary legal classification, not a confidence interval."**
Exactly. That's the entire wedge. Rego is declarative — a rule either matches input or it doesn't. No temperature parameter.

**"EU AI Act isn't really enforced yet."**
Article 5 has been law since February 2, 2025. GPAI enforcement starts August 2, 2026 — 10 weeks out. Penalties: €35M or 7% of global revenue for prohibited-use violations; €15M or 3% for transparency failures.

**"Only 19 Rego rules? That's not enough."**
19 Rego policies + 53 YAML rules across 4 jurisdictions. EU covers Articles 4–27, 50, 53, GPAI, GDPR. US covers HIPAA, SOX, COPPA, TCPA, BIPA, CCPA, Colorado AI Act, NYC LL144, ECPA. Plus PCI DSS and prompt injection detection. Curated, not exhaustive — open source means community PRs fill the gaps. CONTRIBUTING.md explains the format.

**"Can't I just write my own regex rules?"**
Yes — the engine is Apache 2.0 for exactly that. The value is the curated corpus + citation chain + immutable audit log, not the matcher. Same relationship as Snyk vs writing your own vuln scanner.

**"Your benchmark shows 855ms median / 2.7s p99, not 100ms."**
Honest split: 38–96ms (median 58ms, n=14) is the OPA-violation fast path — OPA fires, pattern matches, blocks immediately. For the other 36 allow cases when `use_semantic_fallback=True` is passed, Layer 2 LLM adds 1.6–2.8s. Pass `use_semantic_fallback=False` and the whole 50-prompt benchmark runs at median 73ms, p99 135ms — that's the OPA-only number. Both modes and their raw latencies are in the benchmark JSON in the repo — run it yourself with `scripts/benchmark/runtime_benchmark.py`.

**"The Layer 2 LLM blocks — so it's not truly async."**
Correct. Layer 2 blocks the API response when it runs. Default decorator behavior is OPA-only (`use_semantic_fallback=False` since v0.2.2). Layer 2 LLM is opt-in per request. If you want LLM coverage of ambiguous cases, pass `use_semantic_fallback=True` explicitly.

**"What about US regulations?"**
US corpus exists: HIPAA, SOX, COPPA, TCPA, BIPA — use `jurisdiction="US"`. 2026 focus is EU AI Act because the enforcement timeline is hard and imminent. US expansion follows.
