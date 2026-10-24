"""One stored audit row as an ADCR 0.1.0 record.

ADCR, the AI Decision Check Record, is the open rulebook at
https://complyedge.io/rulebook/0.1.0. This module is the single mapping from a
ComplyEdge audit row to an ADCR record. The write-time chain hashes its output
(CHN-02) and the ADCR export serves its output, so the bytes a reader receives
are the bytes that were hashed. Nothing else builds an ADCR record.

Standard library only, so an auditor can run it beside the export. Versioned:
``MAPPING_VERSION`` is the record's ``record_version``; any change to what this
function emits for the same row is a new mapping version.

Rules the mapping follows, each from the rulebook:

* Canonical form is RFC 8785 (JCS): raw UTF-8, sorted keys, no whitespace.
  Non-integer numbers are refused; the mapping writes them as decimal strings
  (REC-01).
* ``occurred_at`` is UTC with a ``Z`` and at least millisecond precision
  (REC-04).
* Every stored attribute reaches the record, so the chain covers the whole row:
  the ones ADCR names go to their ADCR fields, the rest go under ``complyedge``.
  Storage keys (``pk``, ``sk``, the index keys, ``ttl``) and the chain's own
  attributes are not part of the record.
* A violation is a fired rule only when the row carries its rule metadata
  (``rule_version``), which the writer sets from the loaded rule set. Anything
  else that the engine reported (an engine-state marker, a classifier without a
  rule file) is a reason code, never a rule (REC-15, REC-16).
"""

from __future__ import annotations

import hashlib
import json
import os
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any
from urllib.parse import quote
from uuid import UUID

MAPPING_VERSION = "complyedge-adcr-1"
RULEBOOK = "https://complyedge.io/rulebook/0.1.0"
PRODUCER_ID = "https://complyedge.io/producer-profile/"
RULE_SET_INDEX_BASE = "https://complyedge.io/rule-set/"
CHECKER_ID = "complyedge"

#: ADCR algorithm names (SPEC sections 4 and 5).
CHAIN_ALG = "sha256-chain-1"
COMMITMENT_ALG = "hmac-sha256-1"
CHAIN_STATUS_PRE_CHAIN = "pre_chain"

#: The producer profile (PRF-01) and the sections an export envelope points at.
RETENTION_PROFILE_URL = PRODUCER_ID + "#retention"
INTERPRETATION_GUIDE_URL = PRODUCER_ID + "#interpretation"

#: CHN-04 clock tolerance. ``occurred_at`` is taken from the API host clock
#: when the decision is made and the row is chained when it is written, so two
#: concurrent requests can reach the chain in the opposite order of their
#: timestamps by at most the API function's request ceiling (300 s, the
#: Lambda Timeout set for the API function), plus one second for
#: the hosts' clock reference.
CLOCK_REFERENCE = "AWS Lambda host clock, UTC"
CLOCK_TOLERANCE_MS = 301_000

#: Event types a stored row can carry. A row without ``event_type`` is a
#: decision; only non-decision rows store the attribute.
EVENT_DECISION = "decision"
EVENT_LOGGING_FAILURE = "logging_failure"
EVENT_OVERSIGHT = "oversight"
EVENT_LEGAL_HOLD = "legal_hold"
EVENT_CONTEST = "contest"
EVENT_NOTICE = "notice"
EVENT_INCIDENT = "incident"
EVENT_OPT_OUT = "opt_out"
EVENT_CLASSIFICATION = "classification"
EVENT_FALLBACK = "fallback"
#: OVS-01: the dashboard is opened by the account's one sign-in identity, so
#: the person who reviews a flag there is the account holder.
REVIEWER_ROLE_ACCOUNT_HOLDER = "account_holder"
#: The public page that states who reviews and who grants that authority.
REVIEW_AUTHORITY_URL = "https://complyedge.io/review-authority/"
#: Where a flag opens in the dashboard (the review screen the reviewer used).
DASHBOARD_FLAG_URL = "https://dashboard.complyedge.io/audit/flags/"
#: Days a decision record is kept when the account has not set a longer period: the
#: floor retention class the producer profile publishes. Defined here, beside
#: the classes, so the profile build reads it without importing anything that
#: talks to AWS; dynamodb_utils re-exports it for the writers.
#: REC-20: six months holds from any start date only from 184 days.
AUDIT_RETENTION_DAYS = int(os.getenv("AUDIT_RETENTION_DAYS", "184"))

