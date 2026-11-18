"""
ComplyEdge Python SDK

A Python client library for the ComplyEdge Compliance API.
Provides both simple and advanced interfaces for AI agent compliance checking.

Basic Usage (Simple Interface):
    from complyedge import ComplyEdge, is_safe, check

    # Option 1: Class instance
    ce = ComplyEdge(api_key="your-key")
    if ce.is_safe("Some text"):
        print("Safe to use")

    # Option 2: Global functions
    if is_safe("Some text", api_key="your-key"):
        print("Safe to use")

    result = check("Some text", api_key="your-key")
    print(f"Safe: {result.safe}, Reason: {result.reason}")

Advanced Usage (Full Interface):
    from complyedge import ComplyEdgeClient, AsyncComplyEdgeClient

    # Synchronous client
    with ComplyEdgeClient(api_key="your-key") as client:
        result = client.check_compliance(
            text="Your AI agent output text",
            agent_id="my-bot",
            jurisdiction="EU"
        )

    # Asynchronous client
    async with AsyncComplyEdgeClient(api_key="your-key") as client:
        result = await client.check_compliance(
            text="Your AI agent output text",
            agent_id="my-bot"
        )
"""

# PEP 604 unions (str | None) are evaluated at def time, so this module
# raised TypeError on import under Python 3.9 while pyproject, the PyPI
# classifiers and the quick-start all advertised 3.9 support. Reproduced
# on 3.9.19 at __init__.py:92. Do not remove without dropping 3.9.
from __future__ import annotations

import json
import os
import time
import unicodedata
from datetime import datetime, timedelta, timezone
from collections.abc import Callable
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Literal
from urllib.parse import quote

import httpx
from tenacity import (
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)

__version__ = "0.2.27"

# Default API URL — set via COMPLYEDGE_API_URL env var or explicit config
DEFAULT_BASE_URL = os.getenv("COMPLYEDGE_API_URL")

# ComplyEdge runs two regions. A tenant lives in exactly one of them.
# The key says which host to call. It does not move the account.
#   ce_eu_  -> EU (eu.api.complyedge.io).
#   ce_     -> US (api.complyedge.io).
# The region is chosen when the API key is created (EU preselected); changing
# it later goes through support and issues a new key. No key, or a key with
# neither prefix, goes to EU. Setting COMPLYEDGE_API_URL does not change the
# account's home.
Region = Literal["us", "eu"]

REGION_BASE_URLS: dict[str, str] = {
    "us": "https://api.complyedge.io",
    "eu": "https://eu.api.complyedge.io",
}

_KEY_PREFIX_REGIONS: tuple[tuple[str, str], ...] = (
    ("ce_eu_", "eu"),  # longest prefix first: ce_eu_ also starts with ce_
    ("ce_", "us"),
)


def region_from_api_key(api_key: str | None) -> Region | None:
    """Region an API key was issued in, read from its prefix; None if unknown."""
    if not api_key:
        return None
    for prefix, region in _KEY_PREFIX_REGIONS:
        if api_key.startswith(prefix):
            return region  # type: ignore[return-value]
    return None


def resolve_base_url(
    api_key: str | None = None,
    base_url: str | None = None,
    region: str | None = None,
) -> str:
    """Pick the API host. Precedence, highest first:

    1. ``base_url`` argument
    2. ``COMPLYEDGE_API_URL`` environment variable
    3. ``region`` argument, else ``COMPLYEDGE_REGION`` environment variable
    4. the region encoded in the API key prefix (``ce_eu_`` -> EU, ``ce_`` -> US)
    5. EU
    """
    if base_url:
        return base_url.rstrip("/")
    env_url = os.getenv("COMPLYEDGE_API_URL")
    if env_url:
        return env_url.rstrip("/")
    chosen = (region or os.getenv("COMPLYEDGE_REGION") or "").strip().lower()
    if chosen:
        if chosen not in REGION_BASE_URLS:
            raise ValueError(
                f"Unknown ComplyEdge region {chosen!r}; expected one of {sorted(REGION_BASE_URLS)}"
            )
        return REGION_BASE_URLS[chosen]
    inferred = region_from_api_key(api_key)
    return REGION_BASE_URLS[inferred or "eu"]


# Decorator functionality will be imported at the end to avoid circular imports

# =============================================================================
# CORE DATA MODELS
# =============================================================================


