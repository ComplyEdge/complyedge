"""Python SDK appeals: record_appeal, record_answer, list_appeals and get_appeal
send what the API takes and surface the API's own error messages.

httpx.MockTransport sees the real request the client issues (method, path,
query, body). The server side is covered by tests/unit/test_audit_reviews_routes.py.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime

import httpx
import pytest

from complyedge import ComplianceError, ComplyEdge


def _client(status: int, payload: dict, seen: list[httpx.Request]) -> ComplyEdge:
    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(status, json=payload)

    ce = ComplyEdge(
        api_key="k", base_url="https://example.test", agent_id="credit-assistant"
    )
    ce._client = httpx.Client(
        base_url="https://example.test", transport=httpx.MockTransport(handler)
    )
    return ce


def _body(req: httpx.Request) -> dict:
    return json.loads(req.content)


def test_record_appeal_posts_the_request_and_returns_its_id() -> None:
    seen: list[httpx.Request] = []
    ce = _client(
        200,
        {"event_id": "req-1", "event_type": "contest", "already_recorded": False},
        seen,
    )
    rid = ce.record_appeal(
        "dec-1",
        "human_intervention",
        system_version="2026.10.1",
        agent_id="agent-hr",
        requested_at=datetime(2026, 11, 13, 8, 44, tzinfo=UTC),
    )
    assert rid == "req-1"
    assert (seen[0].method, seen[0].url.path) == ("POST", "/v1/audit/contest")
    assert _body(seen[0]) == {
        "agent_id": "agent-hr",
        "deciding_system": {"version": "2026.10.1"},
        "decision_ref": "dec-1",
        "request_kind": "human_intervention",
        "requested_at": "2026-11-13T08:44:00Z",
    }


def test_record_appeal_lets_the_api_read_agent_and_version_from_the_decision() -> None:
    # The common call is two arguments: the decision id and the kind.
    seen: list[httpx.Request] = []
    _client(200, {"event_id": "req-1"}, seen).record_appeal("dec-1", "contest")
    sent = _body(seen[0])
    assert "agent_id" not in sent
    assert "deciding_system" not in sent


def test_record_appeal_defaults_requested_at_to_now() -> None:
    seen: list[httpx.Request] = []
    before = datetime.now(UTC).replace(microsecond=0)
    _client(200, {"event_id": "req-1"}, seen).record_appeal("dec-1", "explanation")
    sent = _body(seen[0])["requested_at"]
    assert datetime.fromisoformat(sent.replace("Z", "+00:00")) >= before


def test_record_answer_posts_by_request_id() -> None:
    seen: list[httpx.Request] = []
    ce = _client(
        200,
        {
            "event_id": "ans-1",
            "event_type": "contest",
            "request_id": "req/1",
            "already_recorded": False,
        },
        seen,
    )
    out = ce.record_answer(
        "req/1",
        "rectified",
        statement_ref="ticket:88213",
        reviewer="staff:4471",
        responded_at="2026-11-20T15:10:00Z",
        rectified_at=datetime(2026, 11, 20, 15, 10),  # naive -> UTC
    )
    assert out["already_recorded"] is False
    assert seen[0].url.raw_path == b"/v1/audit/reviews/req%2F1/answer"
    assert _body(seen[0]) == {
        "review_outcome": "rectified",
        "statement_ref": "ticket:88213",
        "reviewer": "staff:4471",
        "responded_at": "2026-11-20T15:10:00Z",
        "rectified_at": "2026-11-20T15:10:00Z",
    }


def test_record_answer_leaves_responded_at_to_the_server() -> None:
    seen: list[httpx.Request] = []
    _client(200, {"event_id": "ans-1"}, seen).record_answer(
        "req-1", "upheld", statement_ref="ticket:1", reviewer="staff:1"
    )
    assert "responded_at" not in _body(seen[0])


def test_list_appeals_reads_open_appeals_by_default() -> None:
    seen: list[httpx.Request] = []
    item = {"request_id": "req-1", "due_at": "2026-12-14T23:59:59Z", "late": False}
    out = _client(
        200, {"status": "open", "count": 1, "reviews": [item]}, seen
    ).list_appeals()
    assert out == [item]
    assert (seen[0].method, seen[0].url.path) == ("GET", "/v1/audit/reviews")
    assert seen[0].url.params["status"] == "open"


def test_get_appeal_reads_one_by_its_escaped_id() -> None:
    seen: list[httpx.Request] = []
    payload = {
        "review": {"request_id": "req/1"},
        "decision": None,
        "decision_missing": True,
    }
    assert _client(200, payload, seen).get_appeal("req/1") == payload
    assert seen[0].url.raw_path == b"/v1/audit/reviews/req%2F1"


def test_api_error_carries_the_api_message() -> None:
    seen: list[httpx.Request] = []
    ce = _client(404, {"detail": "No such review request."}, seen)
    with pytest.raises(
        ComplianceError, match=r"API error \(404\): No such review request\."
    ):
        ce.record_answer("nope", "upheld", statement_ref="ticket:1", reviewer="staff:1")


def test_missing_decision_facts_error_says_what_to_send() -> None:
    seen: list[httpx.Request] = []
    detail = {
        "code": "decision_facts_missing",
        "message": "Send agent_id and deciding_system.version: the decision was not found on your account.",
    }
    ce = _client(422, {"detail": detail}, seen)
    with pytest.raises(
        ComplianceError, match="Send agent_id and deciding_system.version"
    ):
        ce.record_appeal("dec-x", "contest")


def test_validation_error_names_the_field() -> None:
    seen: list[httpx.Request] = []
    detail = [
        {
            "loc": ["body", "request_kind"],
            "msg": "Input should be 'contest' or 'review'",
        }
    ]
    ce = _client(422, {"detail": detail}, seen)
    with pytest.raises(ComplianceError, match="request_kind: Input should be"):
        ce.record_appeal("dec-1", "appeal")


def test_review_not_recorded_is_not_retryable() -> None:
    """The API says trying again will not help (the account's audit key is
    unavailable); code that retries on e.retryable must not loop."""
    seen: list[httpx.Request] = []
    detail = {"code": "review_not_recorded", "message": "The answer was not saved."}
    ce = _client(503, {"detail": detail}, seen)
    with pytest.raises(ComplianceError) as err:
        ce.record_answer(
            "req-1", "upheld", statement_ref="ticket:1", reviewer="staff:1"
        )
    assert err.value.code == "review_not_recorded"
    assert err.value.retryable is False
    other = _client(
        503, {"detail": "Review requests could not be read. Try again."}, []
    )
    with pytest.raises(ComplianceError) as err2:
        other.list_appeals()
    assert err2.value.retryable is True
