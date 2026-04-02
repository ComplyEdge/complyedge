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

@compliance_check(rules="eu-ai-act/article-5")
def my_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

## Multiple Rules

```python
@compliance_check(rules=["eu-ai-act/article-5", "gdpr/consent"])
def my_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

## Input-Only / Output-Only

```python
# Check input before it reaches the LLM
@compliance_check(rules="eu-ai-act/article-5", input=True, output=False)
def intake_agent(prompt: str) -> str:
    return llm.generate(prompt)

# Check output before it reaches the user
@compliance_check(rules="eu-ai-act/article-5", input=False, output=True)
def generation_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

## Example File

- **`ai-agent-examples.py`** — EU AI Act Article 5, multi-regulation, input/output control, enterprise configuration

## Environment Setup

```bash
export COMPLYEDGE_API_KEY="your-key"
export COMPLYEDGE_ENABLED="true"
```