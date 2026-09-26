# @complyedge/mcp

[![npm version](https://img.shields.io/npm/v/@complyedge/mcp)](https://www.npmjs.com/package/@complyedge/mcp)
[![npm downloads](https://img.shields.io/npm/dw/@complyedge/mcp)](https://www.npmjs.com/package/@complyedge/mcp)
[![license](https://img.shields.io/npm/l/@complyedge/mcp)](https://github.com/ComplyEdge/complyedge/blob/main/LICENSE)

EU AI Act Article 5 and Article 50 runtime deny via TrustLint, offline. Classifiers (`eu-ai-act-*`) score the *system*; this server denies *this* prompt or output. Article 50 here is unlabeled or deceptive use, not C2PA.

```bash
npx -y @complyedge/mcp
pip install 'complyedge[mcp]'
pip install complyedge
pip install trustlint
claude mcp add complyedge -- npx -y @complyedge/mcp
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
| `check_compliance` | `PASS` / `FAIL` with cited findings | Checks already-produced text. Optional `jurisdiction`: `EU`, `US`, `GLOBAL` |
| `scan_prompt` | `SAFE` / `RISK_DETECTED` | Checks a candidate prompt before it is sent to a model |
| `list_rules` | Rule inventory | Discovery only — does not evaluate text |

### Optional: hosted sandbox with your API key

Set `COMPLYEDGE_API_KEY` in the server's environment and a fourth tool
appears. Without it the tool is not listed and the server stays fully offline.

| Tool | Returns | Notes |
|---|---|---|
| `sandbox_check` | `BLOCKED` / `ALLOWED` with rule ID and article citation | Hosted enforcement in sandbox mode (`POST /v1/sandbox/check`): your tenant's real rules and settings, the same verdict as production, and nothing recorded: no audit entry, no usage, no rate-limit count. One network call per check. Never evidence. A new account is EU (`ce_eu_` calls `eu.api.complyedge.io`). A US account uses `ce_` and `api.complyedge.io`. `COMPLYEDGE_API_URL` picks a host and does not move the account. Email support@complyedge.io to change region. |

Rotating the key: mint the new one with **Rotate key** on the dashboard's API
Key page (it asks first), update
`COMPLYEDGE_API_KEY` (or the `Authorization: Bearer` header on the hosted
server) and restart the client, then click **Revoke previous key** in the
reveal. Both keys work until you revoke, so nothing has to go dark in between.

## Limitations and honest scope

- Tier-1 regex matching over a bundled YAML corpus. It does not evaluate
  Rego, and it is not the hosted runtime enforcement path — use
  [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk) for
  `POST /v1/check` and the Article 12 audit trail.
- Findings are technical compliance evidence, not legal advice, not a legal
  opinion, and not a regulatory classification of an AI system.
- The corpus is bundled at build time. It is current as of the release you
  install, not a live regulatory feed.
- Read-only and local. No tool writes, sends, or persists anything; the three
  offline tools make no network calls and need no API key. `sandbox_check` is
  the one exception, exists only when you set `COMPLYEDGE_API_KEY`, and the
  hosted sandbox it calls records nothing.

## Links

- [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk) — hosted runtime enforcement and the Article 12 audit trail
- [`trustlint`](https://www.npmjs.com/package/trustlint) — the same offline engine as a CLI
- [`complyedge` on PyPI](https://pypi.org/project/complyedge/) — Python MCP server, published under this same registry entry
- GitHub Action: `uses: complyedge/trustlint-action@v1`
- GOPAL is an OPA library in your process. ComplyEdge is per-request deny + citation + AI Trust Center + MCP.
- [`trustlint` on PyPI](https://pypi.org/project/trustlint/) — Python linter
- [Documentation](https://www.complyedge.io/docs) · [Trust portal](https://trust.complyedge.io)

<!-- mcp-name: io.github.ComplyEdge/complyedge -->
