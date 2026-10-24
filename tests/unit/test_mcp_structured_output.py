"""Regression: outputSchema tools must return structuredContent (Smithery / MCP SDK).

When tools declare outputSchema but return only TextContent JSON, the MCP
low-level Server responds with:
  Output validation error: outputSchema defined but no structured output returned
Hosts (Smithery Toolbox) then show Idle / No tools available or failed calls.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from mcp.types import (
    CallToolRequest,
    CallToolRequestParams,
    CallToolResult,
    ListToolsRequest,
    ServerResult,
)

ROOT = Path(__file__).resolve().parents[2]
SDK_ROOT = ROOT / "sdks" / "python"
sys.path.insert(0, str(SDK_ROOT))

from complyedge import mcp_server  # noqa: E402


@pytest.mark.asyncio
async def test_call_tool_returns_call_tool_result_with_structured():
    """Handlers must return CallToolResult with structuredContent when outputSchema is set."""
    result = await mcp_server.call_tool(
        "check_compliance", {"text": "Hello world, this is fine."}
    )
    assert isinstance(result, CallToolResult)
    assert result.structuredContent is not None
    assert result.structuredContent["status"] == "PASS"
    assert result.content and result.content[0].type == "text"


@pytest.mark.asyncio
async def test_server_tools_call_emits_structured_content_not_schema_error():
    """Exercise the Server wrapper path that validates structuredContent."""
    list_handler = mcp_server.server.request_handlers[ListToolsRequest]
    await list_handler(ListToolsRequest(method="tools/list"))

    handler = mcp_server.server.request_handlers[CallToolRequest]
    req = CallToolRequest(
        method="tools/call",
        params=CallToolRequestParams(
            name="check_compliance",
            arguments={"text": "Hello world, this is fine."},
        ),
    )
    result = await handler(req)
    assert isinstance(result, ServerResult)
    root = result.root
    assert isinstance(root, CallToolResult)
    assert root.isError is not True
    assert root.structuredContent is not None
    assert root.structuredContent["status"] == "PASS"
    text = root.content[0].text if root.content else ""
    assert "outputSchema defined but no structured output" not in text