#: Violations whose ``reason`` is a model's sentence, by exact rule id. The
#: audit row stores a reason code instead (ADCR REC-16: codes, never free
#: text that could restate the input). Read by the API's audit writer and by
#: the producer-profile build (the reason-code list).
MODEL_REASON_CODES = {"LLM_FALLBACK_BLOCK": "llm_fallback_block", "LLM_LAYER2_BLOCK": "llm_layer2_block"}

#: A final review and the oversight record it writes. ``needs_legal_counsel``
#: keeps the flag in the queue and writes no record.
OVERSIGHT_FOR_REVIEW = {
    "reviewed_violation": ("accepted", "layer2.reviewed_violation"),
    "reviewed_compliant": ("disregarded", "layer2.reviewed_compliant"),
}


def dashboard_flag_url(flag_id: str) -> str:
    """The dashboard URL that opens one flag (OVS-01 inputs_ref)."""
    return DASHBOARD_FLAG_URL + quote(str(flag_id), safe="")


#: REC-07: a logging failure about the chain itself (an anchor that could not
#: be obtained, a row that could not be chained) has no deciding system, so
#: its record carries none. A failed decision write (write_failed) names the
#: system whose decision could not be recorded.
CHAIN_LEVEL_FAILURES = frozenset({"anchor_failed", "chain_failed"})

#: Data categories a caller may declare (REC-13). Closed vocabulary; the
#: special-category flag is an exact lookup in the second set
#: (Regulation (EU) 2016/679, Article 9(1)).
SPECIAL_CATEGORIES = frozenset(
    {
        "racial_or_ethnic_origin",
        "political_opinions",
        "religious_or_philosophical_beliefs",
        "trade_union_membership",
        "genetic",
        "biometric",
        "health",
        "sex_life_or_sexual_orientation",
    }
)
DATA_CATEGORIES = SPECIAL_CATEGORIES | frozenset(
    {
        "identification",
        "contact",
        "financial",
        "location",
        "employment",
        "education",
        "online_identifier",
        "communication",
        "behavioural",
        "criminal_convictions_and_offences",
    }
)

#: Article 22(2) exceptions a legal basis may name.
ART22_EXCEPTIONS = frozenset({"22(2)(a)", "22(2)(b)", "22(2)(c)"})

_STORAGE_KEYS = frozenset({"pk", "sk", "gsi1_pk", "gsi1_sk", "ttl"})
_CHAIN_KEYS = frozenset(
    {"chain_seq", "chain_prev", "chain_hash", "chain_alg", "chain_link", "chain_status"}
)
_DIRECTION = {"prompt": "input", "output": "output", "action": "action"}
_VERDICT = {
    "block": ("deny", "blocked"),
    "allow": ("allow", "passed"),
    "flag": ("allow", "flagged"),
}

# --- value form --------------------------------------------------------------


def decimal_string(value: Any) -> str:
    """A number as a plain decimal string, the same for a float and the
    Decimal DynamoDB returns for it: 0.95 and Decimal("0.95") give "0.95";
    1.0 and Decimal("1") give "1"."""
    d = Decimal(repr(value)) if isinstance(value, float) else Decimal(value)
    d = d.normalize()
    if d == d.to_integral_value():
        d = d.quantize(Decimal(1))
    return format(d, "f")


