# ComplyEdge Python SDK

Runtime compliance engine for EU AI Act. Open source. Deterministic.

## Installation

```bash
pip install complyedge
```

## Quick Start — EU AI Act Article 5 in Three Lines

```python
from complyedge import compliance_check

@compliance_check(rules="eu-ai-act/article-5")
def my_agent(prompt):
    return llm.generate(prompt)  # every output checked
```

That's it. Every input and output is checked against Article 5 prohibited practices. Violations are blocked before they reach the user, with legal citation, rule ID, and timestamp on every check.

## Multi-Regulation Enforcement

```python
# Enforce multiple rules — same pattern
@compliance_check(rules=["eu-ai-act/article-5", "eu-ai-act/article-50"])
def my_agent(prompt):
    return llm.generate(prompt)

# Add GDPR tomorrow — no API changes
@compliance_check(rules=["eu-ai-act/article-5", "gdpr/article-17"])
def my_agent(prompt):
    return llm.generate(prompt)
```

Rule paths map 1:1 to OPA/Rego policy paths. Same engine, any regulation.

> **Note:** The `rules=` path pattern is the canonical API (decided 2026-03-29).
> Legacy patterns (`jurisdiction=`, `create_sox_guardrail()`) are from the pre-pivot
> product and will be deprecated.

## Additional Installation Options

```bash
# Development setup
pip install complyedge[dev]

# Local development from source
pip install -e ./sdks/python
```

## Client API Usage

```python
from complyedge import ComplyEdge

ce = ComplyEdge(api_key="your-key")
result = ce.check("AI-generated content", rules="eu-ai-act/article-5")

if result.safe:
    print("Content approved")
else:
    print(f"Blocked: {result.violations}")
```

## Documentation

See the [ComplyEdge Documentation](https://docs.complyedge.io) for complete guides.
