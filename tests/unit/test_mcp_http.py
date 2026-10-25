"""Hosted Streamable HTTP MCP — TrustLint tools + ASGI surface."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from complyedge.mcp_http import (
    _DEFAULT_RATE_LIMIT_PER_MINUTE,
    HOSTED_SANDBOX_DESCRIPTION,
    TOOL_NAMES,
    _client_ip,
    _rate_limit_per_minute,
    _reset_rate_limit_state_for_tests,
    create_asgi_app,
    create_mcp,
)
from complyedge.mcp_server import SANDBOX_TOOL_NAME, TOOL_DESCRIPTIONS
from starlette.testclient import TestClient

# Hosted surface: the offline trio plus sandbox_check, which is always listed
# and works only for a caller that sends its own API key on the request.
HOSTED_TOOL_NAMES = [*TOOL_NAMES, SANDBOX_TOOL_NAME]


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "test")
    _reset_rate_limit_state_for_tests()
    app = create_asgi_app()
    with TestClient(app) as c:
        yield c


def test_health(client: TestClient) -> None:
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "healthy"
    assert body["tools"] == list(TOOL_NAMES)
    assert body["optional_tools"] == [SANDBOX_TOOL_NAME]
    assert body["stateless"] is True
    assert body["rules_loaded"] > 0


def test_get_mcp_returns_405_without_hang(client: TestClient) -> None:
    r = client.get("/mcp", headers={"Accept": "text/event-stream"})
    assert r.status_code == 405
    assert r.headers.get("allow") == "POST"
    assert r.content == b""


def test_get_mcp_bare_returns_405(client: TestClient) -> None:
    r = client.get("/mcp")
    assert r.status_code == 405
    assert r.headers.get("allow") == "POST"


def test_health_empty_corpus_is_unhealthy(monkeypatch: pytest.MonkeyPatch) -> None:
    from types import SimpleNamespace

    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setattr(
        "complyedge.mcp_http._get_engine",
        lambda: SimpleNamespace(rules=[]),
    )
    _reset_rate_limit_state_for_tests()
    app = create_asgi_app()
    with TestClient(app) as c:
        r = c.get("/health")
    assert r.status_code == 503
    body = r.json()
    assert body["status"] == "unhealthy"
    assert body["rules_loaded"] == 0


def test_health_payload_engine_error_is_unhealthy(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from complyedge.mcp_http import _health_payload

    monkeypatch.setattr(
        "complyedge.mcp_http._get_engine",
        lambda: (_ for _ in ()).throw(RuntimeError("no engine")),
    )
    body, code = _health_payload()
    assert code == 503
    assert body["status"] == "unhealthy"
    assert body["rules_loaded"] == 0


def test_http_mcp_tool_descriptions_match_stdio_source() -> None:
    """stdio and HTTP MCP must share TOOL_DESCRIPTIONS (GE-5 / no drift)."""
    import asyncio

    mcp = create_mcp()
    tools = asyncio.run(mcp.list_tools())
    for tool in tools:
        expected = (
            HOSTED_SANDBOX_DESCRIPTION
            if tool.name == SANDBOX_TOOL_NAME
            else TOOL_DESCRIPTIONS[tool.name]
        )
        assert tool.description == expected, tool.name
        assert "EU AI Act" in tool.description
        assert "Article 5" in tool.description
        assert "Article 50" in tool.description


def test_mcp_initialize_and_tools_list(client: TestClient) -> None:
    """Stateless Streamable HTTP: initialize + tools/list on /mcp."""
    init = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "ce-test", "version": "0.0.1"},
        },
    }
    r = client.post(
        "/mcp",
        json=init,
        headers={
            "Accept": "application/json, text/event-stream",
            "Content-Type": "application/json",
        },
    )
    assert r.status_code == 200, r.text
    # tools/list
    listed = client.post(
        "/mcp",
        json={"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        headers={
            "Accept": "application/json, text/event-stream",
            "Content-Type": "application/json",
        },
    )
    assert listed.status_code == 200, listed.text
    data = listed.json()
    # JSON response mode may nest result
    result = data.get("result") or data
    tools = result.get("tools") or []
    names = [t["name"] for t in tools]
    assert names == HOSTED_TOOL_NAMES


def test_check_compliance_tool_via_fastmcp() -> None:
    """Direct FastMCP tool call (no HTTP) — TrustLint FAIL on biometric."""
    import asyncio

    mcp = create_mcp()
    # Resolve registered tool
    tools = asyncio.run(mcp.list_tools())
    assert [t.name for t in tools] == HOSTED_TOOL_NAMES


def test_per_ip_rate_limit_returns_429(monkeypatch: pytest.MonkeyPatch) -> None:
    """Soft in-process limit returns 429 with Retry-After (edge WAF/APIGW primary)."""
    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "3")
    _reset_rate_limit_state_for_tests()
    app = create_asgi_app()
    with TestClient(app) as c:
        assert c.get("/health").status_code == 200
        for _ in range(3):
            assert c.get("/health").status_code == 200
        # Health is exempt — probe /mcp instead
        headers = {
            "Accept": "application/json, text/event-stream",
            "Content-Type": "application/json",
            "X-Forwarded-For": "203.0.113.50",
        }
        body = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "rl-test", "version": "0"},
            },
        }
        codes = [
            c.post("/mcp", json=body, headers=headers).status_code for _ in range(4)
        ]
        assert 429 in codes
        last = c.post("/mcp", json=body, headers=headers)
        if last.status_code == 429:
            assert last.headers.get("retry-after") == "60"
            assert last.json()["error"] == "rate_limit_exceeded"


def test_client_ip_uses_rightmost_forwarded_hop():
    """Leftmost X-Forwarded-For is attacker-controlled; APIGW appends last."""

    class _Req:
        def __init__(self, xff: str | None, host: str | None = "127.0.0.1"):
            self.headers = {"x-forwarded-for": xff} if xff else {}
            self.client = type("C", (), {"host": host})() if host else None

    assert _client_ip(_Req("203.0.113.1, 198.51.100.10")) == "198.51.100.10"
    assert _client_ip(_Req("198.51.100.10")) == "198.51.100.10"


def test_spoofed_left_xff_cannot_bypass_rate_limit(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "3")
    _reset_rate_limit_state_for_tests()
    app = create_asgi_app()
    body = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "xff-spoof", "version": "0"},
        },
    }
    with TestClient(app) as c:
        codes = []
        for i in range(4):
            headers = {
                "Accept": "application/json, text/event-stream",
                "Content-Type": "application/json",
                "X-Forwarded-For": f"203.0.113.{i}, 198.51.100.99",
            }
            codes.append(c.post("/mcp", json=body, headers=headers).status_code)
        assert 429 in codes, f"rotating spoofed left hop bypassed the cap: {codes}"


def test_rate_limit_zero_is_default_not_unlimited(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "0")
    assert _rate_limit_per_minute() == _DEFAULT_RATE_LIMIT_PER_MINUTE


def test_rate_limit_negative_is_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "-5")
    assert _rate_limit_per_minute() == _DEFAULT_RATE_LIMIT_PER_MINUTE


def test_rate_limit_garbage_is_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "unlimited")
    assert _rate_limit_per_minute() == _DEFAULT_RATE_LIMIT_PER_MINUTE


def test_rate_limit_positive_is_honored(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "3")
    assert _rate_limit_per_minute() == 3


def test_rate_limit_zero_still_429s_on_mcp(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """0 used to skip the middleware (unlimited). It must still cap."""
    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("MCP_RATE_LIMIT_PER_MINUTE", "0")
    monkeypatch.setattr("complyedge.mcp_http._DEFAULT_RATE_LIMIT_PER_MINUTE", 3)
    _reset_rate_limit_state_for_tests()
    app = create_asgi_app()
    headers = {
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json",
        "X-Forwarded-For": "203.0.113.77",
    }
    body = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "zero-cap", "version": "0"},
        },
    }
    with TestClient(app) as c:
        codes = [
            c.post("/mcp", json=body, headers=headers).status_code for _ in range(4)
        ]
    assert 429 in codes


def test_production_ignores_dns_rebinding_disable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "production")
    from complyedge.mcp_http import _transport_security

    ts = _transport_security()
    assert ts.enable_dns_rebinding_protection is True


def test_development_may_disable_dns_rebinding(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MCP_DNS_REBINDING", "0")
    monkeypatch.setenv("ENVIRONMENT", "development")
    from complyedge.mcp_http import _transport_security

    ts = _transport_security()
    assert ts.enable_dns_rebinding_protection is False


def test_production_default_hosts_exclude_localhost(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.delenv("MCP_ALLOWED_HOSTS", raising=False)
    monkeypatch.delenv("DOMAIN", raising=False)
    from complyedge.mcp_http import _allowed_hosts

    hosts = _allowed_hosts()
    assert "localhost" not in hosts
    assert "127.0.0.1" not in hosts
    assert "mcp.complyedge.io" in hosts


def test_development_default_hosts_include_localhost(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.delenv("MCP_ALLOWED_HOSTS", raising=False)
    from complyedge.mcp_http import _allowed_hosts

    hosts = _allowed_hosts()
    assert "localhost" in hosts
    assert "127.0.0.1" in hosts


# ---------------------------------------------------------------------------
# sandbox_check on the hosted server: the caller's key rides the HTTP request
# ---------------------------------------------------------------------------
_MCP_HEADERS = {
    "Accept": "application/json, text/event-stream",
    "Content-Type": "application/json",
}


def _call_sandbox(
    client: TestClient, headers: dict[str, str], text: str = "Score users"
) -> dict:
    body = {
        "jsonrpc": "2.0",
        "id": 7,
        "method": "tools/call",
        "params": {"name": SANDBOX_TOOL_NAME, "arguments": {"text": text}},
    }
    r = client.post("/mcp", json=body, headers={**_MCP_HEADERS, **headers})
    assert r.status_code == 200, r.text
    data = r.json()
    return data.get("result") or data


def test_hosted_sandbox_description_says_header_not_env() -> None:
    assert "Authorization: Bearer" in HOSTED_SANDBOX_DESCRIPTION
    assert "COMPLYEDGE_API_KEY" not in HOSTED_SANDBOX_DESCRIPTION
    assert "never a tool argument" in HOSTED_SANDBOX_DESCRIPTION
    assert "NOTHING is recorded" in HOSTED_SANDBOX_DESCRIPTION


def test_hosted_sandbox_without_bearer_is_a_tool_error_and_no_network(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    import complyedge

    ctor = MagicMock()
    monkeypatch.setattr(complyedge, "ComplyEdge", ctor)
    result = _call_sandbox(client, {})
    assert result.get("isError") is True
    text = result["content"][0]["text"]
    assert "Authorization: Bearer" in text
    ctor.assert_not_called()


def test_hosted_sandbox_forwards_the_callers_key_and_reports_not_recorded(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    import complyedge

    violation = SimpleNamespace(
        rule_id="rego-art5-1c-001",
        rule_description="Regulation (EU) 2024/1689, Article 5(1)(c): ...",
        severity=complyedge.SeverityLevel.CRITICAL,
        reason="Remove social scoring",
    )
    sdk = MagicMock()
    sdk.check.return_value = SimpleNamespace(
        blocked=True,
        violations=[violation],
        engine_path="opa",
        latency_ms=7,
        audit_logged=False,
        sandbox=True,
    )
    ctor = MagicMock(return_value=sdk)
    monkeypatch.setattr(complyedge, "ComplyEdge", ctor)

    result = _call_sandbox(client, {"Authorization": "Bearer ce_eu_caller_key"})
    assert not result.get("isError"), result
    ctor.assert_called_once_with(api_key="ce_eu_caller_key", agent_id="mcp-sandbox")
    sdk.check.assert_called_once_with("Score users", jurisdiction=None, sandbox=True)
    payload = result.get("structuredContent") or json.loads(
        result["content"][0]["text"]
    )
    assert payload["status"] == "BLOCKED"
    assert payload["audit_logged"] is False
    assert payload["sandbox"] is True
    assert payload["violations"][0]["rule_id"] == "rego-art5-1c-001"


def test_hosted_sandbox_refuses_unconfirmed_sandbox_response(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    import complyedge

    sdk = MagicMock()
    sdk.check.return_value = SimpleNamespace(
        blocked=False,
        violations=[],
        engine_path="opa",
        latency_ms=3,
        audit_logged=True,
        sandbox=False,
    )
    monkeypatch.setattr(complyedge, "ComplyEdge", MagicMock(return_value=sdk))
    result = _call_sandbox(client, {"Authorization": "Bearer ce_key"})
    assert result.get("isError") is True
    assert "did not confirm sandbox" in result["content"][0]["text"]
