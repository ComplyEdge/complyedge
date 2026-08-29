---
name: complyedge-eu-ai-act-runtime-deny
description: >
  Runtime deny for EU AI Act Article 5 and Article 50 on this prompt or output
  via ComplyEdge TrustLint MCP. Use when the user wants agent I/O compliance
  enforcement, not system classification, FRIA forms, or C2PA watermarking.
---

# ComplyEdge — EU AI Act runtime deny

Classifiers named `eu-ai-act-*` score the *system*. ComplyEdge denies *this*
prompt or output now, with an article citation. Article 50 here is unlabeled
or deceptive use, not C2PA.

## Install

```bash
npx -y @complyedge/mcp
pip install complyedge
pip install trustlint
pip install 'complyedge[mcp]'
claude mcp add complyedge -- npx -y @complyedge/mcp
```

Hosted MCP: `https://mcp.complyedge.io/mcp`

Hosted SDK extra (needs `COMPLYEDGE_API_KEY`):

```bash
pip install 'complyedge[agents]'
```

```python
from complyedge.agents import create_compliance_guardrail
```

## Tools

- `check_compliance` — already-produced text
- `scan_prompt` — prompt about to be sent
- `list_rules` — corpus inventory, not a verdict

Offline TrustLint regex. Not hosted OPA. Not legal advice.
