"""MCP `sandbox_check`: optional, key-gated, hosted, never recorded.

Leo, 2026-09-20: add the sandbox to the MCP as optional with the key. The
three offline tools keep their no-network / no-key contract; a fourth tool
appears only when COMPLYEDGE_API_KEY is set and calls POST /v1/sandbox/check
through the SDK client.
"""

from __future__ import annotations

import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sdks" / "python"))

import complyedge  # noqa: E402
from complyedge.mcp_server import (  # noqa: E402
    API_KEY_ENV,
    SANDBOX_TOOL_DESCRIPTION,
    SANDBOX_TOOL_NAME,
    TOOL_DESCRIPTIONS,
    TOOL_NAMES,
    call_tool,
    list_tools,
)


def _result(*, sandbox: bool, blocked: bool = True):
    violation = SimpleNamespace(
        rule_id="rego-art5-1c-001",
        rule_description="Regulation (EU) 2024/1689, Article 5(1)(c): ...",
        severity=complyedge.SeverityLevel.CRITICAL,
        reason="Remove social scoring",
    )
    return SimpleNamespace(
        blocked=blocked,
        violations=[violation] if blocked else [],
        engine_path="opa",
        latency_ms=7,
        audit_logged=False,
        sandbox=sandbox,
    )


@pytest.mark.asyncio
async def test_without_key_the_tool_does_not_exist(monkeypatch):
    monkeypatch.delenv(API_KEY_ENV, raising=False)
    tools = await list_tools()
    assert [t.name for t in tools] == list(TOOL_NAMES)
    with pytest.raises(ValueError, match="Unknown tool"):
        await call_tool(SANDBOX_TOOL_NAME, {"text": "x"})


@pytest.mark.asyncio
async def test_with_key_the_tool_is_listed_last_and_says_what_it_is(monkeypatch):
    monkeypatch.setenv(API_KEY_ENV, "ce_test_key")
    tools = await list_tools()
    assert [t.name for t in tools] == [*TOOL_NAMES, SANDBOX_TOOL_NAME]
    sandbox = tools[-1]
    assert sandbox.description == SANDBOX_TOOL_DESCRIPTION
    for needle in ("EU AI Act", "Article 5", "Article 50", "COMPLYEDGE_API_KEY"):
        assert needle in sandbox.description
    assert "NOTHING is recorded" in sandbox.description
    assert "never evidence" in sandbox.description
    assert "/v1/sandbox/check" in sandbox.description
    # The offline trio's descriptions are untouched by the fourth tool.
    assert SANDBOX_TOOL_NAME not in TOOL_DESCRIPTIONS
    assert sandbox.outputSchema["properties"]["audit_logged"]["const"] is False
    assert sandbox.outputSchema["properties"]["sandbox"]["const"] is True


@pytest.mark.asyncio
async def test_call_goes_through_sdk_sandbox_and_reports_not_recorded(monkeypatch):
    monkeypatch.setenv(API_KEY_ENV, "ce_eu_test_key")
    client = MagicMock()
    client.check.return_value = _result(sandbox=True)
    with patch.object(complyedge, "ComplyEdge", return_value=client) as ctor:
        result = await call_tool(
            SANDBOX_TOOL_NAME,
            {"text": "Score users by social behaviour", "jurisdiction": "EU"},
        )
    ctor.assert_called_once_with(api_key="ce_eu_test_key", agent_id="mcp-sandbox")
    client.check.assert_called_once_with(
        "Score users by social behaviour", jurisdiction="EU", sandbox=True
    )
    client.close.assert_called_once()
    payload = result.structuredContent
    assert payload["status"] == "BLOCKED"
    assert payload["audit_logged"] is False
    assert payload["sandbox"] is True
    assert payload["violations"][0]["rule_id"] == "rego-art5-1c-001"
    assert "Article 5(1)(c)" in payload["violations"][0]["citation"]
    assert payload["engine_path"] == "opa"
    assert "not recorded" in payload["message"]


@pytest.mark.asyncio
async def test_allowed_verdict(monkeypatch):
    monkeypatch.setenv(API_KEY_ENV, "ce_test_key")
    client = MagicMock()
    client.check.return_value = _result(sandbox=True, blocked=False)
    with patch.object(complyedge, "ComplyEdge", return_value=client):
        result = await call_tool(SANDBOX_TOOL_NAME, {"text": "The weather is mild."})
    assert result.structuredContent["status"] == "ALLOWED"
    assert result.structuredContent["violations"] == []


@pytest.mark.asyncio
async def test_refuses_to_report_when_server_did_not_confirm_sandbox(monkeypatch):
    # A recorded /v1/check response wearing the sandbox tool's name would be
    # the one lie this tool must never tell.
    monkeypatch.setenv(API_KEY_ENV, "ce_test_key")
    client = MagicMock()
    client.check.return_value = _result(sandbox=False)
    with patch.object(complyedge, "ComplyEdge", return_value=client):
        with pytest.raises(RuntimeError, match="did not confirm sandbox"):
            await call_tool(SANDBOX_TOOL_NAME, {"text": "x"})


@pytest.mark.asyncio
async def test_empty_text_rejected_before_any_network_call(monkeypatch):
    monkeypatch.setenv(API_KEY_ENV, "ce_test_key")
    with patch.object(complyedge, "ComplyEdge") as ctor:
        with pytest.raises(ValueError, match="Missing or empty"):
            await call_tool(SANDBOX_TOOL_NAME, {"text": "   "})
    ctor.assert_not_called()
