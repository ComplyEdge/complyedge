# ComplyEdge Integration Examples

Working examples showing how to add compliance checking to AI agents.

## Decorator Examples

Add compliance to any Python function with one line:

```python
from complyedge import compliance_check

@compliance_check(rules="eu-ai-act/article-5")
def my_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

See [`decorators/`](decorators/) for examples across HR, credit, content moderation, and more.

## OpenAI Agents Examples

Add compliance guardrails to OpenAI Agents:

```python
from complyedge.agents import create_compliance_guardrail
from agents import Agent

guardrail = create_compliance_guardrail(
    api_key="your-key",
    rules="eu-ai-act/article-5",
)

agent = Agent(
    name="Compliant Agent",
    input_guardrails=[guardrail],
)
```

See [`openai-agents/`](openai-agents/) for complete integration examples.

## Environment Setup

```bash
pip install complyedge
export COMPLYEDGE_API_KEY="your-key"
export COMPLYEDGE_ENABLED="true"
```