def json_value(value: Any, key: str = "") -> Any:
    """JSON-native, float-free, sorted. Integral numbers stay integers, other
    numbers become decimal strings; a ``confidence`` is always a string."""
    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, (int, float, Decimal)):
        if key == "confidence":
            return decimal_string(value)
        if isinstance(value, int):
            return value
        d = Decimal(repr(value)) if isinstance(value, float) else value
        return int(d) if d == d.to_integral_value() else decimal_string(d)
    if isinstance(value, datetime):
        # AUD-053: datetime objects must not keep a caller offset in the
        # ADCR record / chain input. Same Zulu shape as occurred_at (REC-04).
        return utc_timestamp(value)
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, dict):
        return {str(k): json_value(value[k], str(k)) for k in sorted(value, key=str)}
    if isinstance(value, (list, tuple)):
        return [json_value(v, key) for v in value]
    if isinstance(value, (set, frozenset)):
        return sorted(json_value(v, key) for v in value)
    return value


def utc_timestamp(value: Any) -> str:
    """RFC 3339 UTC with a Z: milliseconds when the value has no finer part,
    else microseconds, so no stored precision is lost.

    AUD-103: junk / empty values raise ValueError (not bare TypeError), so
    ADCR export callers can fail closed with one exception type.
    """
    try:
        if isinstance(value, datetime):
            t = value
        else:
            text = str(value).strip()
            if not text:
                raise ValueError("empty timestamp")
            t = datetime.fromisoformat(text.replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=UTC)
        t = t.astimezone(UTC)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"unparseable timestamp: {value!r}") from exc
    frac = f"{t.microsecond // 1000:03d}" if t.microsecond % 1000 == 0 else f"{t.microsecond:06d}"
    return t.strftime("%Y-%m-%dT%H:%M:%S.") + frac + "Z"


def _optional_utc_timestamp(value: Any) -> str | None:
    """UTC Zulu stamp, or None when unparseable (AUD-117 optional rights stamps)."""
    try:
        return utc_timestamp(value)
    except ValueError:
        return None


# --- canonical form and chain --------------------------------------------------

_MAX_SAFE_INT = 2**53


def canonical(obj: Any) -> bytes:
    """RFC 8785 for the value space a record uses: objects, arrays, strings,
    integers within +-(2^53 - 1), booleans and null. Raw UTF-8. A float is
    refused, never rounded (REC-01)."""
    return _jcs(obj).encode("utf-8")


def _jcs(v: Any) -> str:
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        if abs(v) >= _MAX_SAFE_INT:
            raise ValueError("integer outside +-(2^53 - 1); write it as a string (REC-01)")
        return str(v)
    if isinstance(v, (float, Decimal)):
        raise ValueError("non-integer number; write it as a decimal string (REC-01)")
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        return "[" + ",".join(_jcs(x) for x in v) + "]"
    if isinstance(v, dict):
        if any(not isinstance(k, str) for k in v):
            raise ValueError("object keys must be strings")
        keys = sorted(v, key=lambda k: k.encode("utf-16-be"))
        return "{" + ",".join(json.dumps(k, ensure_ascii=False) + ":" + _jcs(v[k]) for k in keys) + "}"
    raise ValueError(f"value of type {type(v).__name__} has no JSON form")


def chain_hash(previous_hash: str, record: dict[str, Any]) -> str:
    """CHN-02: SHA-256 over the previous hash (hex text) followed by the
    canonical record without its ``chain`` member."""
    body = {k: v for k, v in record.items() if k != "chain"}
    return hashlib.sha256((previous_hash or "").encode("utf-8") + canonical(body)).hexdigest()


def anchor_statement(account_id: str, chain_seq: int, chain_hash_hex: str) -> bytes:
    """ANC-01 anchor statement, canonical bytes."""
    return canonical(
        {"account_id": str(account_id), "chain_alg": CHAIN_ALG, "chain_hash": chain_hash_hex, "chain_seq": int(chain_seq)}
    )


def rule_set_index_url(digest: str) -> str:
    return f"{RULE_SET_INDEX_BASE}{digest}/"


