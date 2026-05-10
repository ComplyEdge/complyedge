# ComplyEdge

[![PyPI](https://img.shields.io/pypi/v/complyedge)](https://pypi.org/project/complyedge/)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Runtime compliance enforcement for AI agents. Not a scanner — runs in production, on every request.

**Article 5 is already law.** GPAI fines start August 2, 2026. Your AI is either compliant right now, or it isn't.

> What does your compliance tool tell a regulator when it blocks a request? A probability score?
>
> ComplyEdge says: **Article 5(1)(a), rule EU_AI_ACT_ARTICLE5_SUBLIMINAL_001, timestamp, input hash.** One is an audit trail. One is a guess.

## Quick Start

```bash
pip install complyedge
```

```python
from complyedge import compliance_check

@compliance_check(rules="eu-ai-act/article-5")
def my_agent(prompt):
    return llm.generate(prompt)  # every input and output checked
```

Three lines. Every AI input and output evaluated against EU AI Act Article 5 prohibited practices. Violations blocked before they reach the user — with article citation, rule ID, and timestamp on every decision.

## Multi-Regulation Enforcement

```python
@compliance_check(rules=["eu-ai-act/article-5", "eu-ai-act/article-50"])
def my_agent(prompt):
    return llm.generate(prompt)
```

Rule paths map 1:1 to OPA/Rego policy paths. Same engine, any regulation.

## TrustLint — Offline Linter

No API key required. Scans text against the rule corpus using regex patterns.

```bash
pip install trustlint

trustlint check --text "We use social credit scoring to evaluate applicants"
# → CRITICAL: EU_AI_ACT_ARTICLE5_SOCIAL_SCORING_001 — Article 5(1)(c)
```

Exit codes: `0` = pass, `1` = violations found. Designed for CI/CD pipelines.

## What's In This Repo

```
sdks/python/          Python SDK (@compliance_check decorator, CLI)
rules/regulations/    25 YAML rules (EU AI Act, GDPR, HIPAA, SOX, PCI DSS)
rules/rego/           19 OPA/Rego policies (EU AI Act Article 5, 50, GPAI)
rules/schemas/        Rule validation schema
examples/             Usage examples (decorators, OpenAI Agents)
tests/                Rule validation tests
```

## Rules

25 YAML rules + 19 OPA/Rego policies across 4 jurisdictions:

| Jurisdiction | Rules | Regulations |
|---|---|---|
| **EU** | 18 YAML + 19 Rego | EU AI Act Article 5, Article 50, GPAI, GDPR |
| **US** | 5 YAML | HIPAA, SOX, COPPA, TCPA |
| **Global** | 1 YAML | PCI DSS |
| **Universal** | 1 YAML | PII detection |

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
    field: text
    pattern: "prohibited pattern"
    description: "Matches prohibited practice X"
source:
  regulation: "EU AI Act"
  article: "Article Y(1)(z)"
```

Validate: `cd rules && python scripts/validate_rules.py`

## Architecture

**Layer 1 — Deterministic (hot path, < 5ms):** 19 OPA/Rego policies + TrustLint regex engine fire on every request. Binary pass/block. Legal citation attached to every decision. No LLM on the hot path.

**Layer 2 — Interpretive (async, never blocks):** Clauses requiring legal judgment are queued for LLM analysis in background. The LLM never makes a blocking decision — it surfaces evidence for humans to decide.

Security products protect AI from bad actors. **ComplyEdge protects companies from their own AI's legal violations during normal operations.**

## Contributing

We welcome rule contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

Every rule must include: article + paragraph citation, verifiable detection condition, and test cases.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Links

- **Website**: [complyedge.io](https://complyedge.io)
- **PyPI**: [pypi.org/project/complyedge](https://pypi.org/project/complyedge/)
- **Rule Schema**: [rules/schemas/rule-schema.json](rules/schemas/rule-schema.json)
