"""SDK endpoint parity — primary check() must POST /v1/check.

Catches the PUB-001 class of defect: an SDK silently targeting a legacy
endpoint while docs teach the new one. Asserts the request path the client
actually issues (mocked httpx/axios), not a source-string grep.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from complyedge import ComplyEdge


def _mock_response(payload: dict | None = None) -> MagicMock:
    body = payload or {
        "event_id": "evt-parity",
        "allowed": True,
        "violations": [],
        "latency_ms": 10,
        "bundle_version": "opa-rego-v1",
        "evaluated_rules": [],
        "engine_path": "opa",
        "audit_logged": True,
    }
    resp = MagicMock()
    resp.raise_for_status = MagicMock()
    resp.json = MagicMock(return_value=body)
    return resp


@patch("httpx.Client.post")
def test_python_check_posts_v1_check_path(mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response()
    ce = ComplyEdge(api_key="test-key", base_url="https://example.test")
    ce.check("hello")
    assert mock_post.call_args.args[0] == "/v1/check"


@patch("httpx.Client.post")
def test_python_check_does_not_post_legacy_sensitivity_path(
    mock_post: MagicMock,
) -> None:
    mock_post.return_value = _mock_response()
    ce = ComplyEdge(api_key="test-key", base_url="https://example.test")
    ce.check("hello")
    path = mock_post.call_args.args[0]
    assert path != "/v1/sensitivity/detect"
    assert "/sensitivity/" not in path


# ---------------------------------------------------------------------------
# sandbox=True → /v1/sandbox/check (same body, nothing recorded server-side)
# ---------------------------------------------------------------------------
def _sandbox_response() -> MagicMock:
    return _mock_response(
        {
            "event_id": "evt-sandbox",
            "allowed": False,
            "violations": [
                {
                    "rule_id": "rego-art5-1c-001",
                    "rule_description": "Regulation (EU) 2024/1689, Article 5(1)(c): ...",
                    "severity": "critical",
                    "confidence": 1.0,
                }
            ],
            "latency_ms": 7,
            "bundle_version": "opa-rego-v1",
            "evaluated_rules": ["rego-art5-1c-001"],
            "engine_path": "opa",
            "audit_logged": False,
            "sandbox": True,
        }
    )


@patch("httpx.Client.post")
def test_python_simple_check_sandbox_posts_sandbox_path(mock_post: MagicMock) -> None:
    mock_post.return_value = _sandbox_response()
    ce = ComplyEdge(api_key="test-key", base_url="https://example.test")
    result = ce.check("Score users by social behaviour", sandbox=True)
    assert mock_post.call_args.args[0] == "/v1/sandbox/check"
    # Same request body shape as /v1/check.
    body = mock_post.call_args.kwargs["json"]
    assert body["text"] == "Score users by social behaviour"
    assert body["jurisdiction"] == "EU"
    assert result.blocked
    assert result.sandbox is True
    assert result.audit_logged is False


@patch("httpx.Client.post")
def test_python_simple_check_default_is_not_sandbox(mock_post: MagicMock) -> None:
    mock_post.return_value = _mock_response()
    ce = ComplyEdge(api_key="test-key", base_url="https://example.test")
    result = ce.check("hello")
    assert mock_post.call_args.args[0] == "/v1/check"
    assert result.sandbox is False


@patch("httpx.Client.post")
def test_python_full_client_sandbox_posts_sandbox_path(mock_post: MagicMock) -> None:
    from complyedge import ComplyEdgeClient

    mock_post.return_value = _sandbox_response()
    with ComplyEdgeClient(api_key="test-key", base_url="https://example.test") as c:
        result = c.check_compliance("x", agent_id="a", sandbox=True)
    assert mock_post.call_args.args[0] == "/v1/sandbox/check"
    assert result.sandbox is True


@patch("httpx.AsyncClient.post")
def test_python_async_client_sandbox_posts_sandbox_path(mock_post: MagicMock) -> None:
    import asyncio

    from complyedge import AsyncComplyEdgeClient

    async def _run():
        mock_post.return_value = _sandbox_response()
        client = AsyncComplyEdgeClient(
            api_key="test-key", base_url="https://example.test"
        )
        try:
            return await client.check_compliance("x", agent_id="a", sandbox=True)
        finally:
            await client.close()

    result = asyncio.run(_run())
    assert mock_post.call_args.args[0] == "/v1/sandbox/check"
    assert result.sandbox is True


@patch("httpx.Client.post")
def test_python_module_check_forwards_sandbox(mock_post: MagicMock) -> None:
    from complyedge import check

    mock_post.return_value = _sandbox_response()
    result = check(
        "x", api_key="test-key", base_url="https://example.test", sandbox=True
    )
    assert mock_post.call_args.args[0] == "/v1/sandbox/check"
    assert result.sandbox is True
