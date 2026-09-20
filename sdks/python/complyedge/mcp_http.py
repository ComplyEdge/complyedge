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
from collections.abc import Callable
from typing import Any, Literal

from mcp.server.fastmcp import Context, FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from complyedge.mcp_server import (
    SANDBOX_TOOL_DESCRIPTION,
    SANDBOX_TOOL_NAME,
    TOOL_ANNOTATIONS,
    TOOL_DESCRIPTIONS,
    TOOL_NAMES,
    _check_compliance,
    _get_engine,
    _list_rules,
    _sandbox_check,
    _scan_prompt,
)

logger = logging.getLogger("complyedge.mcp.http")


def _health_payload() -> tuple[dict[str, Any], int]:
    """Hosted MCP readiness. An empty TrustLint corpus is not healthy.

    Tools already refuse PASS/SAFE on zero rules. Health used to report
    healthy anyway, so a load balancer kept sending traffic at a server
    that cannot evaluate.
    """
    try:
        n = len(_get_engine().rules)
    except Exception:
        n = 0
    body: dict[str, Any] = {
        "server": "complyedge-mcp-trustlint",
        "transport": "streamable-http",
        "stateless": True,
        "tools": list(TOOL_NAMES),
        # Always listed; usable only by a caller that sends its own API key
        # as `Authorization: Bearer` on the MCP request.
        "optional_tools": [SANDBOX_TOOL_NAME],
        "rules_loaded": n,
    }
    if n:
        body["status"] = "healthy"
        return body, 200
    body["status"] = "unhealthy"
    body["reason"] = "TrustLint corpus is empty"
    return body, 503


Jurisdiction = Literal["EU", "US", "GLOBAL"]

# Per-container soft rate limit (API Gateway throttle + WAF are primary).
_rate_buckets: dict[str, deque[float]] = defaultdict(deque)


def _client_ip(request: Request) -> str:
    """Client identity for the in-process rate limit.

    Take the *rightmost* X-Forwarded-For hop. API Gateway appends the connecting
    client; the leftmost value is attacker-controlled. Using the first hop
    let a client rotate spoofed IPs and bypass the per-IP cap.
    """
    forwarded = (request.headers.get("x-forwarded-for") or "").strip()
    if forwarded:
        hops = [part.strip() for part in forwarded.split(",") if part.strip()]
        if hops:
            return hops[-1]
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


_DEFAULT_RATE_LIMIT_PER_MINUTE = 120


def _rate_limit_per_minute() -> int:
    """Per-IP cap. Zero/negative/garbage is the default, not unlimited."""
    raw = os.environ.get(
        "MCP_RATE_LIMIT_PER_MINUTE", str(_DEFAULT_RATE_LIMIT_PER_MINUTE)
    ).strip()
    try:
        n = int(raw)
    except ValueError:
        return _DEFAULT_RATE_LIMIT_PER_MINUTE
    if n < 1:
        return _DEFAULT_RATE_LIMIT_PER_MINUTE
    return n


class _PerIpRateLimitMiddleware(BaseHTTPMiddleware):
    """In-process sliding window per IP — soft cap on one Lambda instance."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        limit = _rate_limit_per_minute()
        path = request.url.path or ""
        if path.rstrip("/").endswith("/health"):
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


class _RejectGetMcpMiddleware(BaseHTTPMiddleware):
    """POST-only /mcp. GET SSE on Lambda sits until the 15s timeout."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        path = (request.url.path or "").rstrip("/") or "/"
        if request.method == "GET" and path == "/mcp":
            return Response(status_code=405, headers={"Allow": "POST"})
        return await call_next(request)


def _reset_rate_limit_state_for_tests() -> None:
    """Clear in-process buckets (unit tests only)."""
    _rate_buckets.clear()


_DEV_ENVS = frozenset({"development", "dev", "test", "testing", "local"})


def _is_dev_env() -> bool:
    env = (os.environ.get("ENVIRONMENT") or os.environ.get("ENV") or "").strip().lower()
    return env in _DEV_ENVS