class SeverityLevel(str, Enum):
    """Severity levels for compliance violations."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class DirectionType(str, Enum):
    """Direction of text flow for compliance checking."""

    PROMPT = "prompt"  # Input from user to AI
    OUTPUT = "output"  # Output from AI to user
    ACTION = "action"  # An action the AI system is about to take


@dataclass
class ComplianceViolation:
    """A compliance violation detected in text."""

    rule_id: str
    rule_description: str
    severity: SeverityLevel
    reason: str
    confidence: float
    text_excerpt: str | None = None


#: ``use_case`` value that turns on the companion chatbot laws (California
#: SB 243 and AB 1064, New York Art. 47 and 48, Washington, Oregon).
COMPANION_USE_CASE = "companion_chatbot"


@dataclass
class RequiredAction:
    """Something a companion check tells your app to do for this message.

    ``action`` is the action code (for example ``show_crisis_referral`` or
    ``show_break_reminder``). ``due_at`` is when it was due (ISO 8601 UTC).
    ``interval_key`` names the due interval: send it back with
    ``confirm_action`` once your app has shown the notice. ``counted`` is
    False for actions the law recommends but does not count as missed
    (and for ``block_reply``, ``disable_prior_personal_memory`` and
    ``disable_push_notifications``, which are applied in the response and
    never confirmed, and ``preserve_conversation``, recorded with
    ``preserve``).
    """

    action: str
    rule_ids: list[str] = field(default_factory=list)
    jurisdiction: str | None = None
    reason_code: str | None = None
    due_at: str | None = None
    interval_key: str | None = None
    counted: bool = False


@dataclass
class CompanionActionReceipt:
    """Answer of ``POST /v1/companion/action``."""

    event_id: str
    event_type: str
    confirm_key: str | None
    # True when this confirmation was already recorded (a retry): nothing new
    # was written and event_id is the first row's.
    duplicate: bool


@dataclass
class PreservationReceipt:
    """Answer of ``POST /v1/companion/preservation``."""

    event_id: str
    timestamp: str | None
    event_type: str
    # What California § 21812.5 still asks of you: "retain_account", and for a
    # death or serious self-harm "notify_parent_if_practicable".
    account_duties: list[str] = field(default_factory=list)


def _required_actions_from_payload(
    data: dict[str, Any], key: str = "required_actions"
) -> list[RequiredAction]:
    out: list[RequiredAction] = []
    for entry in data.get(key) or []:
        if not isinstance(entry, dict) or not entry.get("action"):
            continue
        out.append(
            RequiredAction(
                action=str(entry["action"]),
                rule_ids=[str(r) for r in (entry.get("rule_ids") or [])],
                jurisdiction=entry.get("jurisdiction"),
                reason_code=entry.get("reason_code"),
                due_at=entry.get("due_at"),
                interval_key=entry.get("interval_key"),
                counted=entry.get("counted") is True,
            )
        )
    return out


def _companion_fields(data: dict[str, Any]) -> dict[str, Any]:
    """Companion response fields; absent (an older API) parses as empty."""
    return {
        "companion_assessment": data.get("companion_assessment"),
        "companion_not_assessed_reason": data.get("companion_not_assessed_reason"),
        "companion_fallback": data.get("companion_fallback") is True,
        "required_actions": _required_actions_from_payload(data),
        "upcoming_actions": _required_actions_from_payload(data, "upcoming_actions"),
    }


@dataclass
class ComplianceResult:
    """Result of a compliance check."""

    event_id: str
    allowed: bool
    violations: list[ComplianceViolation]
    latency_ms: int
    bundle_version: str
    evaluated_rules: list[str]
    # Keyed hash (HMAC-SHA-256 under the account's own key) of the evaluated
    # text and the UTC instant of evaluation, both byte-identical to this
    # event's Article 12 audit entry. The key never leaves ComplyEdge, so the
    # hash cannot be reversed by hashing guesses; check a text against it with
    # verify_input(). Defaulted so older API responses still deserialize.
    text_hash: str = ""
    timestamp: str | None = None
    # "hmac-sha256-1" (HMAC over "commitment:" + the text). None on responses
    # from an API deployed before the keyed hash, whose text_hash is a plain
    # SHA-256.
    text_hash_alg: str | None = None
    # SHA-256 digest of the rule set that decided, byte-identical to the audit
    # entry's bundle_digest and to the ADCR record's rule_set.digest; the rule
    # set's page is https://complyedge.io/rule-set/<digest>/. None on responses
    # from an API that does not return it.
    bundle_digest: str | None = None
    # Hot-path provenance from /v1/check. Defaulted so older mocks / API
    # responses that omit them still deserialize. Mapped in every check()
    # path — dropping these was the contract gap that left CI blind.
    engine_path: str = ""
    audit_logged: bool = False
    # True when the decision came from /v1/sandbox/check: same verdict, no
    # audit entry, no usage, no count against the plan's daily limit (own
    # caps: 60 a minute, 1,000 a day). Never evidence.
    sandbox: bool = False
    # Companion chatbot checks (use_case="companion_chatbot") only. None /
    # False / [] on every other check and on an API that predates them.
    # "assessed" or "not_assessed"; not_assessed is never a clean pass.
    companion_assessment: str | None = None
    # plan, budget, unavailable, no_direction or no_session.
    companion_not_assessed_reason: str | None = None
    # True when ComplyEdge could not work out the actions for this message:
    # apply your own protocol to it.
    companion_fallback: bool = False
    required_actions: list[RequiredAction] = field(default_factory=list)
    # Periodic notices (break reminder, repeated not-human notice) this session
    # will owe that are not due yet. Show each one by its due_at even when no
    # message arrives; when a later check lists it in required_actions, confirm
    # it with the time it was shown. No interval_key until then.
    upcoming_actions: list[RequiredAction] = field(default_factory=list)

    @property
    def safe(self) -> bool:
        """True if text is safe (no violations)."""
        return self.allowed

    @property
    def blocked(self) -> bool:
        """True if text is blocked (has violations)."""
        return not self.allowed

    @property
    def violation_count(self) -> int:
        """Number of violations found."""
        return len(self.violations)

    @property
    def reason(self) -> str | None:
        """Human-readable reason for the decision."""
        if self.allowed:
            return None
        if self.violations:
            return self.violations[0].rule_description
        return "Blocked by compliance system"


class ComplianceError(Exception):
    """Exception raised when compliance checking fails."""

    def __init__(
        self,
        message: str,
        violations: list[ComplianceViolation] | None = None,
        event_id: str | None = None,
        retryable: bool = False,
        code: str | None = None,
    ):
        # `retryable` exists because the retry decorator on check_compliance was
        # dead code: it was configured to retry httpx.RequestError and
        # HTTPStatusError, but the method body catches both and re-raises
        # ComplianceError, so tenacity never saw a type it was watching and ZERO
        # retries ever fired. Transience has to survive the conversion.
        super().__init__(message)
        self.violations = violations or []
        self.event_id = event_id
        self.retryable = retryable
        #: The API's error code when it sends one (companion endpoints answer
        #: {"code", "message"}), e.g. "check_not_written_yet"; else None.
        self.code = code


# The retry decorators wait at most this long between attempts
# (wait_exponential max=10). A 429 that asks for longer cannot clear inside
# the retry budget, so retrying it only adds delay and doomed requests.
_RETRY_MAX_WAIT_SECONDS = 10.0


_FINAL_ERROR_CODES = frozenset({"review_not_recorded"})


def _status_is_retryable(response: httpx.Response) -> bool:
    """5xx always; 429 only when the server's wait fits the retry budget.

    The daily check cap (error "rate_limit_exceeded") resets at 00:00 UTC, so
    it is never retried: three attempts over ~14s only delayed the caller and
    sent two more requests that were certain to be refused. Older API builds
    sent that 429 an ISO timestamp in Retry-After, so the error code is
    checked first and an unparseable Retry-After is treated as "not soon".
    """
    status = response.status_code
    # A server error the API marks as final: retrying cannot succeed
    # (review_not_recorded: the account's audit key is unavailable).
    if _error_code(response) in _FINAL_ERROR_CODES:
        return False
    if 500 <= status < 600:
        return True
    if status != 429:
        return False
    try:
        detail = response.json().get("detail")
    except Exception:
        detail = None
    if isinstance(detail, dict) and detail.get("error") == "rate_limit_exceeded":
        return False
    retry_after = response.headers.get("Retry-After")
    if retry_after is None:
        return True
    try:
        return float(retry_after) <= _RETRY_MAX_WAIT_SECONDS
    except ValueError:
        return False


#: The user attribution fields the API records on every audit entry
#: (AuditLogEntry.user_id / user_role / session_id). They reach the record
#: only through the request's `context`; a caller that sends none leaves those
#: audit columns blank on every row.
ATTRIBUTION_FIELDS = ("user_id", "user_role", "session_id")


def _attribution_context(
    context: dict[str, Any] | None,
    **attribution: str | None,
) -> dict[str, Any] | None:
    """Merge explicit attribution into `context`; explicit values win.

    None means "not given" and never overwrites a value already in context.
    Returns None when there is nothing to send, so the request body is
    unchanged for callers who pass no attribution.
    """
    merged = dict(context or {})
    for key in ATTRIBUTION_FIELDS:
        value = attribution.get(key)
        if value is not None:
            merged[key] = str(value)
    return merged or None


def _allowed_from_payload(data: dict[str, Any]) -> bool:
    """Missing ``allowed`` is a block, never a pass.

    The parse sites used to default True, so a 200 with a truncated body
    (or a proxy that dropped the field) looked like a clean check.
    ``bool()`` still treated ``"false"`` and ``1`` as a pass. TypeScript
    requires ``=== true``; match that.
    """
    return data.get("allowed") is True


def _check_path(sandbox: bool) -> str:
    """/v1/sandbox/check evaluates with the tenant's real rules and settings
    but records nothing: no audit entry, no usage, no count against the plan's daily
    limit (own caps: 60 a minute, 1,000 a day). For trying cases, never for production traffic.
    """
    return "/v1/sandbox/check" if sandbox else "/v1/check"


def _direction_value(direction: Any) -> str | None:
    if direction is None:
        return None
    return direction.value if hasattr(direction, "value") else str(direction)


def _finish_check_request(
    request_data: dict[str, Any],
    direction: Any,
    use_case: str | None,
    companion_user_message: str | None = None,
) -> None:
    """Add ``direction``, ``use_case`` and ``companion_user_message`` only when
    given, then refuse an incomplete companion check before anything is sent.

    ``companion_user_message`` (the user's last message before a companion
    reply) is accepted only on a companion check judged as "output"; the API
    answers 422 otherwise, so it is refused here first.

    ``direction`` used to default to "output", so a caller who forgot it had
    every user message judged as a bot reply. The API still defaults it to
    "output" for ordinary checks; a companion check needs it said.
    """
    value = _direction_value(direction)
    if value is not None:
        request_data["direction"] = value
    if use_case is not None:
        request_data["use_case"] = use_case
    if companion_user_message is not None:
        if use_case != COMPANION_USE_CASE or value != "output":
            raise ValueError(
                "companion_user_message is accepted only with "
                "use_case='companion_chatbot' and direction='output'; nothing was sent."
            )
        request_data["companion_user_message"] = companion_user_message
    if use_case != COMPANION_USE_CASE:
        return
    missing = []
    if value is None:
        missing.append(
            "direction ('prompt' for the user's message, 'output' for the bot's reply)"
        )
    if not (request_data.get("context") or {}).get("session_id"):
        missing.append("session_id")
    if missing:
        raise ValueError(
            "A companion_chatbot check needs " + " and ".join(missing)
            + "; nothing was sent."
        )


def _audit_logged_from_payload(data: dict[str, Any]) -> bool:
    """Missing ``audit_logged`` is not a logged event.

    The parse sites used to default True, so a truncated 200 claimed an
    Article 12 write that the body never confirmed. TypeScript already
    requires ``=== true``.
    """
    return data.get("audit_logged") is True


# =============================================================================
# SIMPLE INTERFACE (recommended for most users)
# =============================================================================


def _iso_utc(value: "datetime | str | None") -> str:
    """An ISO 8601 UTC stamp; now when value is None. Naive datetimes are UTC."""
    if value is None:
        value = datetime.now(timezone.utc)
    if isinstance(value, str):
        return value
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


# Tests replace these to run the confirmation retry without waiting.
_sleep = time.sleep


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _parse_iso(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


#: How long after a check's timestamp a confirmation keeps retrying while the
#: check row is still being written (409 check_not_written_yet).
CONFIRM_RETRY_WINDOW = timedelta(minutes=10)

_CONVERSATION_KEYS = ("role", "sent_at", "text")


def _jcs(value: Any) -> str:
    """RFC 8785 (JSON Canonicalization Scheme) for strings, lists, objects,
    booleans and null: keys sorted, no insignificant whitespace, strings
    escaped as ECMAScript JSON.stringify does (which json.dumps with
    ensure_ascii=False matches). Numbers are refused: nothing sent here has
    one, and Python's float text differs from ECMAScript's.
    """
    if value is None or isinstance(value, (bool, str)):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(_jcs(v) for v in value) + "]"
    if isinstance(value, dict):
        # RFC 8785 sorts by UTF-16 code units; every key here is ASCII.
        keys = sorted(value, key=lambda k: str(k).encode("utf-16-be"))
        return "{" + ",".join(f"{json.dumps(str(k), ensure_ascii=False)}:{_jcs(value[k])}" for k in keys) + "}"
    raise TypeError(f"Cannot canonicalise {type(value).__name__}")


def _iso_ms(value: datetime) -> str:
    """Same text as JavaScript Date.toISOString(), so both SDKs agree."""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    value = value.astimezone(timezone.utc)
    return value.strftime("%Y-%m-%dT%H:%M:%S.") + f"{value.microsecond // 1000:03d}Z"


def canonical_conversation(conversation: "list[dict[str, Any]] | str") -> bytes:
    """The conversation in the one form ComplyEdge commits to: a JSON array of
    ``{role, text, sent_at}``, text in Unicode NFC, serialised by RFC 8785.

    Accepts a list of dicts or a JSON string. Whitespace, key order and
    Unicode composition in the input do not change the result, so a copy kept
    elsewhere can be checked later whatever its formatting. ``sent_at`` may be
    a datetime (written as ``2026-11-14T20:01:02.345Z``) or a string, kept as
    given. Any other key is refused rather than dropped.
    """
    if isinstance(conversation, str):
        conversation = json.loads(conversation)
    if not isinstance(conversation, list):
        raise ValueError("conversation must be a list of {role, text, sent_at}")
    entries = []
    for i, message in enumerate(conversation):
        if not isinstance(message, dict):
            raise ValueError(f"conversation[{i}] must be an object")
        extra = sorted(set(message) - set(_CONVERSATION_KEYS))
        missing = [k for k in _CONVERSATION_KEYS if k not in message]
        if extra or missing:
            raise ValueError(
                f"conversation[{i}] must have exactly role, text and sent_at"
                + (f"; unexpected: {', '.join(extra)}" if extra else "")
                + (f"; missing: {', '.join(missing)}" if missing else "")
            )
        sent_at = message["sent_at"]
        if isinstance(sent_at, datetime):
            sent_at = _iso_ms(sent_at)
        for key, val in (("role", message["role"]), ("text", message["text"]), ("sent_at", sent_at)):
            if not isinstance(val, str):
                raise ValueError(f"conversation[{i}].{key} must be a string")
        entries.append(
            {
                "role": message["role"],
                "sent_at": sent_at,
                "text": unicodedata.normalize("NFC", message["text"]),
            }
        )
    return _jcs(entries).encode("utf-8")


def _error_code(response: httpx.Response) -> str | None:
    """The API's error code, at the top level or under FastAPI's ``detail``."""
    try:
        data = response.json()
    except Exception:
        return None
    if not isinstance(data, dict):
        return None
    if isinstance(data.get("code"), str):
        return data["code"]
    detail = data.get("detail")
    if isinstance(detail, dict):
        code = detail.get("code") or detail.get("error")
        return code if isinstance(code, str) else None
    return None


def _error_detail(e: "httpx.HTTPStatusError") -> str:
    """The API's own words: a message, or each field and what is wrong with it.

    Most endpoints answer {"detail": ...}; the companion endpoints answer
    {"code", "message"} with no detail, which used to come back as the bare
    httpx text with the code and message lost."""
    try:
        body = e.response.json()
    except Exception:
        return str(e)
    if isinstance(body, dict) and "detail" not in body and body.get("message"):
        code = body.get("code")
        return f"{code}: {body['message']}" if code else str(body["message"])
    detail = body.get("detail", str(e)) if isinstance(body, dict) else str(e)
    if isinstance(detail, dict):
        return str(detail.get("message") or detail)
    if isinstance(detail, list):
        parts = []
        for err in detail:
            if isinstance(err, dict):
                loc = ".".join(str(x) for x in err.get("loc", [])[1:]) or "body"
                parts.append(f"{loc}: {err.get('msg', '')}")
        return "; ".join(parts) or str(detail)
    return str(detail)


class ComplyEdge:
    """
    Simple synchronous client for ComplyEdge Compliance API.

    This is the recommended interface for most users.

    Example:
        ce = ComplyEdge(api_key="your-key")

        if ce.is_safe("Some text"):
            print("Safe to use")
        else:
            result = ce.check("Some text")
            print(f"Blocked: {result.reason}")
    """

    def __init__(
        self,
        api_key: str,
        agent_id: str = "default",
        jurisdiction: str | None = None,
        base_url: str | None = None,
        region: Region | None = None,
        user_id: str | None = None,
        user_role: str | None = None,
        session_id: str | None = None,
        receipt_journal: str | os.PathLike[str] | None = None,
    ):
        """
        Initialize ComplyEdge client.

        Args:
            api_key: Your ComplyEdge API key
            agent_id: Default agent identifier
            user_id: Default person the agent acts for, recorded on every
                audit entry. Per-call values in check() override it.
            user_role: Default role of that person (e.g. 'support_agent').
            session_id: Default conversation, run or job identifier.
            jurisdiction: Regulatory jurisdiction (e.g., 'EU', 'US')
            base_url: API base URL (overrides region and key inference)
            region: "us" or "eu". Defaults to the region encoded in the API
                key prefix (ce_eu_ -> EU, ce_ -> US), else EU. A region or
                base_url argument picks a host and does not move the account.
                See resolve_base_url().
            receipt_journal: Optional path to an append-only JSONL file of
                check linkage (event_id, text_hash, digests). Never stores
                the prompt. See ``complyedge.receipt_journal.ReceiptJournal``.
        """
        self.api_key = api_key
        self.agent_id = agent_id
        self.jurisdiction = jurisdiction
        self.user_id = user_id
        self.user_role = user_role
        self.session_id = session_id
        self.base_url = resolve_base_url(api_key, base_url, region)
        self._receipt_journal = None
        if receipt_journal is not None:
            from complyedge.receipt_journal import ReceiptJournal

            self._receipt_journal = ReceiptJournal(receipt_journal)

        self._client = httpx.Client(
            base_url=self.base_url,
            timeout=300,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"complyedge-python-sdk/{__version__}",
            },
        )

    def is_safe(
        self, text: str, decision_context: dict[str, Any] | None = None
    ) -> bool:
        """
        Check if text is safe to use (no compliance violations).

        Args:
            text: Text to check
            decision_context: ADCR decision context for the record (see check()).

        Returns:
            True if safe, False if blocked

        Example:
            if ce.is_safe("Hello world"):
                print("Safe to use")
        """
        try:
            result = self.check(text, decision_context=decision_context)
            return result.safe
        except Exception:
            # Conservative: assume unsafe if check fails
            return False

    def check(
        self,
        text: str,
        agent_id: str | None = None,
        jurisdiction: str | None = None,
        direction: str | None = None,
        sandbox: bool = False,
        user_id: str | None = None,
        user_role: str | None = None,
        session_id: str | None = None,
        decision_context: dict[str, Any] | None = None,
        use_case: str | None = None,
        context: dict[str, Any] | None = None,
        companion_user_message: str | None = None,
        use_semantic_fallback: bool = False,
    ) -> ComplianceResult:
        """
        Check text for compliance violations.

        Args:
            text: Text to check
            agent_id: Agent identifier (uses default if not provided)
            user_id: Person the agent acts for (uses the client default if not
                provided). Recorded on the audit entry.
            user_role: That person's role (uses the client default if not provided).
            session_id: Conversation, run or job identifier (uses the client
                default if not provided).
            decision_context: What you know about the decision that ComplyEdge
                cannot, written to the audit record as ADCR fields.
                Optional; when sent, the API requires deciding_system.version,
                purpose_ref and data_categories (use [] when none). Without it
                the check runs, but its record does not meet ADCR class Record.
            jurisdiction: Regulatory jurisdiction (uses default if not provided)
            sandbox: Evaluate without recording (POST /v1/sandbox/check). Same
                verdict, no audit entry, no usage, no count against the plan's
                daily limit (own caps: 60 a minute, 1,000 a day). For trying cases; the
                result is never evidence.
            direction: "prompt" for text going INTO the model, "output" for text
                coming out, "action" for an action the AI is about to take.
                Sent only when given; the API then treats the text as
                "output". Required on a companion check.
            use_case: "companion_chatbot" turns on the companion chatbot laws
                for this check. Such a check needs ``direction`` and a
                ``session_id`` (argument, client default or context) and is
                refused before sending without them. Other values are sent as
                given.
            context: Extra context sent with the check, such as the companion
                keys (age_status, age_source, is_session_start,
                session_started_at, minutes_today, ...). user_id, user_role
                and session_id given as arguments override the same keys here.
            companion_user_message: On a companion check with direction
                "output" only: the user's last message before this reply, so
                the reply judge sees what the reply answers. Context only;
                never stored. Refused before sending on any other check.
            use_semantic_fallback: Ask for the wider review. On a paying
                tenant it lets the model check clear a phrase-rule hit that is
                only about the topic. Default False: phrase rules only. A
                tenant with force_semantic_fallback gets the review either way.

        Returns:
            ComplianceResult with detailed information

        Example:
            result = ce.check("Some text")
            if result.safe:
                print("Safe")
            else:
                print(f"Blocked: {result.reason}")
        """
        request_data: dict[str, Any] = {
            "text": text,
            "jurisdiction": jurisdiction or self.jurisdiction or "EU",
            "agent_id": agent_id or self.agent_id,
            "use_semantic_fallback": use_semantic_fallback,
        }
        merged = dict(context or {})
        context = _attribution_context(
            merged,
            user_id=user_id
            if user_id is not None
            else (None if "user_id" in merged else self.user_id),
            user_role=user_role
            if user_role is not None
            else (None if "user_role" in merged else self.user_role),
            session_id=session_id
            if session_id is not None
            else (None if "session_id" in merged else self.session_id),
        )
        if context:
            request_data["context"] = context
        if decision_context:
            request_data["decision_context"] = decision_context
        _finish_check_request(request_data, direction, use_case, companion_user_message)

        try:
            response = self._client.post(_check_path(sandbox), json=request_data)
            response.raise_for_status()
            data = response.json()

            violations = [
                ComplianceViolation(
                    rule_id=v.get("rule_id", "UNKNOWN"),
                    rule_description=v.get("rule_description", ""),
                    severity=SeverityLevel(v.get("severity", "medium").lower()),
                    reason=v.get("reason", ""),
                    confidence=v.get("confidence", 1.0),
                    text_excerpt=v.get("text_excerpt"),
                )
                for v in data.get("violations", [])
            ]

            result = ComplianceResult(
                event_id=data["event_id"],
                allowed=_allowed_from_payload(data),
                violations=violations,
                latency_ms=data.get("latency_ms", 0),
                bundle_version=data.get("bundle_version", "unknown"),
                evaluated_rules=data.get("evaluated_rules", []),
                text_hash=data.get("text_hash", ""),
                text_hash_alg=data.get("text_hash_alg"),
                bundle_digest=data.get("bundle_digest"),
                timestamp=data.get("timestamp"),
                engine_path=data.get("engine_path", ""),
                audit_logged=_audit_logged_from_payload(data),
                sandbox=data.get("sandbox") is True,
                **_companion_fields(data),
            )
            if self._receipt_journal is not None:
                self._receipt_journal.append_result(result)
            return result

        except httpx.HTTPStatusError as e:
            try:
                error_data = e.response.json()
                error_detail = error_data.get("detail", str(e))
            except Exception:
                error_detail = str(e)

            # 5xx and short 429s are transient; 4xx client errors and the
            # daily cap are not and must not burn the retry budget.
            status = e.response.status_code
            raise ComplianceError(
                f"API error ({status}): {error_detail}",
                retryable=_status_is_retryable(e.response),
            ) from e

        except httpx.RequestError as e:
            # Connection errors, DNS failures and timeouts are transient.
            raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e

    def assess_pre_deployment(
        self,
        system_prompt: str,
        model_config: dict[str, Any] | None = None,
        agent_pipeline: dict[str, Any] | None = None,
        jurisdiction: str = "EU",
    ) -> dict[str, Any]:
        """
        Assess an AI system configuration against EU AI Act requirements
        BEFORE deployment.

        Args:
            system_prompt: The system prompt of the AI agent
            model_config: Model configuration (provider, model_id, temperature)
            agent_pipeline: Pipeline configuration (tools, memory, autonomy_level)
            jurisdiction: Regulatory jurisdiction (default: EU)

        Returns:
            Dict with compliance_score, risk_tier, violations, required_disclosures,
            eu_ai_act_category, estimated_deadline

        Example:
            result = ce.assess_pre_deployment(
                system_prompt="You are a hiring assistant...",
                model_config={"provider": "openai", "model_id": "gpt-4"},
                agent_pipeline={"tools": ["resume_scorer"], "autonomy_level": "full"},
            )
            print(f"Risk: {result['risk_tier']}, Score: {result['compliance_score']}")
        """
        request_data: dict[str, Any] = {
            "system_prompt": system_prompt,
            "jurisdiction": jurisdiction,
        }
        if model_config:
            request_data["model_config"] = model_config
        if agent_pipeline:
            request_data["agent_pipeline"] = agent_pipeline

        try:
            response = self._client.post(
                "/v1/assessment/pre-deployment", json=request_data
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            try:
                error_detail = e.response.json().get("detail", str(e))
            except Exception:
                error_detail = str(e)
            raise ComplianceError(
                f"API error ({e.response.status_code}): {error_detail}"
            )
        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}")

    def verify_input(self, event_id: str, text: str) -> bool:
        """True when the audit record ``event_id`` was a decision about exactly ``text``.

        The record's text_hash is keyed with the account's key, which never
        leaves ComplyEdge, so the comparison runs server-side
        (POST /v1/audit/verify). The text is used for that request only: it is
        not stored and not logged. False also when the account's key was
        destroyed (crypto-shred). An unknown event_id raises ComplianceError.
        """
        try:
            response = self._client.post(
                "/v1/audit/verify", json={"event_id": event_id, "text": text}
            )
            response.raise_for_status()
            return response.json().get("match") is True
        except httpx.HTTPStatusError as e:
            try:
                error_detail = e.response.json().get("detail", str(e))
            except Exception:
                error_detail = str(e)
            raise ComplianceError(
                f"API error ({e.response.status_code}): {error_detail}",
                retryable=_status_is_retryable(e.response),
            ) from e
        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e

    # --- Appeals: a person's request about a decision, and your answer ------
    # Enterprise plan. The request returns an id; keep it on your support
    # ticket, and send it with the answer when the ticket closes.
    # References (decision_id, statement_ref, reviewer) are ids, never text:
    # no spaces, no email addresses, no secrets. Guide:
    # https://complyedge.io/docs/appeals.html

    def record_appeal(
        self,
        decision_id: str,
        kind: str,
        *,
        requested_at: datetime | str | None = None,
        system_version: str | None = None,
        agent_id: str | None = None,
    ) -> str:
        """Record that a person asked about a decision; returns the request id.

        Args:
            decision_id: The ``event_id`` ComplyEdge returned for the decision.
            kind: What the person asked for. ``human_intervention`` (a person
                should look at it), ``express_view`` (give their side),
                ``contest`` (they dispute it), ``explanation`` (how and why
                the AI decided), ``correction`` (data it used is wrong) or
                ``review`` (a review under another law, which sets its own
                deadline). If unsure, ``human_intervention``.
            requested_at: When the person asked, such as your ticket's created
                time. The one-month deadline runs from here. Defaults to now.
            system_version: Version of the AI system that decided. Read from
                the decision when omitted; required only if the decision was
                sent without one.
            agent_id: The agent that decided. Read from the decision when
                omitted.

        Safe to retry with the same ``requested_at``: the same request is
        recorded once and its id is returned again. Keep the id on your
        ticket and pass it to ``record_answer``.
        """
        body: dict[str, Any] = {
            "decision_ref": decision_id,
            "request_kind": kind,
            "requested_at": _iso_utc(requested_at),
        }
        if agent_id:
            body["agent_id"] = agent_id
        if system_version:
            body["deciding_system"] = {"version": system_version}
        data = self._post_json("/v1/audit/contest", body)
        return str(data["event_id"])

    def record_answer(
        self,
        request_id: str,
        outcome: str,
        *,
        statement_ref: str,
        reviewer: str,
        responded_at: datetime | str | None = None,
        rectified_at: datetime | str | None = None,
    ) -> dict[str, Any]:
        """Record your answer to an appeal, by the id ``record_appeal`` returned.

        Args:
            request_id: The id ``record_appeal`` returned.
            outcome: ``upheld`` (the decision stands), ``rectified`` (you
                corrected the decision or the data it used), ``withdrawn``
                (the person withdrew), ``refused`` (you will not act on it;
                your reasons must tell the person they can complain to a
                supervisory authority and go to court) or ``extended`` (you
                told the person you need more time, with the reasons; not
                the answer, so send the real one later to the same id).
            statement_ref: Reference to the reply you sent the person, such
                as ``ticket:88213``. Never the text itself.
            reviewer: Who reviewed it, such as ``staff:4471``. An id, not an
                email address. Stored as a keyed pseudonym, never as sent.
            responded_at: When you answered. Defaults to now.
            rectified_at: When the decision was corrected. Required when
                outcome is ``rectified``.

        Sending the same answer again (a webhook retry) records nothing new;
        the response then has ``already_recorded: True``.
        """
        body: dict[str, Any] = {
            "review_outcome": outcome,
            "statement_ref": statement_ref,
            "reviewer": reviewer,
        }
        if responded_at is not None:
            body["responded_at"] = _iso_utc(responded_at)
        if rectified_at is not None:
            body["rectified_at"] = _iso_utc(rectified_at)
        return self._post_json(
            f"/v1/audit/reviews/{quote(request_id, safe='')}/answer", body
        )

    def list_appeals(self, status: str = "open") -> list[dict[str, Any]]:
        """Appeals on your account, late ones first.

        Args:
            status: ``open`` (no answer yet, oldest first), ``answered`` or
                ``all``.

        Each appeal has ``request_id``, ``decision_ref``, ``request_kind``,
        ``requested_at``, ``status``, ``answer`` and ``extension`` (the
        ones recorded last), ``answers`` and ``extensions`` (every one, oldest first; each
        extension with ``in_time``), ``due_at`` (end of the last day to answer;
        None for ``review``), ``late`` and ``answered_late`` (judged on the first
        answer). Use it for a job that flags late appeals, or to find a request id
        you did not keep.
        """
        data = self._get_json("/v1/audit/reviews", params={"status": status})
        return list(data.get("reviews") or [])

    def get_appeal(self, request_id: str) -> dict[str, Any]:
        """One appeal by its request id, with the decision it is about.

        Returns ``{"review": ..., "decision": ..., "decision_missing": bool}``.
        """
        return self._get_json(f"/v1/audit/reviews/{quote(request_id, safe='')}")

    # --- Companion chatbots: confirm a notice was shown; preserve a chat -----

    def confirm_action(
        self,
        required_action: RequiredAction | dict[str, Any] | None = None,
        check: ComplianceResult | None = None,
        *,
        confirmation_id: str,
        source: str,
        shown_at: datetime | str,
        action: str | None = None,
        session_id: str | None = None,
        jurisdiction: str | None = None,
        rule_id: str | None = None,
        format: str | None = None,
        agent_id: str | None = None,
        deciding_system_version: str | None = None,
        language: str | None = None,
        check_event_id: str | None = None,
        check_timestamp: str | None = None,
        interval_key: str | None = None,
    ) -> CompanionActionReceipt:
        """Record that your app showed a companion notice (POST /v1/companion/action).

        Pass the ``required_actions`` entry and the check result it came from,
        and the call fills ``action``, ``check_event_id``, ``check_timestamp``,
        ``interval_key``, ``jurisdiction`` and ``rule_id`` (the entry's first
        rule id) from them. Any of those given as an argument wins. For a
        notice ComplyEdge did not ask for (``minors_notice``), pass ``action``
        and no check.

        Args:
            confirmation_id: Your own id for this confirmation. Without a
                check, sending the same one again records nothing new
                (``duplicate`` is True). For an action a check asked for, the
                check and interval identify it, so any retry is a duplicate.
            source: ``complyedge`` (ComplyEdge's text was shown) or
                ``operator`` (your own text).
            shown_at: When the user saw it.
            session_id: Defaults to this client's session_id. Required.
            format: ``app``, ``browser`` or ``other`` (how the user reached
                the chatbot).

        The check is recorded a moment after it returns. While it is not
        there yet the API answers 409 ``check_not_written_yet``; this call
        retries with growing waits until 10 minutes after the check's
        timestamp, then raises ComplianceError.
        """
        entry: dict[str, Any] = {}
        if isinstance(required_action, RequiredAction):
            entry = {
                "action": required_action.action,
                "rule_ids": required_action.rule_ids,
                "jurisdiction": required_action.jurisdiction,
                "interval_key": required_action.interval_key,
            }
        elif isinstance(required_action, dict):
            entry = required_action
        rule_ids = entry.get("rule_ids") or []
        body: dict[str, Any] = {
            "confirmation_id": confirmation_id,
            "action": action or entry.get("action"),
            "source": source,
            "shown_at": _iso_utc(shown_at),
            "session_id": session_id or self.session_id,
            "agent_id": agent_id or self.agent_id,
            "jurisdiction": jurisdiction or entry.get("jurisdiction"),
            "rule_id": rule_id or (rule_ids[0] if rule_ids else None),
            "format": format,
            "deciding_system_version": deciding_system_version,
            "language": language,
            "check_event_id": check_event_id or (check.event_id if check else None),
            "check_timestamp": check_timestamp or (check.timestamp if check else None),
            "interval_key": interval_key or entry.get("interval_key"),
        }
        body = {k: v for k, v in body.items() if v is not None}
        for key in ("action", "session_id"):
            if key not in body:
                raise ValueError(f"confirm_action needs {key}; nothing was sent.")

        deadline = None
        if body.get("check_timestamp"):
            deadline = _parse_iso(body["check_timestamp"]) + CONFIRM_RETRY_WINDOW
        delay = 1.0
        while True:
            try:
                response = self._client.post("/v1/companion/action", json=body)
            except httpx.RequestError as e:
                raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e
            if response.status_code == 409 and _error_code(response) == "check_not_written_yet":
                remaining = (
                    (deadline - _utcnow()).total_seconds() if deadline is not None else 0
                )
                if remaining <= 0:
                    raise ComplianceError(
                        "API error (409): check_not_written_yet; the check was not "
                        "recorded within 10 minutes of its timestamp"
                    )
                _sleep(min(delay, remaining))
                delay = min(delay * 2, 30.0)
                continue
            data = self._json_or_raise(response)
            return CompanionActionReceipt(
                event_id=str(data["event_id"]),
                event_type=str(data.get("event_type", "notice")),
                confirm_key=data.get("confirm_key"),
                duplicate=data.get("duplicate") is True,
            )

    def preserve(
        self,
        conversation: list[dict[str, Any]] | str,
        *,
        trigger: str,
        preserved_at: datetime | str,
        deciding_system_version: str,
        agent_id: str | None = None,
        session_id: str | None = None,
        user_id: str | None = None,
    ) -> PreservationReceipt:
        """Commit a conversation you must keep (POST /v1/companion/preservation).

        ComplyEdge keeps a keyed hash of the conversation, never its text.
        Before sending, the conversation is put in one canonical form (see
        ``canonical_conversation``), so the copy you keep verifies later
        whatever its whitespace or key order.

        Args:
            conversation: List of ``{role, text, sent_at}``, or that list as
                a JSON string.
            trigger: ``parent_notified``, ``child_died`` or
                ``serious_self_harm``.
            preserved_at: When you preserved it.
            deciding_system_version: Version of the chatbot's AI system.
            session_id / user_id: Default to this client's values; sent when set.
        """
        canonical = canonical_conversation(conversation).decode("utf-8")
        body: dict[str, Any] = {
            "trigger": trigger,
            "preserved_at": _iso_utc(preserved_at),
            "agent_id": agent_id or self.agent_id,
            "deciding_system_version": deciding_system_version,
            "session_id": session_id or self.session_id,
            "user_id": user_id or self.user_id,
            "conversation": json.loads(canonical),
        }
        body = {k: v for k, v in body.items() if v is not None}
        # Serialised here, by the same RFC 8785 writer, so the conversation
        # bytes on the wire are exactly the canonical bytes.
        try:
            response = self._client.post(
                "/v1/companion/preservation",
                content=_jcs(body).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e
        data = self._json_or_raise(response)
        return PreservationReceipt(
            event_id=str(data["event_id"]),
            timestamp=data.get("timestamp"),
            event_type=str(data.get("event_type", "preservation")),
            account_duties=[str(d) for d in data.get("account_duties") or []],
        )

    def _json_or_raise(self, response: httpx.Response) -> dict[str, Any]:
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise ComplianceError(
                f"API error ({e.response.status_code}): {_error_detail(e)}",
                retryable=_status_is_retryable(e.response),
                code=_error_code(e.response),
            ) from e
        return response.json()

    def _post_json(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        return self._send("POST", path, json=body)

    def _get_json(self, path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        return self._send("GET", path, params=params)

    def _send(self, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
        try:
            response = self._client.request(method, path, **kwargs)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            raise ComplianceError(
                f"API error ({e.response.status_code}): {_error_detail(e)}",
                retryable=_status_is_retryable(e.response),
                code=_error_code(e.response),
            ) from e
        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e

    def close(self):
        """Close the HTTP client."""
        self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


# Global convenience functions
def is_safe(
    text: str,
    api_key: str,
    agent_id: str = "default",
    jurisdiction: str | None = None,
    base_url: str | None = None,
    region: Region | None = None,
    user_id: str | None = None,
    user_role: str | None = None,
    session_id: str | None = None,
    decision_context: dict[str, Any] | None = None,
) -> bool:
    """
    Global convenience function to check if text is safe.

    Args:
        text: Text to check
        api_key: ComplyEdge API key
        agent_id: Agent identifier
        jurisdiction: Regulatory jurisdiction
        base_url: API base URL (overrides region and key inference)
        region: "us" or "eu"; defaults to the key's region prefix, else EU
        decision_context: ADCR decision context for the record (see
            ComplyEdge.check). Optional.

    Returns:
        True if safe, False if blocked

    Example:
        from complyedge import is_safe

        if is_safe("Hello world", api_key="your-key"):
            print("Safe to use")
    """
    client = ComplyEdge(
        api_key=api_key,
        agent_id=agent_id,
        jurisdiction=jurisdiction,
        base_url=base_url,
        region=region,
        user_id=user_id,
        user_role=user_role,
        session_id=session_id,
    )
    try:
        return client.is_safe(text, decision_context=decision_context)
    finally:
        client.close()


def check(
    text: str,
    api_key: str,
    agent_id: str = "default",
    jurisdiction: str | None = None,
    base_url: str | None = None,
    region: Region | None = None,
    sandbox: bool = False,
    user_id: str | None = None,
    user_role: str | None = None,
    session_id: str | None = None,
    decision_context: dict[str, Any] | None = None,
    direction: str | None = None,
    use_case: str | None = None,
    context: dict[str, Any] | None = None,
    companion_user_message: str | None = None,
    use_semantic_fallback: bool = False,
) -> ComplianceResult:
    """
    Global convenience function to check text compliance.

    Args:
        text: Text to check
        api_key: ComplyEdge API key
        agent_id: Agent identifier
        jurisdiction: Regulatory jurisdiction
        base_url: API base URL (overrides region and key inference)
        region: "us" or "eu"; defaults to the key's region prefix, else EU
        sandbox: Evaluate without recording (same verdict, no audit entry,
            no usage, no count against the plan's daily limit; own caps:
            60 a minute, 1,000 a day). For trying cases only.
        decision_context: ADCR decision context for the record (see
            ComplyEdge.check). Optional.
        direction, use_case, context: as on ComplyEdge.check. Sent only
            when given.
        companion_user_message: On a companion check with direction
            "output" only: the user's last message before this reply (see
            ComplyEdge.check).
        use_semantic_fallback: Ask for the wider review (see ComplyEdge.check).

    Returns:
        ComplianceResult with detailed information

    Example:
        from complyedge import check

        result = check("Some text", api_key="your-key")
        if result.safe:
            print("Safe")
        else:
            print(f"Blocked: {result.reason}")
    """
    client = ComplyEdge(
        api_key=api_key,
        agent_id=agent_id,
        jurisdiction=jurisdiction,
        base_url=base_url,
        region=region,
        user_id=user_id,
        user_role=user_role,
        session_id=session_id,
    )
    try:
        return client.check(
            text,
            sandbox=sandbox,
            decision_context=decision_context,
            direction=direction,
            use_case=use_case,
            context=context,
            companion_user_message=companion_user_message,
            use_semantic_fallback=use_semantic_fallback,
        )
    finally:
        client.close()


# =============================================================================
# ADVANCED INTERFACE (for power users and backward compatibility)
# =============================================================================


class ComplyEdgeClient:
    """
    Synchronous ComplyEdge client for compliance checking.

    This client provides a simple, synchronous interface to the ComplyEdge API.
    Perfect for quick integrations, testing, and scenarios where you don't need
    async/await patterns.

    Example:
        Basic usage:

        ```python
        from complyedge import ComplyEdgeClient

        client = ComplyEdgeClient(api_key="your-api-key")

        result = client.check_compliance(
            text="We expect revenue to increase by 25% next quarter",
            agent_id="financial-agent"
        )

        if result.allowed:
            print("Text is compliant")
        else:
            print(f"Found {len(result.violations)} violations")
        ```

        With context manager:

        ```python
        with ComplyEdgeClient(api_key="your-api-key") as client:
            result = client.check_compliance(
                text="Check this message",
                agent_id="my-agent"
            )
        ```

        except ComplianceError as e:
            print(f"Compliance check failed: {e}")
    """

    def __init__(
        self,
        api_key: str,
        base_url: str | None = None,
        timeout: int = 300,
        max_retries: int = 3,
        verify_ssl: bool = True,
        region: Region | None = None,
    ):
        """
        Initialize the ComplyEdge client.

        Args:
            api_key: Your ComplyEdge API key
            base_url: Base URL for the ComplyEdge API (overrides region and key inference)
            timeout: Request timeout in seconds
            max_retries: Maximum number of retry attempts
            verify_ssl: Whether to verify SSL certificates
            region: "us" or "eu"; defaults to the key's region prefix, else EU
        """
        self.api_key = api_key
        self.base_url = resolve_base_url(api_key, base_url, region)

        self.client = httpx.Client(
            base_url=self.base_url,
            timeout=timeout,
            verify=verify_ssl,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"complyedge-python-sdk/{__version__}",
            },
        )
        self.max_retries = max_retries

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def close(self):
        """Close the HTTP client."""
        self.client.close()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception(lambda e: getattr(e, "retryable", False)),
        # Surface the original ComplianceError once attempts are exhausted.
        # Without this tenacity raises RetryError, so a caller following the
        # documented contract ("Raises: ComplianceError") would miss it and the
        # retry machinery would leak through the SDK's own abstraction.
        reraise=True,
    )
    def check_compliance(
        self,
        text: str,
        agent_id: str,
        jurisdiction: str | None = None,
        direction: DirectionType | str | None = None,
        context: dict[str, Any] | None = None,
        use_semantic_fallback: bool = False,
        raise_on_violation: bool = False,
        sandbox: bool = False,
        user_id: str | None = None,
        user_role: str | None = None,
        session_id: str | None = None,
        decision_context: dict[str, Any] | None = None,
        use_case: str | None = None,
        companion_user_message: str | None = None,
    ) -> ComplianceResult:
        """
        Check text for compliance violations.

        Args:
            text: Text to evaluate for compliance
            agent_id: Identifier of the AI agent
            jurisdiction: Regulatory jurisdiction (e.g., 'EU', 'US', 'US-CA')
            direction: Whether this is a prompt, output or action. Sent only
                when given; the API then treats the text as output. Required
                when use_case is "companion_chatbot".
            context: Additional context for evaluation (for a companion check,
                the companion keys; session_id is required there)
            use_case: "companion_chatbot" turns on the companion chatbot laws;
                refused before sending without direction and session_id.
            companion_user_message: On a companion check with direction
                "output" only: the user's last message before this reply.
                Context for the reply judge; never stored. Refused before
                sending on any other check.
            user_id: Person the agent acts for; recorded on the audit entry.
                Overrides context["user_id"].
            user_role: That person's role. Overrides context["user_role"].
            session_id: Conversation, run or job identifier. Overrides
                context["session_id"].
            decision_context: Record fields only you know (deciding system
                version, purpose, data categories, ...), written to the audit
                record as ADCR fields. See the API reference.
            use_semantic_fallback: Wider legal review after the phrase rules pass.
                Defaults to False, so that review stays off. On a Developer or
                Enterprise plan the injection meaning check still runs after a
                clean pass when the month's model budget covers it, and it can
                block. If that budget is used up, the phrase rules decide.
                Set True to also run the wider review.
            raise_on_violation: Raise ComplianceError if violations are found
            sandbox: Evaluate without recording (POST /v1/sandbox/check). Same
                verdict, no audit entry, no usage, no count against the plan's
                daily limit (own caps: 60 a minute, 1,000 a day). For trying cases; the
                result is never evidence.

        Returns:
            ComplianceResult with decision and any violations

        Raises:
            ComplianceError: If compliance check fails or violations found
                           (when raise_on_violation=True)
        """
        try:
            request_data: dict[str, Any] = {
                "text": text,
                "jurisdiction": jurisdiction or "EU",
                "agent_id": agent_id,
                "use_semantic_fallback": use_semantic_fallback,
            }
            context = _attribution_context(
                context, user_id=user_id, user_role=user_role, session_id=session_id
            )
            if context:
                request_data["context"] = context
            if decision_context:
                request_data["decision_context"] = decision_context
            _finish_check_request(
                request_data, direction, use_case, companion_user_message
            )

            response = self.client.post(_check_path(sandbox), json=request_data)
            response.raise_for_status()
            data = response.json()

            violations = [
                ComplianceViolation(
                    rule_id=v.get("rule_id", "UNKNOWN"),
                    rule_description=v.get("rule_description", ""),
                    severity=SeverityLevel(v.get("severity", "medium").lower()),
                    reason=v.get("reason", ""),
                    confidence=v.get("confidence", 1.0),
                    text_excerpt=v.get("text_excerpt"),
                )
                for v in data.get("violations", [])
            ]

            result = ComplianceResult(
                event_id=data["event_id"],
                allowed=_allowed_from_payload(data),
                violations=violations,
                latency_ms=data.get("latency_ms", 0),
                bundle_version=data.get("bundle_version", "unknown"),
                evaluated_rules=data.get("evaluated_rules", []),
                text_hash=data.get("text_hash", ""),
                text_hash_alg=data.get("text_hash_alg"),
                bundle_digest=data.get("bundle_digest"),
                timestamp=data.get("timestamp"),
                engine_path=data.get("engine_path", ""),
                audit_logged=_audit_logged_from_payload(data),
                sandbox=data.get("sandbox") is True,
                **_companion_fields(data),
            )

            if raise_on_violation and not result.allowed:
                raise ComplianceError(
                    f"Compliance violations detected: {len(violations)} rule{'' if len(violations) == 1 else 's'} violated",
                    violations=violations,
                    event_id=result.event_id,
                )

            return result

        except httpx.HTTPStatusError as e:
            error_detail = "Unknown error"
            try:
                error_data = e.response.json()
                error_detail = error_data.get("detail", str(e))
            except Exception:
                pass

            # 5xx and short 429s are transient; 4xx client errors and the
            # daily cap are not and must not burn the retry budget.
            status = e.response.status_code
            raise ComplianceError(
                f"API error ({status}): {error_detail}",
                retryable=_status_is_retryable(e.response),
            ) from e

        except httpx.RequestError as e:
            # Connection errors, DNS failures and timeouts are transient.
            raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e

    def get_rules_info(self) -> dict[str, Any]:
        """Get information about the current rule bundle."""
        try:
            response = self.client.get("/v1/rules/info")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get rules info: {e}")

    def get_metrics(self) -> dict[str, Any]:
        """Get compliance metrics for your tenant."""
        try:
            response = self.client.get("/v1/metrics")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get metrics: {e}")


class AsyncComplyEdgeClient:
    """
    Async client for ComplyEdge Compliance API.

    This is the advanced async interface for power users.
    For simple use cases, use the ComplyEdge class instead.

    Example:
        async with AsyncComplyEdgeClient(api_key="your-key") as client:
            result = await client.check_compliance(
                text="Your AI agent output text",
                agent_id="my-bot"
            )

            if result.allowed:
                print("Text is compliant")
            else:
                print(f"Found {len(result.violations)} violations")
    """

    def __init__(
        self,
        api_key: str,
        base_url: str | None = None,
        timeout: int = 300,
        max_retries: int = 3,
        verify_ssl: bool = True,
        region: Region | None = None,
    ):
        """Initialize the async ComplyEdge client."""
        self.api_key = api_key
        self.base_url = resolve_base_url(api_key, base_url, region)

        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=timeout,
            verify=verify_ssl,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"complyedge-python-sdk/{__version__}",
            },
        )
        self.max_retries = max_retries

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception(lambda e: getattr(e, "retryable", False)),
        # Surface the original ComplianceError once attempts are exhausted.
        # Without this tenacity raises RetryError, so a caller following the
        # documented contract ("Raises: ComplianceError") would miss it and the
        # retry machinery would leak through the SDK's own abstraction.
        reraise=True,
    )
    async def check_compliance(
        self,
        text: str,
        agent_id: str,
        jurisdiction: str | None = None,
        direction: DirectionType | str | None = None,
        context: dict[str, Any] | None = None,
        use_semantic_fallback: bool = False,
        raise_on_violation: bool = False,
        sandbox: bool = False,
        user_id: str | None = None,
        user_role: str | None = None,
        session_id: str | None = None,
        decision_context: dict[str, Any] | None = None,
        use_case: str | None = None,
        companion_user_message: str | None = None,
    ) -> ComplianceResult:
        """Async version of check_compliance."""
        try:
            request_data: dict[str, Any] = {
                "text": text,
                "jurisdiction": jurisdiction or "EU",
                "agent_id": agent_id,
                "use_semantic_fallback": use_semantic_fallback,
            }
            context = _attribution_context(
                context, user_id=user_id, user_role=user_role, session_id=session_id
            )
            if context:
                request_data["context"] = context
            if decision_context:
                request_data["decision_context"] = decision_context
            _finish_check_request(
                request_data, direction, use_case, companion_user_message
            )

            response = await self.client.post(_check_path(sandbox), json=request_data)
            response.raise_for_status()
            data = response.json()

            violations = [
                ComplianceViolation(
                    rule_id=v.get("rule_id", "UNKNOWN"),
                    rule_description=v.get("rule_description", ""),
                    severity=SeverityLevel(v.get("severity", "medium").lower()),
                    reason=v.get("reason", ""),
                    confidence=v.get("confidence", 1.0),
                    text_excerpt=v.get("text_excerpt"),
                )
                for v in data.get("violations", [])
            ]

            result = ComplianceResult(
                event_id=data["event_id"],
                allowed=_allowed_from_payload(data),
                violations=violations,
                latency_ms=data.get("latency_ms", 0),
                bundle_version=data.get("bundle_version", "unknown"),
                evaluated_rules=data.get("evaluated_rules", []),
                text_hash=data.get("text_hash", ""),
                text_hash_alg=data.get("text_hash_alg"),
                bundle_digest=data.get("bundle_digest"),
                timestamp=data.get("timestamp"),
                engine_path=data.get("engine_path", ""),
                audit_logged=_audit_logged_from_payload(data),
                sandbox=data.get("sandbox") is True,
                **_companion_fields(data),
            )

            if raise_on_violation and not result.allowed:
                raise ComplianceError(
                    f"Compliance violations detected: {len(violations)} rule{'' if len(violations) == 1 else 's'} violated",
                    violations=violations,
                    event_id=result.event_id,
                )

            return result

        except httpx.HTTPStatusError as e:
            error_detail = "Unknown error"
            try:
                error_data = e.response.json()
                error_detail = error_data.get("detail", str(e))
            except Exception:
                pass

            # 5xx and short 429s are transient; 4xx client errors and the
            # daily cap are not and must not burn the retry budget.
            status = e.response.status_code
            raise ComplianceError(
                f"API error ({status}): {error_detail}",
                retryable=_status_is_retryable(e.response),
            ) from e

        except httpx.RequestError as e:
            # Connection errors, DNS failures and timeouts are transient.
            raise ComplianceError(f"Request failed: {str(e)}", retryable=True) from e

    async def get_rules_info(self) -> dict[str, Any]:
        """Get information about the current rule bundle."""
        try:
            response = await self.client.get("/v1/rules/info")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get rules info: {e}")

    async def get_metrics(self) -> dict[str, Any]:
        """Get compliance metrics for your tenant."""
        try:
            response = await self.client.get("/v1/metrics")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get metrics: {e}")


# =============================================================================
# BACKWARD COMPATIBILITY
# =============================================================================


def check_compliance(
    text: str, agent_id: str, api_key: str, jurisdiction: str | None = None, **kwargs
) -> ComplianceResult:
    """
    Quick compliance check without creating a client instance.

    DEPRECATED: Use ComplyEdge class or global check() function instead.

    Args:
        text: Text to check
        agent_id: Agent identifier
        api_key: ComplyEdge API key
        jurisdiction: Regulatory jurisdiction
        **kwargs: Additional arguments passed to check_compliance

    Returns:
        ComplianceResult
    """
    with ComplyEdgeClient(api_key=api_key) as client:
        return client.check_compliance(
            text=text, agent_id=agent_id, jurisdiction=jurisdiction, **kwargs
        )


# =============================================================================
# AUTO-CONFIGURATION FROM ENVIRONMENT
# =============================================================================


def get_api_key() -> str | None:
    """Get API key from environment variables."""
    return os.environ.get("COMPLYEDGE_API_KEY")


# Convenience instance with environment configuration
default_client: ComplyEdge | None
safe: Callable[[str], bool] | None
# Conditionally bound below; reassigned to the decorator import at module end.
compliance_check: Any

_env_api_key = get_api_key()
if _env_api_key:
    default_client = ComplyEdge(api_key=_env_api_key)
    _env_client = default_client

    def safe(text: str) -> bool:
        """Check if text is safe using environment-configured client."""
        return _env_client.is_safe(text)

    def compliance_check(text: str) -> ComplianceResult:
        """Check compliance using environment-configured client."""
        return _env_client.check(text)

else:
    default_client = None
    safe = None
    compliance_check = None


# Export public API
from complyedge.receipt_journal import ReceiptEntry, ReceiptJournal

__all__ = [
    # Simple interface (recommended)
    "ComplyEdge",
    "is_safe",
    "check",
    # Advanced interface
    "ComplyEdgeClient",
    "AsyncComplyEdgeClient",
    # Data models
    "ComplianceResult",
    "ComplianceViolation",
    "ComplianceError",
    "SeverityLevel",
    "DirectionType",
    # Companion chatbot laws
    "COMPANION_USE_CASE",
    "RequiredAction",
    "CompanionActionReceipt",
    "PreservationReceipt",
    "canonical_conversation",
    # Local check linkage; never stores prompt text
    "ReceiptJournal",
    "ReceiptEntry",
    # Decorator interface
    "compliance_check",
    "ComplianceConfig",
    "default_violation_handler",
    # Backward compatibility
    "check_compliance",
    # Environment helpers
    "get_api_key",
    "safe",
    # Region resolution (one stack per region; keys are region-bound)
    "Region",
    "REGION_BASE_URLS",
    "region_from_api_key",
    "resolve_base_url",
    # Agent integration module (import separately)
    # from complyedge.agents import create_compliance_guardrail
]

# Import decorator functionality after all classes are defined to avoid circular imports
from .decorators import (  # noqa: E402
    ComplianceConfig,
    compliance_check,
    default_violation_handler,
)
