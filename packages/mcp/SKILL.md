---
name: complyedge-eu-ai-act-check-and-cite
description: >
  Check this prompt or output against EU AI Act Article 5 and Article 50 rules
  and cite the article, via the ComplyEdge TrustLint MCP. Use when the user
  wants agent I/O checked and cited, not system classification, FRIA forms, or
  C2PA watermarking.
---

# ComplyEdge: EU AI Act check and cite

Classifiers named `eu-ai-act-*` score the *system*. ComplyEdge checks *this*
prompt or output, with a citation on every finding: the article for legal
rules, while the card-number and personal-data detectors name an industry
standard or say they are not law. Article 50 here is unlabeled or deceptive
use, not C2PA.

The first three tools below record nothing. Run locally (npx or
complyedge-mcp) they make no network call; on the hosted MCP the text is sent
to ComplyEdge's server for that call and not stored. The hosted check path
(the SDK and `POST /v1/check`, with your API key) writes an audit record for
every decision: timestamp, a keyed hash of the text, an `event_id`, and the rule IDs
and citations when a rule fires; never the text itself.

## Install

Each line is an alternative; pick the one you need.

```bash
npx -y @complyedge/mcp                               # this MCP server (Node)
claude mcp add complyedge -- npx -y @complyedge/mcp  # add it to Claude Code
pip install 'complyedge[mcp]'                        # the same tools as a Python MCP server: complyedge-mcp
pip install complyedge                               # Python SDK for hosted checks, no MCP server
pip install trustlint                                # offline linter CLI, no MCP server
```

Hosted MCP: `https://mcp.complyedge.io/mcp`

Hosted SDK extra for OpenAI Agents (needs `COMPLYEDGE_API_KEY`):

```bash
pip install 'complyedge[agents]'
```

```python
from complyedge.agents import create_compliance_guardrail
```

CI: `uses: complyedge/trustlint-action@v1`

## Tools

- `check_compliance`: already-produced text
- `scan_prompt`: prompt about to be sent
- `list_rules`: corpus inventory, not a verdict
- `sandbox_check`: hosted check in sandbox mode, nothing recorded. Local: only with `COMPLYEDGE_API_KEY`. Hosted MCP: send your key as `Authorization: Bearer` on the connection.

TrustLint regex for the first three: offline when run locally, on ComplyEdge's server (not stored) on the hosted MCP. `sandbox_check` is hosted, trial only, never evidence. Not legal advice.
