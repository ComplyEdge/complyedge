# ComplyEdge

Runtime compliance enforcement for AI agents. Not a scanner — runs in production, on every request. Evidence from day one.

**Article 5 is already law.** GPAI fines start August 2026. Your AI is either compliant right now, or it isn't.

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

Three lines of code. Every AI input and output evaluated. Violations blocked before they reach the user — with article citation, rule ID, and timestamp on every decision.

> What does your compliance tool tell a regulator when it blocks a request? A probability score?
> ComplyEdge says: **Article 5(1)(a), rule ID, timestamp, input hash.** One is an audit trail. One is a guess.

## Multi-Regulation Enforcement

```python
@compliance_check(rules=["eu-ai-act/article-5", "eu-ai-act/article-50"])
def my_agent(prompt):
    return llm.generate(prompt)
```

Rule paths map 1:1 to OPA/Rego policy paths. Same engine, any regulation.

## What's In This Repo

```
sdks/python/          Python SDK (@compliance_check decorator)
rules/regulations/    Rule corpus (EU AI Act Article 5, GDPR, PII, and more)
rules/schemas/        Rule validation schema
examples/             Usage examples (decorators, OpenAI Agents)
tests/                Rule validation tests
```

## Rules

Rules are YAML files in `rules/regulations/`, organized by jurisdiction:

```
rules/regulations/
├── eu/          EU AI Act Article 5 (prohibited practices), GDPR
├── us/          HIPAA, SOX, COPPA, TCPA
├── global/      PCI DSS
└── universal/   PII detection
```

Each rule specifies conditions, severity, detection scope, and remediation with legal citations. See the [rule schema](rules/schemas/rule-schema.json) for the format.

## Contributing

We welcome rule contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

Every rule must include:

- Article + paragraph + sub-paragraph citation
- Verifiable detection condition
- Test cases

## Architecture

**Layer 1 — Deterministic (hot path, <5ms):** OPA/Rego rules fire on every request. Binary: pass or block. Legal citation attached to every decision. No LLM on the hot path.

**Layer 2 — Interpretive (async, never blocks):** Clauses requiring legal judgment are queued and processed by LLM in background. LLM never makes a blocking decision — it surfaces evidence for humans to decide.

Security products protect AI from bad actors. **ComplyEdge protects companies from their own AI's legal violations during normal operations.**

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Links

- Website: [complyedge.io](https://complyedge.io)
