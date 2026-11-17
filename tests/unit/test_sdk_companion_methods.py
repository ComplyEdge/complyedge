"""Python SDK companion and audit helpers: confirm_action, preserve,
verify_input, canonical_conversation and assess_pre_deployment send what the
API takes and surface the API's own errors.

httpx.MockTransport sees the real request the client issues (method, path,
body). These run in the public SDK coverage job, with no service code.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

import httpx
import pytest

import complyedge as ce_mod
from complyedge import (
    CompanionActionReceipt,
    ComplianceError,
    ComplianceResult,
    ComplyEdge,
    PreservationReceipt,
    RequiredAction,
    canonical_conversation,
)

SHOWN = datetime(2026, 11, 14, 20, 1, 2, tzinfo=UTC)


def _client(responses, seen: list[httpx.Request], **kw) -> ComplyEdge:
    """responses: one (status, payload) or a list consumed in order."""
    queue = list(responses) if isinstance(responses, list) else [responses]

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        status, payload = queue.pop(0) if len(queue) > 1 else queue[0]
        return httpx.Response(status, json=payload)

    ce = ComplyEdge(api_key="k", base_url="https://example.test", agent_id="companion-bot", **kw)
    ce._client = httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handler))
    return ce


def _failing_client() -> ComplyEdge:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route", request=request)

    ce = ComplyEdge(api_key="k", base_url="https://example.test", agent_id="companion-bot")
    ce._client = httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handler))
    return ce


def _body(req: httpx.Request) -> dict:
    return json.loads(req.content)


def _check(timestamp: str) -> ComplianceResult:
    return ComplianceResult(
        event_id="chk-1",
        allowed=True,
        violations=[],
        latency_ms=3,
        bundle_version="b",
        evaluated_rules=[],
        timestamp=timestamp,
    )


# --- confirm_action -----------------------------------------------------------


def test_confirm_action_fills_the_body_from_the_entry_and_the_check() -> None:
    seen: list[httpx.Request] = []
    ce = _client((200, {"event_id": "n-1", "event_type": "notice", "confirm_key": "ck"}), seen)
    entry = RequiredAction(
        action="show_break_reminder",
        rule_ids=["us_companion.ca.break", "x"],
        jurisdiction="US-CA",
        interval_key="2026-11-14T18",
    )
    out = ce.confirm_action(
        entry,
        _check("2026-11-14T20:00:00Z"),
        confirmation_id="c-1",
        source="complyedge",
        shown_at=SHOWN,
        session_id="s-1",
        format="app",
    )
    assert out == CompanionActionReceipt(event_id="n-1", event_type="notice", confirm_key="ck", duplicate=False)
    assert (seen[0].method, seen[0].url.path) == ("POST", "/v1/companion/action")
    assert _body(seen[0]) == {
        "confirmation_id": "c-1",
        "action": "show_break_reminder",
        "source": "complyedge",
        "shown_at": "2026-11-14T20:01:02Z",
        "session_id": "s-1",
        "agent_id": "companion-bot",
        "jurisdiction": "US-CA",
        "rule_id": "us_companion.ca.break",
        "format": "app",
        "check_event_id": "chk-1",
        "check_timestamp": "2026-11-14T20:00:00Z",
        "interval_key": "2026-11-14T18",
    }


def test_confirm_action_takes_a_dict_entry_and_arguments_win() -> None:
    seen: list[httpx.Request] = []
    ce = _client((200, {"event_id": "n-2", "duplicate": True}), seen, session_id="s-default")
    out = ce.confirm_action(
        {"action": "show_ai_notice", "rule_ids": ["r1"], "jurisdiction": "US-NY"},
        confirmation_id="c-2",
        source="operator",
        shown_at="2026-11-14T20:01:02Z",
        jurisdiction="US-WA",
        rule_id="r9",
    )
    sent = _body(seen[0])
    assert (sent["jurisdiction"], sent["rule_id"], sent["session_id"]) == ("US-WA", "r9", "s-default")
    assert "check_event_id" not in sent
    assert out.duplicate is True and out.event_type == "notice"


def test_confirm_action_without_an_action_sends_nothing() -> None:
    seen: list[httpx.Request] = []
    ce = _client((200, {"event_id": "x"}), seen)
    with pytest.raises(ValueError, match="needs action"):
        ce.confirm_action(confirmation_id="c", source="operator", shown_at=SHOWN, session_id="s")
    with pytest.raises(ValueError, match="needs session_id"):
        ce.confirm_action(action="minors_notice", confirmation_id="c", source="operator", shown_at=SHOWN)
    assert seen == []


def test_confirm_action_retries_while_the_check_is_not_written(monkeypatch) -> None:
    sleeps: list[float] = []
    monkeypatch.setattr(ce_mod, "_sleep", sleeps.append)
    monkeypatch.setattr(ce_mod, "_utcnow", lambda: datetime(2026, 11, 14, 20, 0, 5, tzinfo=UTC))
    seen: list[httpx.Request] = []
    not_yet = (409, {"detail": {"code": "check_not_written_yet"}})
    ce = _client([not_yet, not_yet, (200, {"event_id": "n-3"})], seen)
    out = ce.confirm_action(
        action="show_crisis_referral",
        check=_check("2026-11-14T20:00:00Z"),
        confirmation_id="c-3",
        source="complyedge",
        shown_at=SHOWN,
        session_id="s",
    )
    assert out.event_id == "n-3"
    assert len(seen) == 3
    assert sleeps == [1.0, 2.0]


def test_confirm_action_gives_up_ten_minutes_after_the_check(monkeypatch) -> None:
    monkeypatch.setattr(ce_mod, "_sleep", lambda s: None)
    late = datetime(2026, 11, 14, 20, 0, tzinfo=UTC) + timedelta(minutes=11)
    monkeypatch.setattr(ce_mod, "_utcnow", lambda: late)
    seen: list[httpx.Request] = []
    ce = _client((409, {"code": "check_not_written_yet"}), seen)
    with pytest.raises(ComplianceError, match="within 10 minutes"):
        ce.confirm_action(
            action="show_crisis_referral",
            check=_check("2026-11-14T20:00:00Z"),
            confirmation_id="c-4",
            source="complyedge",
            shown_at=SHOWN,
            session_id="s",
        )
    assert len(seen) == 1


def test_confirm_action_without_a_check_does_not_retry_a_409() -> None:
    seen: list[httpx.Request] = []
    ce = _client((409, {"code": "check_not_written_yet"}), seen)
    with pytest.raises(ComplianceError, match="within 10 minutes"):
        ce.confirm_action(action="minors_notice", confirmation_id="c", source="operator", shown_at=SHOWN, session_id="s")
    assert len(seen) == 1


def test_confirm_action_surfaces_the_api_error_and_its_code() -> None:
    seen: list[httpx.Request] = []
    ce = _client((422, {"detail": {"code": "unknown_action", "message": "no such action"}}), seen)
    with pytest.raises(ComplianceError) as err:
        ce.confirm_action(action="nope", confirmation_id="c", source="operator", shown_at=SHOWN, session_id="s")
    assert "422" in str(err.value)
    assert err.value.code == "unknown_action"


def test_confirm_action_network_failure_is_retryable() -> None:
    with pytest.raises(ComplianceError) as err:
        _failing_client().confirm_action(
            action="minors_notice", confirmation_id="c", source="operator", shown_at=SHOWN, session_id="s"
        )
    assert err.value.retryable is True


# --- preserve -----------------------------------------------------------------


CONVO = [{"role": "user", "text": "é", "sent_at": SHOWN}]


def test_preserve_sends_the_canonical_conversation_bytes() -> None:
    seen: list[httpx.Request] = []
    ce = _client(
        (
            200,
            {
                "event_id": "p-1",
                "timestamp": "2026-11-14T20:02:00Z",
                "account_duties": ["retain_account", "notify_parent_if_practicable"],
            },
        ),
        seen,
        session_id="s-1",
    )
    out = ce.preserve(
        CONVO,
        trigger="serious_self_harm",
        preserved_at=SHOWN,
        deciding_system_version="2026.11",
    )
    assert out == PreservationReceipt(
        event_id="p-1",
        timestamp="2026-11-14T20:02:00Z",
        event_type="preservation",
        account_duties=["retain_account", "notify_parent_if_practicable"],
    )
    assert seen[0].url.path == "/v1/companion/preservation"
    raw = seen[0].content.decode("utf-8")
    assert canonical_conversation(CONVO).decode("utf-8") in raw
    sent = json.loads(raw)
    assert sent["conversation"] == [{"role": "user", "sent_at": "2026-11-14T20:01:02.000Z", "text": "é"}]
    assert (sent["trigger"], sent["session_id"], sent["agent_id"]) == ("serious_self_harm", "s-1", "companion-bot")
    assert "user_id" not in sent


def test_preserve_errors_carry_the_api_code() -> None:
    seen: list[httpx.Request] = []
    ce = _client((403, {"detail": {"code": "plan_required", "message": "Enterprise"}}), seen)
    with pytest.raises(ComplianceError) as err:
        ce.preserve(CONVO, trigger="parent_notified", preserved_at=SHOWN, deciding_system_version="v")
    assert err.value.code == "plan_required"


def test_preserve_network_failure_is_retryable() -> None:
    with pytest.raises(ComplianceError) as err:
        _failing_client().preserve(CONVO, trigger="child_died", preserved_at=SHOWN, deciding_system_version="v")
    assert err.value.retryable is True


# --- canonical_conversation ---------------------------------------------------


def test_canonical_conversation_ignores_formatting() -> None:
    a = canonical_conversation('[ {"text": "hi", "role": "user", "sent_at": "t"} ]')
    b = canonical_conversation([{"role": "user", "sent_at": "t", "text": "hi"}])
    assert a == b == b'[{"role":"user","sent_at":"t","text":"hi"}]'


@pytest.mark.parametrize(
    ("value", "message"),
    [
        ({"role": "user"}, "must be a list"),
        (["x"], "must be an object"),
        ([{"role": "user", "text": "t"}], "missing: sent_at"),
        ([{"role": "user", "text": "t", "sent_at": "s", "id": 1}], "unexpected: id"),
        ([{"role": "user", "text": 3, "sent_at": "s"}], "text must be a string"),
    ],
)
def test_canonical_conversation_refuses_what_it_cannot_commit(value, message) -> None:
    with pytest.raises(ValueError, match=message):
        canonical_conversation(value)


# --- verify_input -------------------------------------------------------------


def test_verify_input_is_true_only_on_a_match() -> None:
    seen: list[httpx.Request] = []
    assert _client((200, {"match": True}), seen).verify_input("e-1", "hello") is True
    assert _body(seen[0]) == {"event_id": "e-1", "text": "hello"}
    assert seen[0].url.path == "/v1/audit/verify"
    assert _client((200, {"match": False}), []).verify_input("e-1", "other") is False
    assert _client((200, {}), []).verify_input("e-1", "other") is False


def test_verify_input_unknown_event_raises() -> None:
    with pytest.raises(ComplianceError, match="404"):
        _client((404, {"detail": "Audit event not found"}), []).verify_input("missing", "t")


def test_verify_input_network_failure_is_retryable() -> None:
    with pytest.raises(ComplianceError) as err:
        _failing_client().verify_input("e", "t")
    assert err.value.retryable is True


# --- assess_pre_deployment ----------------------------------------------------


def test_assess_pre_deployment_posts_the_system_description() -> None:
    seen: list[httpx.Request] = []
    out = _client((200, {"risk_tier": "high"}), seen).assess_pre_deployment(
        system_prompt="You are a hiring assistant",
        model_config={"provider": "openai"},
        agent_pipeline={"tools": ["resume_scorer"]},
    )
    assert out == {"risk_tier": "high"}
    sent = _body(seen[0])
    assert seen[0].url.path == "/v1/assessment/pre-deployment"
    assert sent["model_config"] == {"provider": "openai"}
    assert sent["agent_pipeline"] == {"tools": ["resume_scorer"]}


def test_assess_pre_deployment_errors() -> None:
    with pytest.raises(ComplianceError, match="400"):
        _client((400, {"detail": "bad"}), []).assess_pre_deployment(system_prompt="x")
    with pytest.raises(ComplianceError, match="Request failed"):
        _failing_client().assess_pre_deployment(system_prompt="x")
