# ComplyEdge Integration Examples

Working examples showing how to add compliance checking to AI agents.

## Decorator Examples

Add a compliance check to any Python function with one line:

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt: str) -> str:
    return llm.generate(prompt)
```

See [`decorators/`](decorators/) for examples across HR, credit, content moderation, and more.

## OpenAI Agents Examples

Run a compliance check on every OpenAI Agents input (it plugs into the Agents SDK's `input_guardrails` hook), with a record per decision:

```python
from complyedge.agents import create_compliance_guardrail
from agents import Agent

guardrail = create_compliance_guardrail(api_key="your-key")

agent = Agent(
    name="Checked Agent",
    input_guardrails=[guardrail],
)
```

See [`openai-agents/`](openai-agents/) for complete integration examples.

## Capability Probe

Check what ComplyEdge actually blocks (Article 5 practices and prompt injection in content an agent
reads) and where it stops, offline with `opa` or live against your tenant:

```bash
python capability-probe/probe.py
```

See [`capability-probe/`](capability-probe/) for the cases and the known gaps.

## Output Gate

Check a model's answer before it reaches a user, on three EU AI Act cases (a safe baseline and two
Article 5(1)(c) social-scoring texts), with prompts pre-filled so no LLM is needed:

```bash
python output-gate/eu_fintech_compliance.py
```

## Signed Audit Trail

A home-built signed audit log (Ed25519 plus a hash chain) next to the ComplyEdge export: one SQL
UPDATE, then the same edit re-signed and re-chained, and what a chain anchored outside the audit
store catches that a local chain cannot. Runs offline on recorded decisions and the shipped export. See [`signed-audit-trail/`](signed-audit-trail/).

## Sample Audit Export

[`audit/sample-audit-export.json`](audit/sample-audit-export.json) is a reference export: the
shape of the records a tenant downloads.

## Environment Setup

```bash
pip install complyedge                 # decorators, output gate
pip install "complyedge[agents]"       # adds the OpenAI Agents SDK for the guardrail example
export COMPLYEDGE_API_KEY="your-key"
export COMPLYEDGE_ENABLED="true"
```

The capability probe needs no key offline (it runs the shipped rules with `opa`), and the signed
audit trail installs its own requirements (`pip install -r signed-audit-trail/requirements.txt`).
