# OpenAI Agents + ComplyEdge Integration Examples

Shows how to add EU AI Act compliance to OpenAI Agents with one line of code.

## Quick Start

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Set API Keys**:
   ```bash
   export OPENAI_API_KEY="sk-your-openai-key"
   export COMPLYEDGE_API_KEY="your-complyedge-key"
   ```

3. **Run Example**:
   ```bash
   python production_integration_example.py
   ```

## Integration Pattern

```python
from agents import Agent
from complyedge.agents import create_compliance_guardrail

guardrail = create_compliance_guardrail(
    api_key="your-key",
    rules="eu-ai-act/article-5",
)

agent = Agent(
    name="Compliant Agent",
    input_guardrails=[guardrail],
)
```

## How It Works

1. User input goes through ComplyEdge guardrail first
2. Production API checks against the specified rules
3. Safe content passes to the agent; violations are blocked
4. Conservative blocking on any API errors
