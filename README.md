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
rules/regulations/    53 YAML rules (EU AI Act, GDPR, HIPAA, SOX, PCI DSS, and more)
rules/rego/           19 OPA/Rego policies (EU AI Act Article 5, 50, GPAI)
rules/schemas/        Rule validation schema
examples/             Usage examples (decorators, OpenAI Agents)
tests/                Rule validation tests
```

## Rules

53 YAML rules + 19 OPA/Rego policies across 4 jurisdictions:

| Jurisdiction | Rules | Regulations |
|---|---|---|
| **EU** | 36 YAML + 19 Rego | EU AI Act Articles 4–27, 50, 53, GPAI, GDPR |
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
    field: text
    pattern: "prohibited pattern"
    description: "Matches prohibited practice X"
source:
  regulation: "EU AI Act"
  article: "Article Y(1)(z)"
```

Validate: `cd rules && python scripts/validate_rules.py`

## Architecture

**Layer 1 — Deterministic (hot path, <100ms p99):** 19 OPA/Rego policies + TrustLint regex engine fire on every request. Binary pass/block. Legal citation attached to every decision. No LLM on the hot path.

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
