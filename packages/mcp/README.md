# @complyedge/mcp

[![npm version](https://img.shields.io/npm/v/@complyedge/mcp)](https://www.npmjs.com/package/@complyedge/mcp)
[![npm downloads](https://img.shields.io/npm/dw/@complyedge/mcp)](https://www.npmjs.com/package/@complyedge/mcp)
[![license](https://img.shields.io/npm/l/@complyedge/mcp)](https://github.com/ComplyEdge/complyedge/blob/main/LICENSE)

Offline checks of prompts and answers against the bundled TrustLint rule set (63 YAML rules: EU AI Act Article 5 and Article 50, and more), with the article citation when a rule fires. It checks *this* prompt or output; it does not classify your system.

Each line is an alternative; pick the one you need.

```bash
npx -y @complyedge/mcp                               # this MCP server (Node)
claude mcp add complyedge -- npx -y @complyedge/mcp  # add it to Claude Code
pip install 'complyedge[mcp]'                        # the same tools as a Python MCP server: complyedge-mcp
pip install complyedge                               # Python SDK for hosted checks, no MCP server
pip install trustlint                                # offline linter CLI, no MCP server
```

Run offline TrustLint checks from any MCP host with Node.js:

```json
{
  "complyedge": {
    "command": "npx",
    "args": ["-y", "@complyedge/mcp"]
  }
}
```

## Tools

The server exposes three read-only tools.

| Tool | Returns | Notes |
|---|---|---|
| `check_compliance` | `PASS` / `FAIL` with cited findings | Checks already-produced text. Optional `jurisdiction` (where the end user is): `EU`, `US`, `GLOBAL`. GLOBAL rules always run |
| `scan_prompt` | `SAFE` / `RISK_DETECTED` | Checks a candidate prompt before it is sent to a model |
| `list_rules` | Rule inventory | Discovery only: does not evaluate text |

### Optional: hosted sandbox with your API key

Set `COMPLYEDGE_API_KEY` in the server's environment and a fourth tool
appears. Without it the tool is not listed and the server stays fully offline.

| Tool | Returns | Notes |
|---|---|---|
| `sandbox_check` | `BLOCKED` or `ALLOWED`. A phrase-rule block carries the rule ID and the article. An injection block names the law. A wider-review block does not cite an article. An allowed check can list rules the wider review cleared, and that review runs only when you turn it on and the month's model budget covers it | Hosted enforcement in sandbox mode (`POST /v1/sandbox/check`): your tenant's real rules and settings, the same verdict as production, and nothing recorded: no audit entry, no usage, and no count against your plan's daily limit (sandbox calls have their own caps: 60 a minute, 1,000 a day). One network call per check. Never evidence. An EU account's key is `ce_eu_` and calls `eu.api.complyedge.io`; a US account's key is `ce_` and calls `api.complyedge.io`. The region is your account's, chosen when you sign up and create your first API key. `COMPLYEDGE_API_URL` picks a host and does not change the account's region. To change the region later, use Request a region change in the dashboard. |

Rotating the key: mint the new one with **Rotate key** on the dashboard's API
Key page (it asks first), update
`COMPLYEDGE_API_KEY` (or the `Authorization: Bearer` header on the hosted
server) and restart the client, then click **Revoke previous key** in the
reveal. Both keys work until you revoke, so nothing has to go dark in between.

## Limitations and honest scope

- Tier-1 regex matching over a bundled YAML rule set. It does not evaluate
  Rego, and it is not the hosted check path. Use
  [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk) for
  `POST /v1/check` and the audit record (timestamp, keyed text hash, `event_id`,
  and the rule and the law named when a phrase rule or the injection check fired. A wider-review block does not cite an article; see
  https://complyedge.io/docs/audit-reconciliation.html).
- Findings are rule matches, not legal advice, not a legal
  opinion, and not a regulatory classification of an AI system.
- The corpus is bundled at build time. It is current as of the release you
  install, not a live regulatory feed.
- Read-only and local. No tool writes, sends, or persists anything; the three
  offline tools make no network calls and need no API key. `sandbox_check` is
  the one exception, exists only when you set `COMPLYEDGE_API_KEY`, and the
  hosted sandbox it calls records nothing.

## Links

- [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk): hosted checks and the audit record (timestamp, keyed text hash, `event_id`, and the rule and the law named when a phrase rule or the injection check fired. A wider-review block does not cite an article)
- [`trustlint`](https://www.npmjs.com/package/trustlint): the same offline engine as a CLI
- [`complyedge` on PyPI](https://pypi.org/project/complyedge/): Python MCP server, published under this same registry entry
- GitHub Action: `uses: complyedge/trustlint-action@v1`
- [`trustlint` on PyPI](https://pypi.org/project/trustlint/): Python linter
- [Documentation](https://complyedge.io/docs) · [Trust portal](https://trust.complyedge.io)

<!-- mcp-name: io.github.ComplyEdge/complyedge -->
