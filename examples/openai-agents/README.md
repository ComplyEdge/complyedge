# OpenAI Agents + ComplyEdge Integration Examples

Shows how to run a ComplyEdge compliance check on every OpenAI Agents input. Each decision gets a record; a blocked one names the rule and the law behind it.

## Quick Start

1. **Install Dependencies** (the ComplyEdge SDK with the OpenAI Agents SDK):
   ```bash
   pip install -r requirements.txt
   ```

2. **Set your ComplyEdge API key**:
   ```bash
   export COMPLYEDGE_API_KEY="your-complyedge-key"
   ```

3. **Run Example**:
   ```bash
   python production_integration_example.py
   ```

The example calls the guardrail directly on five inputs, so no model runs and no OpenAI key is
needed. Each check writes one record to your audit trail. A block prints the rule that fired; a
check that could not run prints `ERROR`, so an outage is never counted as a block.

## Integration Pattern

```python
from agents import Agent
from complyedge.agents import create_compliance_guardrail

guardrail = create_compliance_guardrail(api_key="your-key")

agent = Agent(
    name="Checked Agent",
    input_guardrails=[guardrail],
)
```

## How It Works

1. User input goes through the ComplyEdge compliance check first (the Agents SDK's `input_guardrails` hook)
2. The API checks the input against the active rule corpus and writes a record with an `event_id`
3. Input that breaks no blocking rule passes to the agent; input that does is blocked, with the rule ID and citation
4. If the API cannot be reached, the input is blocked (this hook fails closed)

Keep the `event_id` next to your own copy of the input. Later you can prove which text a record was about with `POST /v1/audit/verify` or `ComplyEdge.verify_input`; ComplyEdge never stores the text. See https://complyedge.io/docs/audit-reconciliation.html
