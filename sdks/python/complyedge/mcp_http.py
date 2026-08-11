"""ComplyEdge TrustLint MCP — Streamable HTTP (stateless) for hosted deploy.

Used by the CE AWS Lambda (``complyedge-mcp-trustlint``) and local ASGI smoke.
Same three tools as ``mcp_server`` (stdio). TrustLint offline only — not OPA.
"""

from __future__ import annotations

import json
import logging
import os
import time
from collections import defaultdict, deque
from typing import Any, Callable, Literal

from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from complyedge.mcp_server import (
    TOOL_ANNOTATIONS,
    TOOL_DESCRIPTIONS,
    TOOL_NAMES,
    _check_compliance,
    _get_engine,
    _list_rules,
    _scan_prompt,
)

logger = logging.getLogger("complyedge.mcp.http")

Jurisdiction = Literal["EU", "US", "GLOBAL"]

# Per-container soft rate limit (API Gateway throttle + WAF are primary).
_rate_buckets: dict[str, deque[float]] = defaultdict(deque)


def _client_ip(request: Request) -> str:
    forwarded = (request.headers.get("x-forwarded-for") or "").split(",")[0].strip()
    if forwarded:
        return forwarded
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def _rate_limit_per_minute() -> int:
    raw = os.environ.get("MCP_RATE_LIMIT_PER_MINUTE", "120").strip()
    try:
        return max(0, int(raw))
    except ValueError:
        return 120


class _PerIpRateLimitMiddleware(BaseHTTPMiddleware):
    """In-process sliding window per IP — soft cap on one Lambda instance."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        limit = _rate_limit_per_minute()
        path = request.url.path or ""
        if limit <= 0 or path.rstrip("/").endswith("/health"):
            return await call_next(request)

        ip = _client_ip(request)
        now = time.monotonic()
        window = 60.0
        bucket = _rate_buckets[ip]
        while bucket and now - bucket[0] > window:
            bucket.popleft()
        if len(bucket) >= limit:
            logger.warning("mcp_rate_limit_exceeded ip=%s path=%s", ip, path)
            return JSONResponse(
                {
                    "error": "rate_limit_exceeded",
                    "message": "Too many requests; retry later",
                    "retry_after_seconds": 60,
                },
                status_code=429,
                headers={"Retry-After": "60"},
            )
        bucket.append(now)
        return await call_next(request)


def _reset_rate_limit_state_for_tests() -> None:
    """Clear in-process buckets (unit tests only)."""
    _rate_buckets.clear()


def _allowed_hosts() -> list[str]:
    """Host headers accepted behind mcp.complyedge.io (and local smoke)."""
    raw = os.environ.get("MCP_ALLOWED_HOSTS", "").strip()
    if raw:
        return [h.strip() for h in raw.split(",") if h.strip()]
    domain = os.environ.get("DOMAIN", "complyedge.io").strip() or "complyedge.io"
    return [
        f"mcp.{domain}",
        f"mcp.{domain}:*",
        "localhost",
        "localhost:*",
        "127.0.0.1",
        "127.0.0.1:*",
    ]


def _allowed_origins() -> list[str]:
    raw = os.environ.get("MCP_ALLOWED_ORIGINS", "").strip()
    if raw:
        return [h.strip() for h in raw.split(",") if h.strip()]
    return [
        "https://smithery.ai",
        "https://www.smithery.ai",
        "https://claude.ai",
        "https://cursor.com",
        "https://www.complyedge.io",
        "https://complyedge.io",
    ]


def _transport_security() -> TransportSecuritySettings:
    # Public discovery MCP: Host allowlist on; Origin absent is OK (MCP clients).
    if os.environ.get("MCP_DNS_REBINDING", "1").strip() in ("0", "false", "False"):
        return TransportSecuritySettings(enable_dns_rebinding_protection=False)
    return TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=_allowed_hosts(),
        allowed_origins=_allowed_origins(),
    )


def _payload_from_tool_result(result: Any) -> dict[str, Any]:
    """Unwrap CallToolResult → plain dict for FastMCP structured return."""
    sc = getattr(result, "structuredContent", None)
    if isinstance(sc, dict):
        return sc
    content = getattr(result, "content", None) or []
    for block in content:
        if getattr(block, "type", None) == "text" and getattr(block, "text", None):
            return json.loads(block.text)
    raise RuntimeError("Tool result missing structuredContent/text JSON")


def create_mcp() -> FastMCP:
    """Build FastMCP app: stateless Streamable HTTP + /health."""
    mcp = FastMCP(
        "complyedge",
        instructions=(
            "ComplyEdge TrustLint — offline compliance check tools. "
            "Use check_compliance, list_rules, or scan_prompt. No API key required."
        ),
        website_url="https://www.complyedge.io",
        streamable_http_path="/mcp",
        stateless_http=True,
        json_response=True,
        transport_security=_transport_security(),
    )

    @mcp.tool(
        name="check_compliance",
        description=TOOL_DESCRIPTIONS["check_compliance"],
        annotations=TOOL_ANNOTATIONS,
    )
    async def check_compliance(
        text: str,
        jurisdiction: Jurisdiction | None = None,
    ) -> dict[str, Any]:
        args: dict[str, Any] = {"text": text}
        if jurisdiction is not None:
            args["jurisdiction"] = jurisdiction
        return _payload_from_tool_result(
            await _check_compliance(_get_engine(), args)
        )

    @mcp.tool(
        name="list_rules",
        description=TOOL_DESCRIPTIONS["list_rules"],
        annotations=TOOL_ANNOTATIONS,
    )
    async def list_rules(
        jurisdiction: Jurisdiction | None = None,
    ) -> dict[str, Any]:
        args: dict[str, Any] = {}
        if jurisdiction is not None:
            args["jurisdiction"] = jurisdiction
        return _payload_from_tool_result(await _list_rules(_get_engine(), args))

    @mcp.tool(
        name="scan_prompt",
        description=TOOL_DESCRIPTIONS["scan_prompt"],
        annotations=TOOL_ANNOTATIONS,
    )
    async def scan_prompt(prompt: str) -> dict[str, Any]:
        return _payload_from_tool_result(
            await _scan_prompt(_get_engine(), {"prompt": prompt})
        )

    @mcp.custom_route("/health", methods=["GET"])
    async def health(_request: Request) -> Response:
        return JSONResponse(
            {
                "status": "healthy",
                "server": "complyedge-mcp-trustlint",
                "transport": "streamable-http",
                "stateless": True,
                "tools": list(TOOL_NAMES),
            }
        )

    # Silence unused-name lint for TOOL_NAMES order documentation
    assert TOOL_NAMES == ("check_compliance", "list_rules", "scan_prompt")
    return mcp


def create_asgi_app():
    """ASGI app for Mangum / uvicorn (/mcp + /health + soft per-IP rate limit)."""
    app = create_mcp().streamable_http_app()
    app.add_middleware(_PerIpRateLimitMiddleware)
    return app
