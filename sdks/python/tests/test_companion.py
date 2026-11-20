"""Companion chatbot support in the Python SDK.

Mocked httpx, asserting the path and body the client actually issues, the same
approach as tests/unit/test_sdk_appeals.py.

- the SDK sends what it is given and nothing else; ``direction`` is absent
  unless the caller gives it (it used to default to "output", so a forgotten
  direction had every user message judged as a bot reply)
- a companion check without direction or session_id is refused before any
  HTTP call
- the new response fields parse, and parse as empty on an older API
- confirm_action retries on 409 check_not_written_yet, then succeeds; stops
  10 minutes after the check's timestamp
- preserve sends RFC 8785 bytes that do not depend on the caller's formatting
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import httpx
import pytest

import complyedge
from complyedge import (
    AsyncComplyEdgeClient,
    ComplianceError,
    ComplyEdge,
    ComplyEdgeClient,
    RequiredAction,
    canonical_conversation,
)

CHECK_OK = {
    "event_id": "evt-1",
    "allowed": True,
    "violations": [],
    "timestamp": "2026-11-14T20:00:00.000000Z",
    "audit_logged": True,
}

COMPANION_FIELDS = {
    "companion_assessment": "assessed",
    "companion_not_assessed_reason": None,
    "companion_fallback": False,
    "required_actions": [
        {
            "action": "show_crisis_referral",
            "rule_ids": ["us-ca-22602b-crisis-referral", "us-ca-21812-crisis"],
            "jurisdiction": "US-CA",
            "reason_code": "expresses_self_harm",
            "due_at": "2026-11-14T20:00:00Z",
            "interval_key": "ab" * 32,
            "counted": True,
        },
        {
            "action": "block_reply",
            "rule_ids": ["us-ca-21812-block"],
            "jurisdiction": "US-CA",
            "reason_code": "minor_sexual_content",
            "due_at": "2026-11-14T20:00:00Z",
            "interval_key": "cd" * 32,
            "counted": False,
        },
    ],
}


def _resp(payload: dict, status: int = 200) -> httpx.Response:
    return httpx.Response(
        status, json=payload, request=httpx.Request("POST", "https://example.test")
    )


def _client(**kw) -> ComplyEdge:
    return ComplyEdge(api_key="k", base_url="https://example.test", **kw)


# --- direction is sent only when given -------------------------------------


@patch("httpx.Client.post")
def test_check_without_direction_sends_no_direction(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    _client().check("hello")
    assert post.call_args.args[0] == "/v1/check"
    assert post.call_args.kwargs["json"] == {
        "text": "hello",
        "jurisdiction": "EU",
        "agent_id": "default",
        "use_semantic_fallback": False,
    }


@patch("httpx.Client.post")
def test_check_sends_the_direction_it_is_given(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    _client().check("hello", direction="prompt")
    assert post.call_args.kwargs["json"]["direction"] == "prompt"


@patch("httpx.Client.post")
def test_advanced_client_sends_no_direction_unless_given(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    with ComplyEdgeClient(api_key="k", base_url="https://example.test") as c:
        c.check_compliance("hello", agent_id="a")
        assert "direction" not in post.call_args.kwargs["json"]
        c.check_compliance("hello", agent_id="a", direction=complyedge.DirectionType.PROMPT)
        assert post.call_args.kwargs["json"]["direction"] == "prompt"


# --- the companion check sends exactly what it is given ---------------------


@patch("httpx.Client.post")
def test_companion_check_sends_use_case_and_context_and_nothing_else(post: MagicMock) -> None:
    post.return_value = _resp({**CHECK_OK, **COMPANION_FIELDS})
    ctx = {
        "age_status": "known_minor",
        "age_source": "os_signal",
        "is_session_start": True,
        "session_started_at": "2026-11-14T19:00:00Z",
        "minutes_today": 42,
        "referrals_this_session": 0,
        "parent_linked": False,
    }
    _client(agent_id="pal").check(
        "I want to hurt myself",
        jurisdiction="US-CA",
        direction="prompt",
        use_case="companion_chatbot",
        session_id="sess-1",
        user_id="u-9",
        context=ctx,
    )
    assert post.call_args.kwargs["json"] == {
        "text": "I want to hurt myself",
        "jurisdiction": "US-CA",
        "agent_id": "pal",
        "use_semantic_fallback": False,
        "direction": "prompt",
        "use_case": "companion_chatbot",
        "context": {**ctx, "session_id": "sess-1", "user_id": "u-9"},
    }


@patch("httpx.Client.post")
def test_session_id_in_context_satisfies_the_companion_check(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    _client().check(
        "hi",
        direction="output",
        use_case="companion_chatbot",
        context={"session_id": "sess-ctx"},
    )
    assert post.call_args.kwargs["json"]["context"] == {"session_id": "sess-ctx"}


@patch("httpx.Client.post")
def test_companion_user_message_is_sent_on_a_companion_reply(post: MagicMock) -> None:
    post.return_value = _resp({**CHECK_OK, **COMPANION_FIELDS})
    _client().check(
        "Please don't go",
        direction="output",
        use_case="companion_chatbot",
        session_id="sess-1",
        companion_user_message="ok I am logging off",
    )
    body = post.call_args.kwargs["json"]
    assert body["companion_user_message"] == "ok I am logging off"
    assert body["direction"] == "output"


@patch("httpx.Client.post")
def test_module_check_sends_companion_user_message(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    complyedge.check(
        "Please don't go",
        api_key="k",
        base_url="https://example.test",
        direction="output",
        use_case="companion_chatbot",
        session_id="sess-1",
        companion_user_message="ok I am logging off",
    )
    assert post.call_args.kwargs["json"]["companion_user_message"] == "ok I am logging off"


@patch("httpx.Client.post")
def test_companion_user_message_absent_unless_given(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    _client().check("hi", direction="output", use_case="companion_chatbot", session_id="s")
    assert "companion_user_message" not in post.call_args.kwargs["json"]


@pytest.mark.parametrize(
    "kwargs",
    [
        {"direction": "output"},  # not a companion check
        {"direction": "prompt", "use_case": "companion_chatbot", "session_id": "s"},
    ],
)
@patch("httpx.Client.post")
def test_companion_user_message_refused_off_a_companion_reply(
    post: MagicMock, kwargs: dict
) -> None:
    with pytest.raises(ValueError, match="companion_user_message"):
        _client().check("hi", companion_user_message="bye", **kwargs)
    with ComplyEdgeClient(api_key="k", base_url="https://example.test") as c:
        with pytest.raises(ValueError, match="companion_user_message"):
            c.check_compliance("hi", agent_id="a", companion_user_message="bye", **kwargs)
    post.assert_not_called()


@pytest.mark.parametrize(
    "kwargs, missing",
    [
        ({"session_id": "s"}, "direction"),
        ({"direction": "prompt"}, "session_id"),
        ({}, "direction"),
    ],
)
@patch("httpx.Client.post")
def test_incomplete_companion_check_is_refused_before_sending(
    post: MagicMock, kwargs: dict, missing: str
) -> None:
    with pytest.raises(ValueError, match=missing):
        _client().check("hi", use_case="companion_chatbot", **kwargs)
    post.assert_not_called()


@patch("httpx.Client.post")
def test_advanced_client_refuses_incomplete_companion_check(post: MagicMock) -> None:
    with ComplyEdgeClient(api_key="k", base_url="https://example.test") as c:
        with pytest.raises(ValueError, match="direction"):
            c.check_compliance("hi", agent_id="a", use_case="companion_chatbot", session_id="s")
        with pytest.raises(ValueError, match="session_id"):
            c.check_compliance("hi", agent_id="a", use_case="companion_chatbot", direction="prompt")
    post.assert_not_called()


@patch("httpx.AsyncClient.post")
async def test_async_client_refuses_incomplete_companion_check(post: MagicMock) -> None:
    async with AsyncComplyEdgeClient(api_key="k", base_url="https://example.test") as c:
        with pytest.raises(ValueError, match="direction"):
            await c.check_compliance(
                "hi", agent_id="a", use_case="companion_chatbot", session_id="s"
            )
    post.assert_not_called()


# --- response parsing ------------------------------------------------------


@patch("httpx.Client.post")
def test_companion_response_fields_parse(post: MagicMock) -> None:
    post.return_value = _resp({**CHECK_OK, **COMPANION_FIELDS, "companion_fallback": True})
    r = _client().check("x", direction="prompt", use_case="companion_chatbot", session_id="s")
    assert r.companion_assessment == "assessed"
    assert r.companion_not_assessed_reason is None
    assert r.companion_fallback is True
    assert r.required_actions == [
        RequiredAction(
            action="show_crisis_referral",
            rule_ids=["us-ca-22602b-crisis-referral", "us-ca-21812-crisis"],
            jurisdiction="US-CA",
            reason_code="expresses_self_harm",
            due_at="2026-11-14T20:00:00Z",
            interval_key="ab" * 32,
            counted=True,
        ),
        RequiredAction(
            action="block_reply",
            rule_ids=["us-ca-21812-block"],
            jurisdiction="US-CA",
            reason_code="minor_sexual_content",
            due_at="2026-11-14T20:00:00Z",
            interval_key="cd" * 32,
            counted=False,
        ),
    ]


@patch("httpx.Client.post")
def test_not_assessed_reason_parses(post: MagicMock) -> None:
    post.return_value = _resp(
        {
            **CHECK_OK,
            "companion_assessment": "not_assessed",
            "companion_not_assessed_reason": "budget",
            "required_actions": [],
        }
    )
    r = _client().check("x", direction="prompt", use_case="companion_chatbot", session_id="s")
    assert (r.companion_assessment, r.companion_not_assessed_reason) == ("not_assessed", "budget")
    assert r.required_actions == []


@patch("httpx.Client.post")
def test_older_api_without_companion_fields_parses_as_empty(post: MagicMock) -> None:
    post.return_value = _resp(CHECK_OK)
    r = _client().check("x")
    assert r.companion_assessment is None
    assert r.companion_not_assessed_reason is None
    assert r.companion_fallback is False
    assert r.required_actions == []


# --- confirm_action ----------------------------------------------------------

RECEIPT = {"event_id": "ntc-1", "event_type": "notice", "confirm_key": "ck", "duplicate": False}


def _check_result(timestamp: str) -> complyedge.ComplianceResult:
    return complyedge.ComplianceResult(
        event_id="evt-1",
        allowed=True,
        violations=[],
        latency_ms=1,
        bundle_version="b",
        evaluated_rules=[],
        timestamp=timestamp,
        required_actions=[
            RequiredAction(
                action="show_crisis_referral",
                rule_ids=["us-ca-22602b-crisis-referral", "us-ca-21812-crisis"],
                jurisdiction="US-CA",
                interval_key="ab" * 32,
                counted=True,
            )
        ],
    )


@patch("httpx.Client.post")
def test_confirm_action_fills_from_the_entry_and_check(post: MagicMock) -> None:
    post.return_value = _resp(RECEIPT)
    check = _check_result("2026-11-14T20:00:00.000000Z")
    receipt = _client(agent_id="pal", session_id="sess-1").confirm_action(
        check.required_actions[0],
        check,
        confirmation_id="conf-1",
        source="complyedge",
        shown_at="2026-11-14T20:00:01Z",
        format="app",
        deciding_system_version="pal-3",
        language="en",
    )
    assert post.call_args.args[0] == "/v1/companion/action"
    assert post.call_args.kwargs["json"] == {
        "confirmation_id": "conf-1",
        "action": "show_crisis_referral",
        "source": "complyedge",
        "shown_at": "2026-11-14T20:00:01Z",
        "session_id": "sess-1",
        "agent_id": "pal",
        "jurisdiction": "US-CA",
        "rule_id": "us-ca-22602b-crisis-referral",
        "format": "app",
        "deciding_system_version": "pal-3",
        "language": "en",
        "check_event_id": "evt-1",
        "check_timestamp": "2026-11-14T20:00:00.000000Z",
        "interval_key": "ab" * 32,
    }
    assert receipt == complyedge.CompanionActionReceipt("ntc-1", "notice", "ck", False)


@patch("httpx.Client.post")
def test_operator_only_notice_sends_no_check_fields(post: MagicMock) -> None:
    post.return_value = _resp({**RECEIPT, "duplicate": True})
    receipt = _client(agent_id="pal").confirm_action(
        action="minors_notice",
        confirmation_id="op-1",
        source="operator",
        shown_at="2026-11-14T20:00:01Z",
        session_id="sess-1",
        jurisdiction="US-CA",
        format="browser",
    )
    assert post.call_args.kwargs["json"] == {
        "confirmation_id": "op-1",
        "action": "minors_notice",
        "source": "operator",
        "shown_at": "2026-11-14T20:00:01Z",
        "session_id": "sess-1",
        "agent_id": "pal",
        "jurisdiction": "US-CA",
        "format": "browser",
    }
    assert receipt.duplicate is True


@patch("httpx.Client.post")
def test_confirm_action_without_session_is_refused_before_sending(post: MagicMock) -> None:
    with pytest.raises(ValueError, match="session_id"):
        _client().confirm_action(
            action="minors_notice", confirmation_id="x", source="operator", shown_at="t"
        )
    post.assert_not_called()


@patch("httpx.Client.post")
def test_confirm_action_retries_on_409_then_succeeds(
    post: MagicMock, monkeypatch: pytest.MonkeyPatch
) -> None:
    now = datetime.now(timezone.utc)
    sleeps: list[float] = []
    monkeypatch.setattr(complyedge, "_sleep", sleeps.append)
    not_yet = {"detail": {"code": "check_not_written_yet"}}
    post.side_effect = [_resp(not_yet, 409), _resp({"code": "check_not_written_yet"}, 409), _resp(RECEIPT)]
    check = _check_result(now.isoformat().replace("+00:00", "Z"))
    receipt = _client(session_id="s").confirm_action(
        check.required_actions[0], check, confirmation_id="c", source="complyedge", shown_at=now
    )
    assert receipt.event_id == "ntc-1"
    assert post.call_count == 3
    assert sleeps == [1.0, 2.0]
    # Every attempt sent the same body.
    bodies = [c.kwargs["json"] for c in post.call_args_list]
    assert bodies[0] == bodies[1] == bodies[2]


@patch("httpx.Client.post")
def test_confirm_action_gives_up_ten_minutes_after_the_check(
    post: MagicMock, monkeypatch: pytest.MonkeyPatch
) -> None:
    check_ts = datetime(2026, 11, 14, 20, 0, tzinfo=timezone.utc)
    clock = [check_ts + timedelta(minutes=9, seconds=58)]
    sleeps: list[float] = []

    def fake_sleep(seconds: float) -> None:
        sleeps.append(seconds)
        clock[0] += timedelta(seconds=seconds)

    monkeypatch.setattr(complyedge, "_sleep", fake_sleep)
    monkeypatch.setattr(complyedge, "_utcnow", lambda: clock[0])
    post.return_value = _resp({"code": "check_not_written_yet"}, 409)
    check = _check_result("2026-11-14T20:00:00Z")
    with pytest.raises(ComplianceError, match="409"):
        _client(session_id="s").confirm_action(
            check.required_actions[0], check, confirmation_id="c", source="complyedge", shown_at=clock[0]
        )
    # 1s, then the last 1s left in the window, then it stops.
    assert sleeps == [1.0, 1.0]
    assert post.call_count == 3


@patch("httpx.Client.post")
def test_confirm_action_does_not_retry_other_errors(post: MagicMock) -> None:
    post.return_value = _resp({"detail": {"code": "action_not_asked"}}, 422)
    check = _check_result("2026-11-14T20:00:00Z")
    with pytest.raises(ComplianceError, match="422"):
        _client(session_id="s").confirm_action(
            check.required_actions[0], check, confirmation_id="c", source="complyedge", shown_at="t"
        )
    assert post.call_count == 1


# --- preserve: RFC 8785 canonical bytes --------------------------------------

CONVO_A = [
    {"role": "user", "text": "café", "sent_at": "2026-11-14T19:59:00.000Z"},
    {"role": "assistant", "text": "I hear you.\nCall 988.", "sent_at": "2026-11-14T19:59:05.000Z"},
]
# Same conversation: other key order, other whitespace, "e" + combining accent.
CONVO_B_JSON = """
[ { "sent_at" : "2026-11-14T19:59:00.000Z",  "text": "café", "role": "user" },
  {"text":"I hear you.\\nCall 988.","role":"assistant","sent_at":"2026-11-14T19:59:05.000Z"} ]
