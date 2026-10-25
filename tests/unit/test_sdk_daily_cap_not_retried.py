"""The Python SDK does not retry a 429 it cannot outwait.

Leo, 2026-09-29 (ledger PRV-152): every 429 was marked retryable, so a tenant
over its daily check cap waited ~14s across three attempts and sent two more
requests certain to be refused, because the cap resets at 00:00 UTC. A 429 is
now retried only when the server's wait fits the retry budget. Transient
429s (no Retry-After, or a short one) and 5xx still retry.
"""

from __future__ import annotations

from unittest.mock import patch

import httpx
import pytest
from tenacity import wait_none

from complyedge import AsyncComplyEdgeClient, ComplianceError, ComplyEdgeClient

URL = "http://localhost:1/v1/check"
DAILY_CAP = {
    "detail": {
        "error": "rate_limit_exceeded",
        "limit": 100,
        "plan": "free",
        "reset_at": "2026-09-30T00:00:00+00:00",
        "upgrade_url": "https://dashboard.complyedge.io/?intent=sign-in&upgrade=developer",
    }
}


def _error(status: int, body: dict | None = None, headers: dict | None = None):
    req = httpx.Request("POST", URL)
    resp = httpx.Response(
        status, json=body or {"detail": "x"}, headers=headers or {}, request=req
    )
    return httpx.HTTPStatusError("err", request=req, response=resp)


CASES = [
    # (label, status, body, headers, expected attempts)
    ("daily cap, seconds header", 429, DAILY_CAP, {"Retry-After": "25200"}, 1),
    (
        "daily cap, old ISO header",
        429,
        DAILY_CAP,
        {"Retry-After": "2026-09-30T00:00:00+00:00"},
        1,
    ),
    ("daily cap, no header", 429, DAILY_CAP, {}, 1),
    (
        "sandbox limit, 60s",
        429,
        {"detail": {"error": "sandbox_rate_limit_exceeded"}},
        {"Retry-After": "60"},
        1,
    ),
    (
        "sandbox daily cap",
        429,
        {"detail": {"error": "sandbox_daily_limit_exceeded"}},
        {"Retry-After": "25200"},
        1,
    ),
    (
        "per-minute limit, no header",
        429,
        {"detail": "Too many requests. Please try again later."},
        {},
        3,
    ),
    ("short Retry-After", 429, {"detail": "slow down"}, {"Retry-After": "5"}, 3),
    ("server error", 503, {"detail": "down"}, {}, 3),
    ("client error", 400, {"detail": "bad"}, {}, 1),
]


@pytest.mark.parametrize(
    "label,status,body,headers,attempts", CASES, ids=[c[0] for c in CASES]
)
def test_sync_client_retries_only_what_can_clear(
    label, status, body, headers, attempts
):
    ce = ComplyEdgeClient(api_key="k", base_url="http://localhost:1")
    with (
        patch.object(ComplyEdgeClient.check_compliance.retry, "wait", wait_none()),
        patch.object(
            ce.client, "post", side_effect=_error(status, body, headers)
        ) as post,
    ):
        with pytest.raises(ComplianceError):
            ce.check_compliance("text", agent_id="a")
    assert post.call_count == attempts, label


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "label,status,body,headers,attempts", CASES, ids=[c[0] for c in CASES]
)
async def test_async_client_retries_only_what_can_clear(
    label, status, body, headers, attempts
):
    ce = AsyncComplyEdgeClient(api_key="k", base_url="http://localhost:1")
    with (
        patch.object(AsyncComplyEdgeClient.check_compliance.retry, "wait", wait_none()),
        patch.object(
            ce.client, "post", side_effect=_error(status, body, headers)
        ) as post,
    ):
        with pytest.raises(ComplianceError):
            await ce.check_compliance("text", agent_id="a")
    assert post.call_count == attempts, label


def test_daily_cap_error_is_not_retryable_on_the_simple_client():
    """ComplyEdge.check has no retry loop, but its error must say the same."""
    from complyedge import ComplyEdge

    ce = ComplyEdge(api_key="k", base_url="http://localhost:1")
    with patch.object(
        ce._client, "post", side_effect=_error(429, DAILY_CAP, {"Retry-After": "25200"})
    ):
        with pytest.raises(ComplianceError) as exc:
            ce.check("text")
    assert exc.value.retryable is False