def _allowed_hosts() -> list[str]:
    """Host headers accepted behind mcp.complyedge.io (and local smoke)."""
    raw = os.environ.get("MCP_ALLOWED_HOSTS", "").strip()
    if raw:
        return [h.strip() for h in raw.split(",") if h.strip()]
    domain = os.environ.get("DOMAIN", "complyedge.io").strip() or "complyedge.io"
    hosts = [f"mcp.{domain}", f"mcp.{domain}:*"]
    if _is_dev_env():
        hosts.extend(["localhost", "localhost:*", "127.0.0.1", "127.0.0.1:*"])
    return hosts


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
    want_off = os.environ.get("MCP_DNS_REBINDING", "1").strip().lower() in (
        "0",
        "false",
        "no",
    )
    if want_off and _is_dev_env():
        return TransportSecuritySettings(enable_dns_rebinding_protection=False)
    if want_off:
        logger.warning(
            "mcp_dns_rebinding_disable_ignored env=%s",
            (os.environ.get("ENVIRONMENT") or os.environ.get("ENV") or "unset"),
        )
    return TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=_allowed_hosts(),
        allowed_origins=_allowed_origins(),
    )


# Hosted sandbox description: the hosted server is multi-tenant and has no
# key of its own, so the caller's key travels on the MCP HTTP request itself.
HOSTED_SANDBOX_DESCRIPTION = SANDBOX_TOOL_DESCRIPTION.replace(
    "Requires COMPLYEDGE_API_KEY (this tool is listed only when it is set)",
    "Requires your ComplyEdge API key sent as the `Authorization: Bearer` "
    "header on the MCP connection (configure it in your MCP client; the key "
    "is never a tool argument and never logged)",
)


def _api_key_from_request(ctx: Context) -> str:
    """The caller's key from `Authorization: Bearer ce_...` on the HTTP request.

    Read per request: the hosted server is stateless and multi-tenant, so a key
    is never cached, never put in a tool argument, and never logged.
    """
    request = getattr(ctx.request_context, "request", None)
    header = ""
    if request is not None:
        header = (request.headers.get("authorization") or "").strip()
    scheme, _, value = header.partition(" ")
    if scheme.lower() != "bearer" or not value.strip():
        raise RuntimeError(
            f"{SANDBOX_TOOL_NAME} needs your ComplyEdge API key as "
            "`Authorization: Bearer <key>` on the MCP request. The offline "
            "tools do not."
        )
    return value.strip()


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
            "Use check_compliance, list_rules, or scan_prompt. No API key required. "
            "sandbox_check tries a case against your hosted enforcement without "
            "recording it; it needs your API key as Authorization: Bearer on the "
            "MCP connection."
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
        return _payload_from_tool_result(await _check_compliance(_get_engine(), args))

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

    @mcp.tool(
        name=SANDBOX_TOOL_NAME,
        description=HOSTED_SANDBOX_DESCRIPTION,
        annotations=TOOL_ANNOTATIONS,
    )
    async def sandbox_check(
        text: str,
        ctx: Context,
        jurisdiction: str | None = None,
    ) -> dict[str, Any]:
        api_key = _api_key_from_request(ctx)
        args: dict[str, Any] = {"text": text}
        if jurisdiction is not None:
            args["jurisdiction"] = jurisdiction
        return _payload_from_tool_result(await _sandbox_check(args, api_key))

    @mcp.custom_route("/health", methods=["GET"])
    async def health(_request: Request) -> Response:
        body, code = _health_payload()
        return JSONResponse(body, status_code=code)

    # Silence unused-name lint for TOOL_NAMES order documentation
    assert TOOL_NAMES == ("check_compliance", "list_rules", "scan_prompt")
    return mcp


def create_asgi_app():
    """ASGI app for Mangum / uvicorn (/mcp + /health + soft per-IP rate limit)."""
    app = create_mcp().streamable_http_app()
    app.add_middleware(_PerIpRateLimitMiddleware)
    app.add_middleware(_RejectGetMcpMiddleware)
    return app
