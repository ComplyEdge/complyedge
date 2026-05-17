# ComplyEdge Decorator Examples

Add EU AI Act compliance to any Python function with one decorator.

## Quick Start

```bash
pip install complyedge
export COMPLYEDGE_API_KEY="your_api_key_here"
python ai-agent-examples.py
```

## Basic Usage

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

The `jurisdiction` parameter selects the rule corpus evaluated server-side:

| Value | Corpus |
|---|---|
| `EU` | EU AI Act Article 5 + Article 50 + GPAI (Articles 51–55) |
| `US` | HIPAA, SOX, COPPA, TCPA, BIPA |

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

- **`ai-agent-examples.py`** — EU AI Act, US compliance, input/output control, enterprise configuration

## Environment Setup

```bash
export COMPLYEDGE_API_KEY="your-key"
export COMPLYEDGE_ENABLED="true"
```