"""

EXPECTED = (
    '[{"role":"user","sent_at":"2026-11-14T19:59:00.000Z","text":"café"},'
    '{"role":"assistant","sent_at":"2026-11-14T19:59:05.000Z","text":"I hear you.\\nCall 988."}]'
).encode("utf-8")


def test_canonical_bytes_equal_for_two_differently_formatted_inputs() -> None:
    a = canonical_conversation(CONVO_A)
    b = canonical_conversation(CONVO_B_JSON)
    assert a == b == EXPECTED


def test_canonical_form_writes_datetimes_like_javascript() -> None:
    sent = datetime(2026, 11, 14, 19, 59, 0, 123456, tzinfo=timezone.utc)
    out = canonical_conversation([{"role": "user", "text": "hi", "sent_at": sent}])
    assert out == b'[{"role":"user","sent_at":"2026-11-14T19:59:00.123Z","text":"hi"}]'


def test_canonical_form_refuses_extra_keys() -> None:
    with pytest.raises(ValueError, match="unexpected: id"):
        canonical_conversation([{"role": "user", "text": "hi", "sent_at": "t", "id": "1"}])


@patch("httpx.Client.post")
def test_preserve_sends_the_canonical_bytes(post: MagicMock) -> None:
    post.return_value = _resp(
        {"event_id": "prs-1", "timestamp": "2026-11-14T20:00:02Z", "event_type": "preservation"}
    )
    ce = _client(agent_id="pal", session_id="sess-1")
    r1 = ce.preserve(
        CONVO_A,
        trigger="parent_notified",
        preserved_at="2026-11-14T20:00:00Z",
        deciding_system_version="pal-3",
    )
    first = post.call_args.kwargs["content"]
    ce.preserve(
        CONVO_B_JSON,
        trigger="parent_notified",
        preserved_at="2026-11-14T20:00:00Z",
        deciding_system_version="pal-3",
    )
    second = post.call_args.kwargs["content"]
    assert post.call_args.args[0] == "/v1/companion/preservation"
    assert first == second
    assert EXPECTED in first
    # Same bytes as the TypeScript SDK sends for the same input.
    assert first == (
        b'{"agent_id":"pal","conversation":' + EXPECTED + b',"deciding_system_version":"pal-3",'
        b'"preserved_at":"2026-11-14T20:00:00Z","session_id":"sess-1","trigger":"parent_notified"}'
    )
    assert json.loads(first) == {
        "agent_id": "pal",
        "conversation": json.loads(EXPECTED),
        "deciding_system_version": "pal-3",
        "preserved_at": "2026-11-14T20:00:00Z",
        "session_id": "sess-1",
        "trigger": "parent_notified",
    }
    assert r1 == complyedge.PreservationReceipt("prs-1", "2026-11-14T20:00:02Z", "preservation")


# --- companion error bodies keep their code ----------------------------------


@patch("httpx.Client.post")
def test_companion_error_body_keeps_its_code_and_message(post: MagicMock) -> None:
    """The companion endpoints answer {"code", "message"} with no "detail"; the
    SDK used to raise the bare httpx text, so a caller could not tell
    trigger_invalid from any other 422."""
    post.return_value = _resp({"code": "trigger_invalid", "message": "Unknown trigger."}, 422)
    with pytest.raises(ComplianceError) as err:
        _client().preserve([], trigger="x", preserved_at="2026-11-14T20:00:00Z",
                           deciding_system_version="1")
    assert err.value.code == "trigger_invalid"
    assert "Unknown trigger." in str(err.value)


@patch("httpx.Client.request")
def test_get_requests_keep_the_error_code(request: MagicMock) -> None:
    request.return_value = httpx.Response(
        404, json={"code": "not_found", "message": "No such appeal."},
        request=httpx.Request("GET", "https://example.test"))
    with pytest.raises(ComplianceError) as err:
        _client().get_appeal("r-1")
    assert err.value.code == "not_found"
    assert "No such appeal." in str(err.value)


@patch("httpx.Client.post")
def test_preserve_returns_the_account_duties(post: MagicMock) -> None:
    post.return_value = _resp({
        "event_id": "prs-1", "timestamp": "2026-11-14T20:00:02Z", "event_type": "preservation",
        "account_duties": ["notify_parent_if_practicable", "retain_account"],
    })
    r = _client(agent_id="pal", session_id="sess-1").preserve(
        CONVO_A, trigger="serious_self_harm", preserved_at="2026-11-14T20:00:00Z",
        deciding_system_version="pal-3")
    assert r.account_duties == ["notify_parent_if_practicable", "retain_account"]


# --- a refused check still carries what the law asks ------------------------
# The API puts the companion fields in the 429 and 503 body. The SDK
# used to flatten the whole body into the message string, so an app that caught
# ComplianceError could not show the crisis referral it was owed.

REFUSAL_DETAIL = {
    "error": "daily_limit_exceeded",
    "message": "Daily limit reached.",
    **COMPANION_FIELDS,
    "companion_assessment": "not_assessed",
    "companion_not_assessed_reason": "unavailable",
    "upcoming_actions": [
        {
            "action": "show_break_reminder",
            "rule_ids": ["us-ca-22602c2-break"],
            "jurisdiction": "US-CA",
            "reason_code": "ca_22602c2_break",
            "due_at": "2026-11-14T23:00:00Z",
            "counted": True,
        }
    ],
}


@pytest.mark.parametrize("status", [429, 503])
@patch("httpx.Client.post")
def test_refused_companion_check_keeps_its_required_actions(
    post: MagicMock, status: int
) -> None:
    post.return_value = _resp({"detail": REFUSAL_DETAIL}, status)
    with pytest.raises(ComplianceError) as err:
        _client().check(
            "I keep thinking about ending it.",
            direction="prompt",
            use_case="companion_chatbot",
            context={"session_id": "s-1"},
        )
    e = err.value
    assert e.status_code == status
    assert e.body == {"detail": REFUSAL_DETAIL}
    assert [a.action for a in e.required_actions] == ["show_crisis_referral", "block_reply"]
    assert isinstance(e.required_actions[0], RequiredAction)
    assert [a.action for a in e.upcoming_actions] == ["show_break_reminder"]
    assert e.companion_assessment == "not_assessed"
    assert e.companion_not_assessed_reason == "unavailable"


@patch("httpx.Client.post")
def test_refusal_without_companion_fields_parses_as_empty(post: MagicMock) -> None:
    post.return_value = _resp({"detail": "Daily limit reached."}, 429)
    with pytest.raises(ComplianceError) as err:
        _client().check("hello")
    assert err.value.status_code == 429
    assert err.value.required_actions == [] and err.value.upcoming_actions == []
    assert err.value.companion_assessment is None
    assert "Daily limit reached." in str(err.value)


def test_an_error_with_no_http_answer_has_empty_refusal_fields() -> None:
    e = ComplianceError("Request failed: timeout", retryable=True)
    assert e.status_code is None and e.body is None and e.required_actions == []


# --- integration warnings and operator-supplied labels -----------------------


@patch("httpx.Client.post")
def test_warnings_and_operator_asserted_parse_and_labels_are_sent(post: MagicMock) -> None:
    post.return_value = _resp(
        {
            **CHECK_OK,
            **COMPANION_FIELDS,
            "companion_assessment": "operator_asserted",
            "companion_warnings": ["age_status_missing"],
        }
    )
    r = _client().check(
        "x",
        direction="prompt",
        use_case="companion_chatbot",
        context={"session_id": "s", "operator_labels": ["expresses_self_harm"]},
    )
    assert r.companion_assessment == "operator_asserted"
    assert r.companion_warnings == ["age_status_missing"]
    assert post.call_args.kwargs["json"]["context"]["operator_labels"] == ["expresses_self_harm"]


@patch("httpx.Client.post")
def test_an_api_without_warnings_parses_as_empty(post: MagicMock) -> None:
    post.return_value = _resp({**CHECK_OK, **COMPANION_FIELDS})
    r = _client().check("x", direction="prompt", use_case="companion_chatbot", session_id="s")
    assert r.companion_warnings == []


@patch("httpx.Client.post")
def test_a_refused_check_keeps_its_warnings(post: MagicMock) -> None:
    detail = {**REFUSAL_DETAIL, "companion_warnings": ["session_start_changed"]}
    post.return_value = _resp({"detail": detail}, 429)
    with pytest.raises(ComplianceError) as err:
        _client().check(
            "x", direction="prompt", use_case="companion_chatbot", context={"session_id": "s"}
        )
    assert err.value.companion_warnings == ["session_start_changed"]
