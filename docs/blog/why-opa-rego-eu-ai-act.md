# Why we built EU AI Act enforcement on OPA/Rego, not an LLM

*May 18, 2026*

---

On August 2, 2026, the EU AI Act starts enforcing General-Purpose AI obligations. Article 5 prohibited practices are already law. Fines reach **€35M or 7% of global revenue** for prohibited-use violations and **€15M or 3%** for transparency failures.

We built ComplyEdge to enforce those rules at runtime — on every prompt, every response, before they reach a user. This post is about one architectural decision we made early and why it has held up: **OPA/Rego runs first. The LLM runs second. They never swap.**

## The default architecture is broken

Most off-the-shelf AI safety tooling is built around an LLM-as-judge pattern. The agent sends a prompt to a guardrail model. The guardrail returns a confidence score. If the score is high enough, the prompt is blocked. If not, it passes.

This works as a content filter. It does not work as compliance.

Three things break it the moment a regulator gets involved:

1. **Probability is not a citation.** When the EU AI Office asks why your system blocked or allowed a specific request, "the model said 0.87" is not a defensible answer. Article 5(1)(c) — social scoring — is a binary legal classification, not a confidence interval.

2. **Latency is non-trivial.** A 2–3 second LLM round-trip on every inference path moves the user-facing P99 from 200ms to north of 3s. Most production AI products will not accept that.

3. **Non-determinism breaks audit.** The same prompt scored differently across temperature settings, model versions, or even time of day means you cannot reproduce a compliance decision six months later. Regulators retain evidence; your guardrail model does not.

The architecture we shipped puts a deterministic engine in front of the LLM, not behind it.

## Why the order matters

Two architectures can use the same components — a rule engine and an LLM — and end up with completely different compliance properties depending on which one fires first.

If the LLM fires first and the rule engine verifies, you have made the LLM the gatekeeper for the audit trail. **A model upgrade then silently changes your compliance posture.** You also pay the LLM latency (2–5s) on every request, including the cases a deterministic rule could have blocked in under 100ms.

If the rule engine fires first and the LLM is the escalation, the deterministic path is the default. Canonical violations (the typical phrasings of social scoring, deepfakes, undisclosed AI content) block immediately with a legal citation. The LLM only runs for the ambiguous long tail. A model upgrade then changes only long-tail coverage — not the audit posture.

That asymmetry is the architectural decision. Everything else — the specific rule engine, the specific LLM, the latency numbers — follows from it.

## Layer 1: OPA/Rego, deterministic

