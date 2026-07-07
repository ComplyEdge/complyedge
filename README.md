# ComplyEdge

[![PyPI](https://img.shields.io/pypi/v/complyedge)](https://pypi.org/project/complyedge/)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Runtime compliance enforcement for AI agents. Not a scanner — runs in production, on every request.

**Article 5 is already law.** GPAI fines start August 2, 2026 — and Article 50 transparency binds deployers the same day. If you run a chatbot or publish AI-generated content, that clock is yours, not just your model provider's. Your AI is either compliant right now, or it isn't.

> What does your compliance tool tell a regulator when it blocks a request? A probability score?
>
> ComplyEdge says: **Article 5(1)(a), rule `rego-art5-1a-001`, timestamp, input hash.** One is an audit trail. One is a guess.

## Quick Start

```bash
pip install complyedge
```

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt):
    return llm.generate(prompt)  # every input and output checked
```

Three lines. Every AI input and output evaluated against the EU AI Act rule corpus (Article 5, Article 50, GPAI). Violations blocked before they reach the user — with article citation, rule ID, and timestamp on every decision.

Set `COMPLYEDGE_API_KEY` to your key. The decorator activates by default; to disable without removing the key (e.g., in CI), set `COMPLYEDGE_ENABLED=false`.

## Without a decorator

```python
from complyedge import is_safe, check
import os

api_key = os.environ["COMPLYEDGE_API_KEY"]

# Boolean check — returns True if no violations
if not is_safe(prompt, api_key=api_key, jurisdiction="EU"):
    raise ValueError("Prompt violates EU AI Act")

# Full result — returns ComplianceResult with violations + citations
result = check(prompt, api_key=api_key, jurisdiction="EU")
if not result.allowed:
    for v in result.violations:
        print(v.rule_id, v.citation)
```

Jurisdiction maps to the rule corpus: `EU` evaluates against EU AI Act Article 5, Article 50, and GPAI obligations. `US` evaluates against HIPAA, SOX, COPPA, TCPA, BIPA.

## TrustLint — Offline Linter

No API key required. Scans text against the YAML rule corpus using regex patterns. Published as a standalone package, versioned independently of the SDK.

```bash
pip install trustlint

trustlint check --text "We use social credit scoring to evaluate applicants"
# → CRITICAL: EU_AI_ACT_ART5_SOCIAL_SCORING_001 — Article 5(1)(c)
```

Exit codes: `0` = pass, `1` = violations found. Designed for CI/CD pipelines. Source: [`packages/trustlint/`](packages/trustlint).

## Rule IDs — two namespaces

ComplyEdge resolves the same regulations through two engines, each with its own rule-ID namespace:

- **Runtime API (OPA/Rego):** IDs like `rego-art5-1c-001` — returned by `compliance_check` and the `/v1/check` API. This is the audit trail your production system logs.
- **TrustLint (offline, YAML corpus):** IDs like `EU_AI_ACT_ART5_SOCIAL_SCORING_001` — emitted by the offline linter.

Both cite the same legal article and differ only in engine. Map between them via the article reference carried in every rule.

## What's In This Repo

```
sdks/python/          Python SDK (@compliance_check decorator, CLI)
packages/trustlint/   Offline regex linter (TrustLint) — no API key, for CI/CD
rules/regulations/    53 YAML rules (EU AI Act, GDPR, HIPAA, SOX, PCI DSS, and more)
rules/rego/           19 OPA/Rego policies (EU AI Act Article 5, 50, GPAI)
rules/schemas/        Rule validation schema
examples/             Usage examples (decorators, OpenAI Agents)
scripts/benchmark/    Runtime benchmark (runner + prompt YAMLs + committed results)
tests/                Rule validation + acceptance tests
```

## Rules

53 YAML rules + 19 OPA/Rego policies across 4 jurisdictions:

| Jurisdiction | Rules | Regulations |
|---|---|---|
| **EU** | 36 YAML + 19 Rego | EU AI Act Articles 4–6, 9–10, 12–16, 26–27, 50, 53, GPAI, GDPR |
| **US** | 13 YAML | HIPAA, SOX, COPPA, TCPA, BIPA, CCPA, Colorado AI Act, NYC LL144, ECPA |
| **Global** | 1 YAML | PCI DSS |
| **Universal** | 3 YAML | PII detection, prompt injection (direct + indirect) |

Each rule specifies conditions, severity, detection scope, and remediation with legal citations. See the [rule schema](rules/schemas/rule-schema.json) for the format.

### Writing Custom Rules

```yaml
id: MY_CUSTOM_RULE_001
jurisdiction: EU
effective_date: "2025-02-02"
description: "Detect prohibited practice X under Article Y"
severity: critical
conditions:
  - type: regex
    value: "prohibited pattern"
    description: "Matches prohibited practice X"
source:
  regulation: "EU AI Act"
  article: "Article Y(1)(z)"
```

Validate: `cd rules && python scripts/validate_rules.py`

## Architecture

**Layer 1 — Deterministic (hot path):** 19 OPA/Rego policies evaluate every request. Blocked prompts return with a legal citation in tens of milliseconds — 38–100ms (median 62ms) across the OPA-blocked prompts in our benchmark. Binary pass/block, no LLM on the hot path. (TrustLint applies the same regex corpus offline for CI use.)

**Layer 2 — Interpretive (synchronous, opt-in):** When called with `use_semantic_fallback=True`, an LLM evaluates the request and blocks if a violation is found. Off by default since v0.2.2. Adds 2–5s latency per request.

Security products protect AI from bad actors. **ComplyEdge protects companies from their own AI's legal violations during normal operations.**

## Benchmark

A 50-prompt corpus runs against the live API. The runner, prompt YAMLs, and the latest result JSON are committed under [`scripts/benchmark/`](scripts/benchmark) — inspect the results directly, or re-run with your own `COMPLYEDGE_API_KEY`.

## Contributing

We welcome rule contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

Every rule must include: article + paragraph citation, verifiable detection condition, and test cases.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md). Do not open a public issue for security reports.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Links

- **Website**: [complyedge.io](https://complyedge.io)
- **Blog**: [complyedge.io/blog/](https://complyedge.io/blog/)
- **GPAI Compliance Benchmark**: [complyedge.io/blog/gpai-compliance-benchmark.html](https://complyedge.io/blog/gpai-compliance-benchmark.html)
- **Why OPA/Rego for EU AI Act**: [complyedge.io/blog/why-opa-rego-eu-ai-act.html](https://complyedge.io/blog/why-opa-rego-eu-ai-act.html)
- **PyPI**: [pypi.org/project/complyedge](https://pypi.org/project/complyedge/)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **Rule Schema**: [rules/schemas/rule-schema.json](rules/schemas/rule-schema.json)
