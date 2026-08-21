# @complyedge/mcp

[![npm version](https://img.shields.io/npm/v/@complyedge/mcp)](https://www.npmjs.com/package/@complyedge/mcp)
[![npm downloads](https://img.shields.io/npm/dw/@complyedge/mcp)](https://www.npmjs.com/package/@complyedge/mcp)
[![license](https://img.shields.io/npm/l/@complyedge/mcp)](https://github.com/ComplyEdge/complyedge/blob/main/LICENSE)

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

## Limitations and honest scope

- Tier-1 regex matching over a bundled YAML corpus. It does not evaluate
  Rego, and it is not the hosted runtime enforcement path — use
  [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk) for
  `POST /v1/check` and the Article 12 audit trail.
- Findings are technical compliance evidence, not legal advice, not a legal
  opinion, and not a regulatory classification of an AI system.
- The corpus is bundled at build time. It is current as of the release you
  install, not a live regulatory feed.
- Read-only and local. No tool writes, sends, or persists anything, and the
  server makes no network calls and needs no API key.

## Links

- [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk) — hosted runtime enforcement and the Article 12 audit trail
- [`trustlint`](https://www.npmjs.com/package/trustlint) — the same offline engine as a CLI
- [`complyedge` on PyPI](https://pypi.org/project/complyedge/) — Python MCP server, published under this same registry entry
- [`trustlint` on PyPI](https://pypi.org/project/trustlint/) — Python linter
- [Documentation](https://www.complyedge.io/docs) · [Trust portal](https://trust.complyedge.io)

<!-- mcp-name: io.github.ComplyEdge/complyedge -->
