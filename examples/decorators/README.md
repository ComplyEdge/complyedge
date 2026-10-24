# ComplyEdge Decorator Examples

Add a ComplyEdge check, and a record of each decision, to any Python function with one decorator.

## Quick Start

```bash
pip install complyedge
export COMPLYEDGE_API_KEY="your_api_key_here"
python ai-agent-examples.py
```

With the key set, every call goes through `/v1/check` and writes one record to your audit trail; the
social-scoring intake request is blocked. Without a key the script runs with checking off and says so.

## Basic Usage

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

The `jurisdiction` parameter selects the rule corpus evaluated server-side:

| Value | What the hosted API runs |
|---|---|
| `EU` | EU AI Act: Article 5 prohibited practices; Article 6 (text describing an Annex III use); Articles 4, 9 to 16, 26, 27, 50 and the GPAI articles 51 to 55 (text describing a missing control); personal data and secrets (GDPR Articles 5(1)(c) and 32(1)); prompt-injection detection |
| `US`, `US-*` | SOX §302 material disclosure; prompt-injection detection |

On either jurisdiction a rule that fires blocks the call: the decorator raises `ComplianceError` unless you pass a `violation_handler`. The other US rules (HIPAA, COPPA, TCPA, BIPA, CCPA, NYC LL144, ECPA) run offline in TrustLint (`pip install trustlint`), not on the hosted `/v1/check` path.

## Input-Only / Output-Only

```python
# Check input before it reaches the LLM
@compliance_check(jurisdiction="EU", input=True, output=False, agent_id="intake")
def intake_agent(prompt: str) -> str:
    return llm.generate(prompt)

# Check output before it reaches the user
@compliance_check(jurisdiction="EU", input=False, output=True, agent_id="generator")
def generation_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

## Example File

- **`ai-agent-examples.py`**: EU AI Act, US compliance, input/output control, enterprise configuration

## Environment Setup

```bash
export COMPLYEDGE_API_KEY="your-key"
export COMPLYEDGE_ENABLED="true"
```
