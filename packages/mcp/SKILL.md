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

CI: `uses: complyedge/trustlint-action@v1`

GOPAL is an OPA library in your process. ComplyEdge is per-request deny + citation + AI Trust Center + MCP.

## Tools

- `check_compliance` — already-produced text
- `scan_prompt` — prompt about to be sent
- `list_rules` — corpus inventory, not a verdict
- `sandbox_check` — hosted enforcement, sandbox mode, nothing recorded. Local: only with `COMPLYEDGE_API_KEY`. Hosted MCP: send your key as `Authorization: Bearer` on the connection.

Offline TrustLint regex for the first three. `sandbox_check` is hosted, trial only, never evidence. Not legal advice.