#: The longer periods an Enterprise account can pick, in years
#: (apps/dashboard/src/retentionPresets.ts). With the product floor they are
#: the retention classes the producer profile defines.
ENTERPRISE_RETENTION_YEARS = (7, 11)


def retention_class_days(floor_days: int) -> list[int]:
    """Days of every retention class the producer profile defines: the floor,
    then each Enterprise preset in whole days (365.25 a year, rounded up)."""
    presets = {-(-years * 36525 // 100) for years in ENTERPRISE_RETENTION_YEARS}
    return sorted({int(floor_days)} | presets)


def allowed_retention_days() -> frozenset[int]:
    """Retention lengths the API may store (PRF-01 classes only)."""
    return frozenset(retention_class_days(AUDIT_RETENTION_DAYS))


def retention_fields(when: datetime, retention_days: int | None) -> dict[str, str]:
    """The row's retention attributes (REC-19), written with the row.

    ``class`` is ``retention-<N>d`` for an account that keeps records N days,
    the label the producer profile defines; ``erase_after`` is the write time
    plus N days. Lengths outside the profile classes are refused at the
    retention API; a missing or zero value falls back to the product floor so
    the record never carries ``retention-none``.
    """
    from datetime import timedelta

    # Zero / missing was never-expire; that is not a profile class, so write
    # the floor. Positive lengths are written as given (the retention API only
    # accepts profile classes for new settings).
    days = AUDIT_RETENTION_DAYS if not retention_days else int(retention_days)
    # UTC calendar arithmetic (AUD-037): same convention as EVENT# SK writers.
    # AUD-131: store erase_after as ADCR Zulu (utc_timestamp), not bare +00:00
    # isoformat, so write-time shape matches to_adcr / verifier.
    t = when.replace(tzinfo=UTC) if when.tzinfo is None else when.astimezone(UTC)
    return {
        "retention_class": f"retention-{days}d",
        "retention_erase_after": utc_timestamp(t + timedelta(days=days)),
    }


def is_adcr_exportable(row: dict[str, Any]) -> bool:
    """True when the row can sit in an ADCR export that the reference verifier
    can accept for Chain and commitment rules.

    Rows written before the write-time chain (no ``chain_alg``) and rows whose
    text commitment still uses plain ``sha256`` are excluded. Oversight and
    logging-failure rows with a write-time chain stay included.
    """
    if not row.get("chain_alg"):
        return False
    alg = row.get("text_hash_alg")
    if row.get("text_hash") and alg and alg != COMMITMENT_ALG:
        return False
    return True


# --- the mapping ----------------------------------------------------------------


def _pseudonym(value: Any, key_version: Any) -> dict[str, Any] | None:
    if isinstance(value, str) and value.startswith("p1:") and isinstance(key_version, int):
        return {"key_version": key_version, "value": value}
    return None


def _is_rule(violation: Any) -> bool:
    return isinstance(violation, dict) and bool(violation.get("rule_version"))


def _rule_ref(v: dict[str, Any]) -> dict[str, Any]:
    ref = {k: val for k, val in v.items() if k not in ("rule_description", "description")}
    citation = v.get("rule_description") or v.get("description")
    if citation:
        ref["citation"] = citation
    return ref


def _fallback(row: dict[str, Any]) -> dict[str, Any] | None:
    if row.get("engine_path") == "fallback_block":
        return {"kind": "degraded", "reason_code": "fallback_block"}
    skipped = row.get("layer2_skipped")
    if skipped:
        return {"kind": "skipped", "reason_code": f"layer2_{skipped}"}
    return None


def _exemption_provision(
    e: dict[str, Any], by_rule: dict[str, Any]
) -> dict[str, Any]:
    """Prefer the ELI/url provision stored on the row or on the fired rule."""
    stored = e.get("provision")
    if isinstance(stored, dict) and (stored.get("eli") or stored.get("url")):
        return {
            k: stored[k]
            for k in ("eli", "url", "label")
            if stored.get(k) is not None
        }
    rule = by_rule.get(e.get("rule_id")) or {}
    if isinstance(rule.get("provision"), dict) and (
        rule["provision"].get("eli") or rule["provision"].get("url")
    ):
        return dict(rule["provision"])
    return {"label": e.get("basis") or e.get("exemption")}


def _exemptions(row: dict[str, Any], rules: list[dict[str, Any]]) -> dict[str, list]:
    by_rule = {r.get("rule_id"): r for r in rules}
    claimed = []
    for e in row.get("exemptions") or []:
        if not isinstance(e, dict):
            continue
        entry = {k: v for k, v in e.items() if k not in ("exemption", "basis", "provision")}
        entry["name"] = e.get("exemption")
        entry["provision"] = _exemption_provision(e, by_rule)
        claimed.append(entry)
    rejected = []
    for e in row.get("rejected_exemptions") or []:
        if not isinstance(e, dict):
            continue
        entry = {k: v for k, v in e.items() if k not in ("exemption", "provision")}
        entry["name"] = e.get("exemption")
        entry["provision"] = _exemption_provision(e, by_rule)
        entry["reason_code"] = f"{e.get('exemption')}_{e.get('outcome') or 'refused'}"
        rejected.append(entry)
    return {"claimed": claimed, "rejected": rejected}


def to_adcr(row: dict[str, Any]) -> dict[str, Any]:
    """The ADCR record for one stored row, without its ``chain`` member.

    ``row`` is the item as stored or as the export serialises it; both give the
    same record. Pure and deterministic: the chain writer and the verifier call
    it on the same row and must get the same bytes.
    """
    row = json_value({k: v for k, v in row.items() if k not in _STORAGE_KEYS and k not in _CHAIN_KEYS})
    # Attributes carried in an ADCR field; every other one goes under
    # ``complyedge`` so the chain covers the whole row.
    used = {"event_id", "tenant_id", "timestamp", "event_type"}
    key_version = row.get("pseudonym_key_version")
    event_type = row.get("event_type") or EVENT_DECISION
    occurred_at = utc_timestamp(row["timestamp"]) if row.get("timestamp") else None

    rec: dict[str, Any] = {
        "rulebook": RULEBOOK,
        "record_version": MAPPING_VERSION,
        "record_id": row.get("event_id"),
        **({"occurred_at": occurred_at} if occurred_at else {}),
        "event_type": event_type,
        "account_id": row.get("tenant_id"),
        "producer_id": PRODUCER_ID,
        "deploying_party": row.get("tenant_id"),
    }
    failure_kind = None
    if event_type == EVENT_LOGGING_FAILURE:
        failure_kind = "write_failed" if row.get("agent_id") else "anchor_failed"
    if row.get("agent_id") and failure_kind not in CHAIN_LEVEL_FAILURES:
        ds = {"id": row["agent_id"]}
        if row.get("deciding_system_version"):
            ds["version"] = row["deciding_system_version"]
        rec["deciding_system"] = ds
        used |= {"agent_id", "deciding_system_version"}
    if row.get("retention_class") or row.get("retention_erase_after"):
        retention: dict[str, Any] = {}
        if row.get("retention_class"):
            retention["class"] = row["retention_class"]
        if row.get("retention_erase_after"):
            # AUD-113: junk erase_after must not abort the whole ADCR record;
            # keep class and omit erase_after (occurred_at still fail-closed).
            try:
                retention["erase_after"] = utc_timestamp(row["retention_erase_after"])
            except ValueError:
                pass
        if retention:
            rec["retention"] = retention
        used |= {"retention_class", "retention_erase_after"}

    if failure_kind:
        rec["failure_kind"] = failure_kind
        if occurred_at:
            rec["detected_at"] = occurred_at

    checker: dict[str, Any] = {"id": CHECKER_ID}
    for src, dst in (("bundle_id", "version"), ("engine_path", "path"), ("model_used", "model"),
                     ("confirm_model", "confirm_model")):
        if src in row:
            checker[dst] = row[src]
            used.add(src)
    if len(checker) > 1:
        rec["checker"] = checker

    if event_type == EVENT_LEGAL_HOLD:
        hold = row.get("hold")
        if isinstance(hold, dict):
            rec["hold"] = {
                k: hold[k]
                for k in ("id", "action", "scope", "reason_code")
                if hold.get(k) is not None
            }
            used.add("hold")

    if event_type == EVENT_CONTEST:
        for f in (
            "decision_ref",
            "request_kind",
            "requested_at",
            "responded_at",
            "review_outcome",
            "statement_ref",
            "rectified_at",
        ):
            if row.get(f) is not None:
                # AUD-117: junk *_at must not abort the whole ADCR record.
                if f.endswith("_at"):
                    stamp = _optional_utc_timestamp(row[f])
                    if stamp is None:
                        used.add(f)
                        continue
                    rec[f] = stamp
                else:
                    rec[f] = row[f]
                used.add(f)
        reviewer = _pseudonym(row.get("reviewer"), key_version)
        if reviewer:
            rec["reviewer"] = reviewer
            used |= {"reviewer", "pseudonym_key_version"}

    if event_type == EVENT_NOTICE:
        for f in (
            "notice_kind",
            "decision_ref",
            "channel_ref",
            "language",
            "issued_at",
            "statement_ref",
        ):
            if row.get(f) is not None:
                if f == "issued_at":
                    stamp = _optional_utc_timestamp(row[f])
                    if stamp is None:
                        used.add(f)
                        continue
                    rec[f] = stamp
                else:
                    rec[f] = row[f]
                used.add(f)

    if event_type == EVENT_INCIDENT:
        for f in ("incident_kind", "detected_at", "reported_at", "report_ref"):
            if row.get(f) is not None:
                if f.endswith("_at"):
                    stamp = _optional_utc_timestamp(row[f])
                    if stamp is None:
                        used.add(f)
                        continue
                    rec[f] = stamp
                else:
                    rec[f] = row[f]
                used.add(f)

    if event_type == EVENT_OPT_OUT:
        for f in ("decision_ref", "reason_code"):
            if row.get(f) is not None:
                rec[f] = row[f]
                used.add(f)

    if event_type == EVENT_CLASSIFICATION:
        for f in ("classification_result", "assessment_ref"):
            if row.get(f) is not None:
                rec[f] = row[f]
                used.add(f)

    if event_type == EVENT_FALLBACK:
        fb = row.get("fallback")
        if isinstance(fb, dict):
            rec["fallback"] = {
                k: fb[k] for k in ("kind", "reason_code") if fb.get(k) is not None
            }
            used.add("fallback")

    if event_type == EVENT_OVERSIGHT:
        for f in ("proposal_ref", "oversight_action", "reviewer_role", "authority_ref", "inputs_ref", "reason_code"):
            if row.get(f) is not None:
                rec[f] = row[f]
                used.add(f)
        if row.get("review_opened_at"):
            # AUD-117: junk review_opened_at omits the field; keep oversight.
            stamp = _optional_utc_timestamp(row["review_opened_at"])
            if stamp is not None:
                rec["review_opened_at"] = stamp
            used.add("review_opened_at")
        reviewer = _pseudonym(row.get("reviewer"), key_version)
        if reviewer:
            rec["reviewer"] = reviewer
            used |= {"reviewer", "pseudonym_key_version"}

    if event_type == EVENT_DECISION:
        native = row.get("action") or ("allow" if row.get("allowed") else "block")
        # ``allowed`` is the decision; ``action`` refines an allowed one (flag).
        # Rows written before the action followed the decision can carry
        # ``action: allow`` on a block, so a refusal is read from ``allowed``.
        verdict, action = _VERDICT["block"] if row.get("allowed") is False else _VERDICT.get(native, ("deny", "blocked"))
        rec["verdict"] = verdict
        rec["action"] = action
        rec["native_result"] = native
        if row.get("action"):
            used.add("action")

        violations = [v for v in row.get("violations") or [] if isinstance(v, dict)]
        rules = [_rule_ref(v) for v in violations if _is_rule(v)]
        others = [v for v in violations if not _is_rule(v)]
        rec["rules_fired"] = rules
        used.add("violations")
        codes = {str(v.get("rule_id")) for v in others if v.get("rule_id")}
        codes |= {str(v["reason_code"]) for v in violations if v.get("reason_code")}
        fb = _fallback(row)
        if fb:
            rec["fallback"] = fb
            codes.add(fb["reason_code"])
            used.add("layer2_skipped")
        if codes:
            rec["reason_codes"] = sorted(codes)
        if others:
            rec.setdefault("complyedge", {})["non_rule_findings"] = others
        if row.get("bundle_digest"):
            rec["rule_set"] = {
                "digest": row["bundle_digest"],
                "index_url": rule_set_index_url(row["bundle_digest"]),
                "label": row.get("bundle_id") or "",
            }
            used.add("bundle_digest")
        rec["exemptions"] = _exemptions(row, rules)
        used |= {"exemptions", "rejected_exemptions"}

        if row.get("text_hash"):
            commitment: dict[str, Any] = {
                "alg": row.get("text_hash_alg") or "sha256",
                "direction": _DIRECTION.get(row.get("direction"), row.get("direction")),
                "value": row["text_hash"],
            }
            if key_version is not None:
                commitment["key_version"] = key_version
            if row.get("source_ref"):
                commitment["source_ref"] = row["source_ref"]
            rec["commitments"] = [commitment]
            used |= {"text_hash", "text_hash_alg", "direction", "source_ref"}
        else:
            rec["commitments"] = []

        if "data_categories" in row:
            cats = list(row["data_categories"] or [])
            rec["data_categories"] = cats
            if any(c in SPECIAL_CATEGORIES for c in cats):
                rec["special_category"] = True
            used.add("data_categories")
        for f in ("purpose_ref", "correlation_id", "works_agreement_ref", "legal_basis", "subject_is_employee"):
            if row.get(f) is not None:
                rec[f] = row[f]
                used.add(f)
        subject = _pseudonym(row.get("subject"), key_version)
        if subject:
            rec["subject"] = subject
            used.add("subject")
        for f in ("decision_mode", "notice", "explanation_inputs", "withheld", "escrow_ref"):
            if row.get(f) is not None:
                rec[f] = row[f]
                used.add(f)

    for field, name in (("user_id", "user"), ("session_id", "session")):
        p = _pseudonym(row.get(field), key_version)
        if p:
            rec[name] = p
            used.add(field)
    if any(name in rec for name in ("user", "session", "subject")) or (
        "commitments" in rec and rec["commitments"] and "key_version" in rec["commitments"][0]
    ):
        used.add("pseudonym_key_version")

    residual = {k: v for k, v in row.items() if k not in used}
    if residual:
        rec.setdefault("complyedge", {}).update(residual)
    if "complyedge" in rec:
        rec["complyedge"] = json_value(rec["complyedge"])
    return rec


# --- the export (EXP-01) ----------------------------------------------------------


def _anchor_entry(stored: dict[str, Any]) -> dict[str, Any]:
    """One stored anchor (audit_anchor.anchor_head) as an EXP-01 anchor.

    AUD-119: junk ``anchored_at`` must not abort the whole ADCR export;
    omit ``stored_at`` and keep statement / token / provider.

    Raises ValueError when required anchor fields are missing or statement
    JSON is unparseable (AUD-130: export_document skips those anchors).
    """
    try:
        statement = json.loads(stored["statement"])
        token_b64 = stored["token_der_b64"]
        provider_url = stored["tsa_url"]
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ValueError("unusable anchor record") from exc
    if not isinstance(statement, dict) or not token_b64 or not provider_url:
        raise ValueError("unusable anchor record")
    entry: dict[str, Any] = {
        "statement": statement,
        "token_b64": token_b64,
        "provider_url": provider_url,
    }
    stored_at = _optional_utc_timestamp(stored.get("anchored_at"))
    if stored_at is not None:
        entry["stored_at"] = stored_at
    # GAP-TR-03 / CHN-05: pass through producer origin signatures when present.
    sigs = stored.get("signatures")
    if isinstance(sigs, list) and sigs:
        entry["signatures"] = sigs
    return entry


def export_document(
    rows: list[dict[str, Any]],
    *,
    account_id: str,
    period_from: datetime,
    period_to: datetime,
    anchors: list[dict[str, Any]],
) -> dict[str, Any]:
    """The ADCR export of these stored rows: ``{"envelope", "records"}``.

    Only write-time-chained rows with a current commitment algorithm are
    included (``is_adcr_exportable``). Pre-chain and legacy plain-sha256
    commitment rows stay in storage and in the plain JSON/CSV export; they
    are omitted here so the ADCR package the reference verifier reads does
    not fail Chain / CMT rules for history that predates those algorithms.
    ``anchors`` are the stored anchor records inside the range; the envelope
    states only what they and the records give.
    """
    skipped_pre_chain = 0
    skipped_unmapped = 0
    chained = []
    for row in rows:
        if not is_adcr_exportable(row):
            if not row.get("chain_alg"):
                skipped_pre_chain += 1
            continue
        # AUD-127: one junk occurred_at (or other fail-closed stamp) must not
        # abort the whole ADCR package; skip that row (still in storage / plain
        # export). to_adcr itself stays fail-closed for single-row callers.
        try:
            rec = to_adcr(row)
        except ValueError:
            skipped_unmapped += 1
            continue
        # AUD-129: empty/missing timestamp maps without occurred_at; skip so
        # the package does not ship records the verifier must reject.
        if not rec.get("occurred_at"):
            skipped_unmapped += 1
            continue
        rec["chain"] = {
            "seq": int(row["chain_seq"]),
            "prev": str(row.get("chain_prev") or ""),
            "hash": str(row["chain_hash"]),
            "alg": str(row["chain_alg"]),
        }
        chained.append(rec)
    chained.sort(key=lambda r: r["chain"]["seq"])
    seqs = [r["chain"]["seq"] for r in chained]
    last = max(seqs) if seqs else 0
    # AUD-130: one broken stored anchor must not abort the whole package.
    entries: list[dict[str, Any]] = []
    for a in anchors:
        try:
            entries.append(_anchor_entry(a))
        except (ValueError, TypeError, KeyError):
            continue
    anchored = max(
        (e["statement"].get("chain_seq") for e in entries
         if isinstance(e["statement"].get("chain_seq"), int) and e["statement"]["chain_seq"] <= last),
        default=0,
    )
    envelope = {
        "rulebook": RULEBOOK,
        "account_id": str(account_id),
        "producer_id": PRODUCER_ID,
        "period": {"from": utc_timestamp(period_from), "to": utc_timestamp(period_to)},
        "clock_source": {"reference": CLOCK_REFERENCE, "tolerance_ms": CLOCK_TOLERANCE_MS},
        "chain_summary": {
            "alg": CHAIN_ALG,
            "first_seq": min(seqs) if seqs else 0,
            "last_seq": last,
            "chained_rows": len(chained),
            "pre_chain_rows": skipped_pre_chain,
            # AUD-127: exportable rows that failed to_adcr (e.g. junk timestamp).
            "unmapped_rows": skipped_unmapped,
        },
        "anchors": entries,
        "anchor_coverage": {
            "newest_anchored_seq": anchored,
            "unanchored_rows": max(0, last - anchored),
        },
        "retention_profile_url": RETENTION_PROFILE_URL,
        "interpretation_guide_url": INTERPRETATION_GUIDE_URL,
    }
    return {"envelope": envelope, "records": chained}
