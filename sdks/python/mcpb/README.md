# ComplyEdge TrustLint MCP server, local stdio

This folder holds the entry point of the TrustLint MCP server packaged as an
MCP Bundle (`.mcpb`) for desktop clients. The server runs on your machine over
stdio. Run it with [uv](https://docs.astral.sh/uv/):

```bash
uvx --from 'complyedge[mcp]==0.2.22' -- python -m complyedge.mcp_server
```

## Tools

- `check_compliance`, `list_rules` and `scan_prompt` run offline against the
  bundled TrustLint rules. No API key, and nothing leaves your machine.
- `sandbox_check` is listed only when `COMPLYEDGE_API_KEY` is set in the
  server's environment. It sends the text to the hosted ComplyEdge API in
  sandbox mode: the decision comes back and nothing is recorded.

## Client config

Claude Desktop, Cursor and other clients that launch a stdio server:

```json
{
  "mcpServers": {
    "complyedge": {
      "command": "uvx",
      "args": ["--from", "complyedge[mcp]==0.2.22", "--", "python", "-m", "complyedge.mcp_server"],
      "env": { "COMPLYEDGE_API_KEY": "ce_..." }
    }
  }
}
```

Leave out `env` to stay fully offline.

The server is launched with `python -m complyedge.mcp_server` rather than the
`complyedge-mcp` console script because some hosts lack `realpath`, which the
generated wrapper needs under uvx.

## Hosted instead

`https://mcp.complyedge.io/mcp` serves the same tools over Streamable HTTP,
hosted by ComplyEdge. `sandbox_check` is always listed there and works only
when the client sends `Authorization: Bearer <API key>` on the connection; the
three offline tools need no key.

The server is listed in the Official MCP Registry as
`io.github.ComplyEdge/complyedge`.
