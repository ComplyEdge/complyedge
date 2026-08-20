# ComplyEdge TrustLint — MCPB stdio bundle

Install-true MCP Bundle (`.mcpb`) for **local stdio** desktop / directory clients.

- **Runtime (local only):** `uvx --from 'complyedge[mcp]==0.2.10' -- python -m complyedge.mcp_server`
- **Tools:** `check_compliance`, `list_rules`, `scan_prompt` (manifest includes MCP `inputSchema` so directory registries that require full Tool shape accept the bundle; schemas match `complyedge.mcp_server`)
- **Config:** none required on day one
- **Official Registry twin:** `io.github.ComplyEdge/complyedge` @ 0.2.10
- **Pack:** `./pack.sh` uses zip (not `mcpb pack`) so Tool-shaped tools can ship
- **Hosted (Smithery Toolbox / Add to toolbox):** `https://mcp.complyedge.io/mcp` — Streamable HTTP on CE AWS (PM-01). Prefer this for one-click Install.
- **Local MCPB (this bundle):** `uvx … python -m complyedge.mcp_server` for offline / Claude Desktop double-click. Secondary to hosted.
- **Cursor:** Prefer Smithery Install → hosted URL, or stdio `command`/`args` with uvx as above.
- **Claude Desktop:** MCPB stdio **or** hosted URL via Smithery Install.
- **Why not `complyedge-mcp` console script under uvx:** some hosts lack `realpath` and break the generated wrapper; `-m complyedge.mcp_server` is the durable launch.

## Pack

```bash
cd sdks/python/mcpb
./pack.sh
# writes ../dist/complyedge-trustlint-0.2.10.mcpb
```

## Smoke

```bash
# requires uv/uvx on PATH (https://docs.astral.sh/uv/)
uvx --from 'complyedge[mcp]==0.2.10' -- python -m complyedge.mcp_server
```