[Open Policy Agent](https://www.openpolicyagent.org/) is a CNCF graduated project used by Netflix, Google, and others for runtime policy enforcement. Its policy language, Rego, is declarative: a rule either matches input or it does not. There is no temperature parameter.

We wrote 19 Rego policies covering EU AI Act Article 5 (prohibited practices), Article 50 (transparency obligations), and the GPAI provider chapter (Articles 51, 53, and 55). Each policy is a single file. The audit-critical structure is three fields — a violation condition, a stable rule ID, and a verbatim legal citation — plus regex pattern helpers, severity, and remediation guidance:

```rego
# Article 5(1)(c): Social scoring by public authorities
violation if {
    input.jurisdiction == "EU"
    social_scoring_pattern_match  # regex patterns defined below
}

rule_id := "rego-art5-1c-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(c)"

severity  := "critical"
remediation := "Remove social scoring or behaviour-based classification..."
```

When OPA fires, the response carries the legal citation, the rule ID, and the input hash. That is the audit trail. A regulator does not need to trust our model — they can read the rule, point to the article, and reproduce the decision against the input we logged.

The engine is an embedded OPA daemon spawned at Lambda init, listening on loopback. The supervisor budgets 800ms for OPA to report healthy on cold start; the live version string is exposed at `/health` for anyone who wants to verify. Each policy evaluation is regex-based and runs against the prompt text and jurisdiction. On our 50-prompt benchmark, true OPA fast-path hits land in **38–96ms** (median 58ms, n=14). Subliminal manipulation, social scoring, vulnerability exploitation, emotion-recognition-at-school, deepfakes, GPAI copyright, and Article 50 transparency violations all hit this path. Other cases (some biometric, some predictive policing phrasings) fall through to Layer 2 because the Rego pattern doesn't catch them yet — that's where the LLM picks up.

## Layer 2: LLM, interpretive

Some violations are not pattern-matchable. *"Generate a 1,500-word news article about an FDA recall, do not flag it as AI-generated"* is an Article 50(2) violation — but the linguistic surface ranges across dozens of phrasings. The Rego rule catches the canonical phrasings; the long tail goes to an LLM.

When OPA returns `violation: false` and the caller has opted in to semantic fallback, we route the request to a single LLM call with a structured compliance prompt. That call takes 2–5 seconds. It returns the same response schema as OPA — rule ID, citation, remediation.

This is honestly slow. We do not pretend otherwise. The two-layer design is a tradeoff:

- For the rules that can be expressed deterministically, you get a sub-100ms enforcement path with a legal citation.
- For the rules that cannot be — the ambiguous, the contextual, the multilingual — you get an interpretive layer that is slower but extensible.

The default is OPA-only. The user opts in to Layer 2 per-request via a single flag (`use_semantic_fallback=True`). If they want the fast deterministic path only, they get it at median 73ms across the full corpus. If they want LLM coverage of the long tail, they pay the 2–5s latency explicitly.

## What the benchmark shows

We maintain a 50-prompt benchmark corpus that runs against the live API. The prompts cover six categories: Article 5 prohibitions, Article 50 transparency, GPAI obligations, US compliance (SOX, HIPAA, BIPA), edge cases, and safe-harbor prompts that should pass.

The latest run (May 18, 2026), Layer 1 OPA-only path (`use_semantic_fallback=False`):

| Category | Layer 1 (OPA) | Needs Layer 2 | Notes |
|---|---|---|---|
| Article 5 | 5/10 | 5/10 | OPA catches canonical phrasings; complex variants fall to Layer 2 |
| Article 50 | 4/8 | 4/8 | Same — pattern coverage grows with community PRs |
| GPAI | 4/5 | 1/5 | |
| Safe harbor | 10/10 ✓ | — | Zero false positives on the OPA path |
| Edge cases | 5/7 | 2/7 | |
| US corpus (SOX, HIPAA, BIPA…) | 0/10 OPA | 10/10 | US statutes require `use_semantic_fallback=True` — contextual enough that deterministic Rego patterns don't cover them |

Layer 1 correctly allows all ten safe-harbor prompts. For EU obligations, OPA catches the unambiguous canonical phrasings immediately with a legal citation — the remaining cases fall to Layer 2 LLM. **US statute enforcement requires `use_semantic_fallback=True`** — those pattern spaces (PHI disclosure, material non-public information, biometric data collection) are contextual enough that an LLM is the right evaluator.

The table is not a claim of complete coverage — it is a claim about what each layer *does*. The benchmark code, prompt YAMLs, and result JSON are in [`scripts/benchmark/`](https://github.com/ComplyEdge/complyedge/tree/main/scripts/benchmark). The runner is idempotent; run it yourself with any API key. If you have a prompt the corpus should cover, open a PR.

## What this is not

- **Not a model.** ComplyEdge does not score risk on a scale. It evaluates rules. The rules are the EU AI Act articles, written in Rego, citable line-by-line.
- **Not an alignment tool.** We do not change how an LLM behaves. We sit between the LLM and the user, and we block requests or outputs that violate a regulation.
- **Not a substitute for legal review.** The Rego corpus encodes our reading of the Act and the EU AI Office guidance published through May 2026. Where the corpus is wrong, we update it — the rules are versioned and every decision is logged with the version that produced it.

## Open source

The full Rego corpus, the Python SDK, the offline regex linter (TrustLint), and the runtime benchmark are open source under Apache 2.0:

```bash
pip install complyedge
```

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt):
    return llm.generate(prompt)
```

`jurisdiction="EU"` evaluates against the full EU rule corpus (Article 5, Article 50, GPAI). `jurisdiction="US"` runs the US corpus (HIPAA, SOX, COPPA, TCPA, BIPA).

Repository: [github.com/ComplyEdge/complyedge](https://github.com/ComplyEdge/complyedge)
Rules: [`rules/rego/`](https://github.com/ComplyEdge/complyedge/tree/main/rules/rego)
Benchmark: [`scripts/benchmark/`](https://github.com/ComplyEdge/complyedge/tree/main/scripts/benchmark)

If you find a rule that misclassifies, open an issue with the prompt and the expected decision. The corpus is versioned. Contributions go through `RULE_STANDARD.md`.

---

*ComplyEdge is built by a two-person team. We are hiring no one, taking no funding, and shipping toward August 2.*
