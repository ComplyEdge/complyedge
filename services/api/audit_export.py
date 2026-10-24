"""
Tamper-evident hash chains for the audit trail, and their offline verifier.

Two chains, because they prove two different things:

* ``sha256-v1`` (export time): ``chain_link`` on every exported event and
  ``chain_head`` in the envelope. Each link is SHA-256(previous_link +
  canonical_event_json). It proves the FILE was not altered after export.
* ``sha256-chain-1`` (write time, ADCR 0.1.0 CHN-02): ``chain_seq`` /
  ``chain_prev`` / ``chain_hash`` stored ON THE ROW when it is written, by the
  single writer, in one atomic operation with the tenant's chain head. Each
  hash is SHA-256(previous hash + the RFC 8785 canonical ADCR record of the
  row), the record being ``adcr_record.to_adcr(row)``. It proves the ROWS were not edited,
  deleted, reordered or forged between the write and the export. A deleted row
  is a gap in the sequence; a reordered or inserted row breaks ``chain_prev``;
  an edited row breaks its own hash. On a schedule the chain head is bound to
  an eIDAS-qualified RFC 3161 timestamp (``anchors`` in the envelope), which is
  what lets a third party who trusts neither the operator nor the customer
  detect a truncated tail and date the chain with legal weight.

``verify_write_time_chain`` reports each failure class on its own axis, never
one boolean. It needs only the export file and, for the timestamp signature,
the QTSP's root certificate. Verification recomputes everything; nothing here
is a stub.

This module ships publicly with ``adcr_record.py`` beside it and has no
dependencies beyond the standard library. The RFC 3161 signature check runs ``openssl ts -verify`` (OpenSSL 1.1
or later, which supports ``-partial_chain``), trusting the certificate the
auditor supplies, typically the one the EU Trusted List publishes for the
provider, at the token's own time. Without a usable openssl it reports
``anchor_token_signature_not_checked``, never a failure.

EU AI Act Art 12 record-keeping evidence.
"""

from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

import adcr_record

CHAIN_ALGORITHM = "sha256-v1"
GENESIS_HASH = ""

#: Write-time chain (stored on the row by the writer, see the module docstring).
#: The ADCR name (rulebook 0.1.0, CHN-02).
WRITE_TIME_CHAIN_ALGORITHM = adcr_record.CHAIN_ALG
#: Attributes the writer stores on each chained row.
WRITE_TIME_CHAIN_FIELDS = ("chain_seq", "chain_prev", "chain_hash", "chain_alg")
#: Set by the export, never stored: "chained" or "pre_chain" (ADCR names).
CHAIN_STATUS_FIELD = "chain_status"
CHAIN_STATUS_CHAINED = "chained"
CHAIN_STATUS_PRE_CHAIN = adcr_record.CHAIN_STATUS_PRE_CHAIN

# ---------------------------------------------------------------------------
# Evidence completeness (the 2026-07-25 incident described below; the full
# incident write-up is kept internally)
#
# On 2026-07-25 /v1/audit/export returned 160 records with no text_hash, no
# agent_id, no citations — and a cheerful HTTP 200. A telemetry dual-write had
# been silently replacing the audit record for 11 days. Every dashboard stayed
# green because metrics read only the fields that survived, and the hash chain
# verified the hollow rows perfectly.
#
# An Article 12 export whose records lack Article 12 fields must never present
# itself as complete. This module now refuses to.
# ---------------------------------------------------------------------------

#: Fields without which a record cannot serve its Art 12 evidentiary purpose:
#: binding a decision to a specific input, actor and moment.
EVIDENCE_FIELDS = ("text_hash", "agent_id", "timestamp")

#: Records written from this instant carry the full contract, because the
#: dual-write fix (f32e8ed) was deployed at this point. Anything at or after
#: this timestamp that is incomplete is a LIVE regression and must raise.
#:
#: Records BEFORE it are permanently incomplete — the data was destroyed in
#: place and is unrecoverable (PITR only snapshots post-overwrite state; the
#: streams that held the old images expired long before discovery). Those
#: cannot be fixed, so they are reported rather than raised on: failing hard
#: would make every export spanning the window unusable, which punishes the
#: reader for damage they did not cause and hides the gap behind a 500.
EVIDENCE_CONTRACT_SINCE = "2026-07-25T20:30:00+00:00"

#: The ACTUAL window in which evidence was destroyed (the July 2026 audit
#: write incident), as
#: measured by a full-table scan on 2026-07-27: 221 records affected, 6 later
#: recovered from the stream archive, 215 permanently lost.
#:
#: This is deliberately NOT the same thing as EVIDENCE_CONTRACT_SINCE, and the
#: distinction is what a reader needs. The contract date says "anything
#: incomplete after this is a live regression". The window says "this is where
#: the historical damage is."
#:
#: Stating only the contract date over-claims. An export spanning 2026-07-01
#: onward returns 202 COMPLETE records dated before the fix (07-10, 07-11,
#: 07-12) alongside the damaged ones — so telling a reader that "records
#: predating the fix lost their evidence fields" contradicts the very data they
#: are holding, and reads as either sloppiness or overstatement. Both are
#: expensive in a due-diligence review. Name the window.
INCIDENT_WINDOW_START = "2026-07-13"
INCIDENT_WINDOW_END = "2026-07-25"


class IncompleteEvidenceError(RuntimeError):
    """A post-contract audit record is missing Article 12 evidence fields.

    Raised rather than returned: an export is a legal artifact, and shipping a
    silently hollow one is worse than shipping none. If this fires, the write
    path is dropping evidence again — check for a second writer on the EVENT#
    keyspace before touching this module.

    Carries the facts as ATTRIBUTES, not only inside the message string, so an
    HTTP handler can compose its own response instead of forwarding ``str(e)``.
    Passing exception text straight to a caller couples the API's response body
    to this class's wording — a later edit here would silently change the API —
    and it is the pattern that leaks internals when the exception is not one of
    ours. ``record_count`` and ``contract_since`` are safe to state publicly;
    ``examples`` names specific event ids and belongs in logs only.
    """

    def __init__(
        self,
        message: str,
        *,
        record_count: int = 0,
        contract_since: str = "",
        examples: list[str] | None = None,
    ) -> None:
        super().__init__(message)
        self.record_count = record_count
        self.contract_since = contract_since
        self.examples = examples or []


def _missing_evidence(event: dict[str, Any]) -> list[str]:
    # A logging_failure row records that a decision could NOT be recorded; it
    # binds no input by design, so the decision evidence contract is not its.
    if event.get("event_type") not in (None, "", "decision"):
        return []
    return [f for f in EVIDENCE_FIELDS if not event.get(f)]


def assess_evidence_completeness(events: list[dict[str, Any]]) -> dict[str, Any]:
    """Summarise Art 12 completeness across an export, and fail on live regressions.

    Returns an envelope block that states the truth about the export's own
    evidentiary quality, so a reader is never left to assume.

    Raises:
        IncompleteEvidenceError: a record written after EVIDENCE_CONTRACT_SINCE
            is missing evidence fields — i.e. the write path is losing data now.
    """
    complete = 0
    legacy_incomplete: list[str] = []
    live_regressions: list[str] = []

    contract_at = _parse_event_instant(EVIDENCE_CONTRACT_SINCE)
    for event in events:
        missing = _missing_evidence(event)
        if not missing:
            complete += 1
            continue
        # AUD-043: compare UTC instants. Lexicographic string compare against
        # EVIDENCE_CONTRACT_SINCE amnestied post-contract hollow rows stamped
        # with a negative offset (wall clock looked "before" the cutover).
        instant = _parse_event_instant(
            event.get("timestamp") or event.get("ts")
        )
        is_live = instant is None or (
            contract_at is not None and instant >= contract_at
        )
        target = live_regressions if is_live else legacy_incomplete
        target.append(f"{event.get('event_id', '<no event_id>')} missing {missing}")

    if live_regressions:
        raise IncompleteEvidenceError(
            f"{len(live_regressions)} record(s) written after "
            f"{EVIDENCE_CONTRACT_SINCE} are missing Article 12 evidence fields. "
            "The audit write path is dropping evidence: check that nothing "
            "overwrites the audit item after it is persisted (the July 2026 audit "
            "write incident). "
            f"First: {live_regressions[0]}",
            record_count=len(live_regressions),
            contract_since=EVIDENCE_CONTRACT_SINCE,
            examples=live_regressions[:50],
        )

    summary: dict[str, Any] = {
        "required_fields": list(EVIDENCE_FIELDS),
        "complete": complete,
        "incomplete": len(legacy_incomplete),
    }
    if legacy_incomplete:
        summary["incident_window"] = {
            "from": INCIDENT_WINDOW_START,
            "to": INCIDENT_WINDOW_END,
        }
        # Buyer-facing prose: this string reaches a due-diligence reviewer, so it
        # is held to the same standard as published copy. No em dashes.
        summary["note"] = (
            f"Incomplete records fall in a single closed window, "
            f"{INCIDENT_WINDOW_START} to {INCIDENT_WINDOW_END} (the July 2026 "
            "audit write incident): a telemetry writer replaced the audit item on its own "
            "key, destroying the evidence fields in place. 221 records were "
            "affected, 6 were later recovered from the stream "
            "archive, and 215 are permanently unrecoverable. Records outside "
            "that window are unaffected, both before it and after it, and this "
            "export lists the incomplete ones rather than hiding them. The "
            "write path was fixed and the recovery posture rebuilt; recovery is "
            "now exercised on a schedule with a measured objective."
        )
        summary["incomplete_event_ids"] = [
            entry.split(" missing ")[0] for entry in legacy_incomplete[:50]
        ]
    return summary


def normalize_event(value: Any) -> Any:
    """
    Convert an event to JSON-native types, recursively.

    THE INVARIANT THIS EXISTS TO PROTECT: the chain must be computed over the
    representation that is *transmitted*. Anything hashed over an in-memory
    type that serializes differently on the wire is unverifiable by definition,
    because the recipient can never reproduce the bytes that were hashed.

    That is exactly what happened before 2026-07-25. DynamoDB returns numbers
    as ``Decimal``; ``json.dumps(..., default=str)`` rendered them as QUOTED
    STRINGS (``"114"``) into the hash material, while FastAPI serialized the
    same event to the wire as BARE NUMBERS (``114``). Every link in every live
    export failed to verify — 359/359 on the export that surfaced it — while
    the synthetic sample, built from JSON-native literals, verified fine. The
    verifier was sound; it was being fed two different documents.

    Note ``violations[].confidence`` is nested, hence the recursion: a
    top-level-only normalization silently leaves the same hole.
    """
    if isinstance(value, bool):
        return value
    if isinstance(value, Decimal):
        # DynamoDB numerics. Integral values must land on int, not float, or
        # 114 would serialize as 114.0 and break the wire/hash equality again.
        return int(value) if value == value.to_integral_value() else float(value)
    if isinstance(value, datetime):
        # AUD-054: export wire must not keep a caller offset. Naive → UTC;
        # aware → UTC instant. date (no time) stays calendar-only below.
        if value.tzinfo is None:
            value = value.replace(tzinfo=UTC)
        else:
            value = value.astimezone(UTC)
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, dict):
        # Sorted: DynamoDB does not keep the key order of a stored map, so the
        # same art12_purposes object came back as ref/purpose in one row and
        # purpose/ref in the next (4 orders in 8 events, Leo, 2026-10-06), and
        # the CSV wrote different text for identical content. The chain is
        # unaffected: canonical_event_json already hashes with sort_keys.
        return {k: normalize_event(value[k]) for k in sorted(value)}
    if isinstance(value, (list, tuple)):
        return [normalize_event(v) for v in value]
    if isinstance(value, (set, frozenset)):
        # Sets have no stable iteration order, so hashing one is a silent
        # non-determinism bug. Sort into a list so the chain is reproducible.
        return sorted(normalize_event(v) for v in value)
    return value


def canonical_event_json(event: dict[str, Any]) -> str:
    """
    Stable JSON for hashing — sorted keys, no whitespace.

    No ``default=`` fallback on purpose: after normalize_event() every value is
    JSON-native, so an unexpected type must raise here rather than be silently
    hashed as its ``repr``. A loud TypeError is recoverable; a chain that no
    recipient can verify is not.
    """
    payload = {k: v for k, v in event.items() if k != "chain_link"}
    return json.dumps(normalize_event(payload), sort_keys=True, separators=(",", ":"))


def _link_hash(previous_hash: str, event: dict[str, Any]) -> str:
    material = previous_hash + canonical_event_json(event)
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def _parse_event_instant(value: Any) -> datetime | None:
    """UTC datetime for an event timestamp, or None if unparseable.

    Used by the evidence cutover (AUD-043) and export-time chain order
    (AUD-044). Naive values are treated as UTC; offsets convert to UTC.
    """
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        t = value
    else:
        try:
            # AUD-092: TypeError on junk types must not break export sort / cutover.
            t = datetime.fromisoformat(str(value).strip().replace("Z", "+00:00"))
        except (TypeError, ValueError):
            return None
    if t.tzinfo is None:
        return t.replace(tzinfo=UTC)
    return t.astimezone(UTC)


def _sort_events_chronologically(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    # AUD-044: sort by UTC instant. String order put a later UTC row ahead of
    # an earlier one when the later row used a smaller offset wall clock.
    far_future = datetime.max.replace(tzinfo=UTC)

    def key(event: dict[str, Any]) -> tuple[datetime, str]:
        instant = _parse_event_instant(event.get("timestamp")) or far_future
        return (instant, str(event.get("event_id") or ""))

    return sorted(events, key=key)


def _compute_chain_head_in_order(events: list[dict[str, Any]]) -> str | None:
    """Walk events in export order; return None if any chain_link is invalid."""
    previous = GENESIS_HASH
    for event in events:
        clean = {k: v for k, v in event.items() if k != "chain_link"}
        link = _link_hash(previous, clean)
        if event.get("chain_link") != link:
            return None
        previous = link
    return previous


#: DynamoDB storage keys: how the row is found and when it expires, not what
#: was decided. They are not part of the customer's record, so neither export
#: carries them (Leo, 2026-09-29). `timestamp` and `event_id` already say what
#: `sk` encodes; retention is stated once in the envelope (`retention_days`).
EXPORT_INTERNAL_KEYS = frozenset({"pk", "sk", "gsi1_pk", "gsi1_sk", "ttl"})

#: Stamp fields that may arrive as ISO strings with a leftover offset.
#: ``normalize_event`` only converts ``datetime`` objects (AUD-054); string
#: offsets must be rewritten here so wire and export-time hash match (AUD-109).
_EXPORT_STAMP_KEYS = (
    "timestamp",
    "ts",
    "retention_erase_after",
    "requested_at",
    "responded_at",
    "rectified_at",
    "issued_at",
    "detected_at",
    "reported_at",
    "review_opened_at",
    # AUD-128 / AUD-132: same UTC/None rewrite as list normalize.
    "reviewed_at",
    "created_at",
    "updated_at",
    "activated_at",
    "enqueued_at",
)


def _utc_stamp_string(value: Any) -> Any:
    """ISO string → UTC isoformat; datetime left for normalize_event; junk → None.

    AUD-122: do not re-echo unparseable stamp strings on the export wire
    (same None contract as list normalize AUD-115/120).
    AUD-137: empty string is None (same as utc_iso_text / AUD-135), not "".
    """
    if value is None or isinstance(value, datetime):
        return value
    if value == "":
        return None
    instant = _parse_event_instant(value)
    if instant is None:
        return None
    return instant.isoformat()


def export_event(event: dict[str, Any]) -> dict[str, Any]:
    """One event as the customer receives it: JSON-native, storage keys removed."""
    # AUD-109: rewrite offset stamp *strings* before Decimal/datetime walk.
    shaped = dict(event)
    for key in _EXPORT_STAMP_KEYS:
        if key in shaped:
            shaped[key] = _utc_stamp_string(shaped[key])
    normalized = normalize_event(shaped)
    return {k: v for k, v in normalized.items() if k not in EXPORT_INTERNAL_KEYS}


def build_hash_chain(events: list[dict[str, Any]]) -> dict[str, Any]:
    """
    Build a tamper-evident hash chain over audit events.

    Returns events annotated with per-link ``chain_link``, plus envelope
    metadata ``chain_head`` and ``chain_algorithm``.
    """
    # Normalize BEFORE sorting and hashing, and emit the normalized events.
    # The object that gets hashed is the object that gets returned, so a caller
    # can recompute the chain from the JSON they received. Normalizing here
    # rather than inside the loop also makes the sort key type-stable.
    # Labelled BEFORE the export-time links are computed, so the label is
    # inside the sha256-v1 hash material: a reader who strips "pre_chain"
    # from a row breaks chain_link.
    normalized = label_chain_status([export_event(e) for e in events])
    ordered = _sort_events_chronologically(normalized)
    previous = GENESIS_HASH
    chained_events: list[dict[str, Any]] = []

    for event in ordered:
        clean = {k: v for k, v in event.items() if k != "chain_link"}
        link = _link_hash(previous, clean)
        annotated = deepcopy(clean)
        annotated["chain_link"] = link
        chained_events.append(annotated)
        previous = link

    return {
        "events": chained_events,
        "chain_head": previous,
        "chain_algorithm": CHAIN_ALGORITHM,
    }


def verify_audit_export_chain(export: dict[str, Any]) -> bool:
    """
    Verify tamper evidence on an audit export JSON envelope.

    Returns False if chain metadata is missing, algorithm mismatches, events
    were reordered, or any event payload was altered after export.
    """
    if export.get("chain_algorithm") != CHAIN_ALGORITHM:
        return False

    chain_head = export.get("chain_head")
    if not isinstance(chain_head, str):
        return False

    events = export.get("events")
    if not isinstance(events, list):
        return False

    stripped = [{k: v for k, v in e.items() if k != "chain_link"} for e in events]
    if stripped != _sort_events_chronologically(stripped):
        return False

    recomputed_head = _compute_chain_head_in_order(events)
    if recomputed_head is None:
        return False
    return recomputed_head == chain_head


# ---------------------------------------------------------------------------
# Write-time chain (sha256-chain-1, ADCR CHN-02)
# ---------------------------------------------------------------------------


def write_time_material(record: dict[str, Any]) -> str:
    """The exact bytes a write-time link hashes, as text: the RFC 8785
    canonical ADCR record of the row (``adcr_record.to_adcr``), which leaves
    out storage keys and the chain's own attributes.

    The writer computes this on the row it is about to store; the verifier
    recomputes it from either export format (the ADCR export serves these
    records as they are). If the two ever differ, nothing verifies, so both
    sides go through this one function.
    """
    return adcr_record.canonical(adcr_record.to_adcr(record)).decode("utf-8")


def write_time_link_hash(previous_hash: str, record: dict[str, Any]) -> str:
    """CHN-02: SHA-256(previous row's chain_hash + write_time_material(record))."""
    return adcr_record.chain_hash(previous_hash or GENESIS_HASH, adcr_record.to_adcr(record))


def is_chained(event: dict[str, Any]) -> bool:
    return bool(event.get("chain_alg"))


def label_chain_status(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Set ``chain_status`` on each event: chained or pre-chain. Never both silent."""
    out = []
    for event in events:
        annotated = dict(event)
        annotated[CHAIN_STATUS_FIELD] = (
            CHAIN_STATUS_CHAINED if is_chained(event) else CHAIN_STATUS_PRE_CHAIN
        )
        out.append(annotated)
    return out


def _seq(event: dict[str, Any]) -> int | None:
    try:
        return int(event["chain_seq"])
    except (KeyError, TypeError, ValueError):
        return None


def write_time_chain_summary(events: list[dict[str, Any]]) -> dict[str, Any]:
    """Envelope block describing the write-time chain over these events.

    States where write-time evidence begins (``chain_since``) and how many rows
    predate it, so a reader is never left to assume every row is chained.
    """
    chained = [e for e in events if is_chained(e)]
    seqs = [s for s in (_seq(e) for e in chained) if s is not None]
    pre_chain = len(events) - len(chained)
    summary: dict[str, Any] = {
        "algorithm": WRITE_TIME_CHAIN_ALGORITHM,
        "chained_rows": len(chained),
        "pre_chain_rows": pre_chain,
    }
    if seqs:
        first = min(seqs)
        summary["first_seq"] = first
        summary["last_seq"] = max(seqs)
        first_event = next(e for e in chained if _seq(e) == first)
        # AUD-070: envelope chain_since must be UTC instant text, not a leftover
        # -03:00 wall clock from a pre-normalize row (stdlib-only module).
        # AUD-121: omit chain_since when the first chained stamp is junk;
        # do not str() garbage into the envelope.
        since = _parse_event_instant(first_event.get("timestamp"))
        if since is not None:
            summary["chain_since"] = since.isoformat()
    summary["note"] = (
        "chained rows carry chain_seq, chain_prev and chain_hash written with the "
        "row; pre-chain rows predate the write-time chain and are covered only by "
        "the export-time chain_link. Run verify_write_time_chain on this file."
    )
    return summary


# --- RFC 3161 token parsing (standard library only) -------------------------
#
# Enough DER to read a TimeStampResp: its PKIStatus, and inside the token the
# TSTInfo messageImprint digest and genTime. The signature over the token is
# checked by openssl (``_verify_token_signature``); this parser never claims to.

_OID_SIGNED_DATA = bytes.fromhex("2a864886f70d010702")  # 1.2.840.113549.1.7.2
_OID_TST_INFO = bytes.fromhex("2a864886f70d010910 0104".replace(" ", ""))  # ...1.9.16.1.4


def _der_read(buf: bytes, pos: int) -> tuple[int, bytes, int]:
    """One TLV at ``pos``: (tag byte, value bytes, position after it)."""
    if pos >= len(buf):
        raise ValueError("DER: unexpected end of data")
    tag = buf[pos]
    pos += 1
    length = buf[pos]
    pos += 1
    if length & 0x80:
        n = length & 0x7F
        if n == 0 or n > 4:
            raise ValueError("DER: unsupported length encoding")
        length = int.from_bytes(buf[pos : pos + n], "big")
        pos += n
    end = pos + length
    if end > len(buf):
        raise ValueError("DER: length exceeds data")
    return tag, buf[pos:end], end


def _der_children(value: bytes) -> list[tuple[int, bytes]]:
    out: list[tuple[int, bytes]] = []
    pos = 0
    while pos < len(value):
        tag, inner, pos = _der_read(value, pos)
        out.append((tag, inner))
    return out


def parse_timestamp_response(der: bytes) -> dict[str, Any]:
    """Read status, message imprint and generation time from a TimeStampResp.

    Returns ``{"status": int, "imprint_hex": str | None, "gen_time": str | None}``.
    Raises ValueError on anything that is not a TimeStampResp. Does NOT verify
    the signature: see verify_write_time_chain for what is and is not checked.
    """
    tag, body, _ = _der_read(der, 0)
    if tag != 0x30:
        raise ValueError("DER: TimeStampResp must be a SEQUENCE")
    parts = _der_children(body)
    if not parts or parts[0][0] != 0x30:
        raise ValueError("DER: PKIStatusInfo missing")
    status_parts = _der_children(parts[0][1])
    if not status_parts or status_parts[0][0] != 0x02:
        raise ValueError("DER: PKIStatus missing")
    status = int.from_bytes(status_parts[0][1], "big") if status_parts[0][1] else 0
    result: dict[str, Any] = {"status": status, "imprint_hex": None, "gen_time": None}
    if len(parts) < 2:
        return result
    # ContentInfo { contentType OID, [0] EXPLICIT SignedData }
    ci = _der_children(parts[1][1])
    if len(ci) < 2 or ci[0][0] != 0x06 or ci[0][1] != _OID_SIGNED_DATA:
        return result
    signed = _der_children(ci[1][1])  # [0] EXPLICIT -> SignedData SEQUENCE
    if not signed or signed[0][0] != 0x30:
        return result
    sd = _der_children(signed[0][1])
    # SignedData { version, digestAlgorithms, encapContentInfo, ... }
    if len(sd) < 3 or sd[2][0] != 0x30:
        return result
    eci = _der_children(sd[2][1])
    if len(eci) < 2 or eci[0][0] != 0x06 or eci[0][1] != _OID_TST_INFO:
        return result
    octets = _der_children(eci[1][1])  # [0] EXPLICIT -> OCTET STRING
    if not octets or octets[0][0] != 0x04:
        return result
    tst_tag, tst_body, _ = _der_read(octets[0][1], 0)
    if tst_tag != 0x30:
        return result
    tst = _der_children(tst_body)
    # TSTInfo { version, policy, messageImprint, serialNumber, genTime, ... }
    if len(tst) >= 3 and tst[2][0] == 0x30:
        imprint = _der_children(tst[2][1])
        if len(imprint) >= 2 and imprint[1][0] == 0x04:
            result["imprint_hex"] = imprint[1][1].hex()
    if len(tst) >= 5 and tst[4][0] == 0x18:
        result["gen_time"] = tst[4][1].decode("ascii", errors="replace")
    return result


def find_openssl(preferred: str | None = None) -> str | None:
    """Path of an openssl that can verify a timestamp against a non-root
    certificate (``ts -verify -partial_chain``), or None. LibreSSL, the
    openssl macOS ships, lacks the option and is reported as unusable."""
    import shutil
    import subprocess

    path = preferred or shutil.which("openssl")
    if not path:
        return None
    try:
        out = subprocess.run([path, "version"], capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    return None if "LibreSSL" in out or not out.startswith("OpenSSL") else path


def _token_verification_time(gen_time: str | None) -> int | None:
    """Epoch seconds of a TSTInfo genTime (``YYYYMMDDHHMMSS[.fff]Z``). The
    signature is checked at this time, so a token stays verifiable after the
    signing certificate expires."""

    if not gen_time:
        return None
    try:
        when = datetime.strptime(gen_time[:14], "%Y%m%d%H%M%S").replace(tzinfo=UTC)
    except ValueError:
        return None
    return int(when.timestamp())


def _as_pem(path: str) -> bytes:
    import base64

    data = open(path, "rb").read()
    if b"-----BEGIN CERTIFICATE-----" in data:
        return data
    body = base64.encodebytes(data).replace(b"\n", b"")
    lines = [body[i : i + 64] for i in range(0, len(body), 64)]
    return b"-----BEGIN CERTIFICATE-----\n" + b"\n".join(lines) + b"\n-----END CERTIFICATE-----\n"


def _verify_token_signature(
    der: bytes, statement: bytes, roots: list[str], gen_time: str | None, openssl: str
) -> tuple[str, str]:
    """Run ``openssl ts -verify`` once per supplied certificate.

    Returns ("verified", ""), ("invalid", reason) when openssl checked and
    rejected the token for every certificate, or ("not_checked", reason)
    when openssl could not run the check."""
    import os
    import subprocess
    import tempfile

    attime = _token_verification_time(gen_time)
    errors: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        tsr = os.path.join(tmp, "token.tsr")
        data = os.path.join(tmp, "statement")
        with open(tsr, "wb") as fh:
            fh.write(der)
        with open(data, "wb") as fh:
            fh.write(statement)
        for i, root in enumerate(roots):
            ca = os.path.join(tmp, f"ca{i}.pem")
            try:
                with open(ca, "wb") as fh:
                    fh.write(_as_pem(root))
            except OSError as exc:
                return "not_checked", f"cannot read {root}: {exc}"
            cmd = [openssl, "ts", "-verify", "-data", data, "-in", tsr, "-CAfile", ca, "-partial_chain"]
            if attime is not None:
                cmd += ["-attime", str(attime)]
            try:
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            except (OSError, subprocess.SubprocessError) as exc:
                return "not_checked", f"openssl did not run: {exc}"
            output = (proc.stdout + proc.stderr).strip()
            if proc.returncode == 0 and "Verification: OK" in output:
                return "verified", ""
            if "Verification: FAILED" not in output:
                return "not_checked", f"openssl could not check the token: {output[-200:]}"
            errors.append(output.splitlines()[-1] if output else "Verification: FAILED")
    return "invalid", (errors[-1] if errors else "Verification: FAILED")[:200]


def _check_anchor_token(
    anchor: dict[str, Any],
    statement: bytes,
    tsa_roots: list[str] | None,
    openssl: str | None = None,
) -> list[tuple[str, str]]:
    """Findings about one anchor's RFC 3161 token. Empty list = nothing wrong
    with what could be checked; the signature axis is reported separately.
    ``tsa_roots`` are paths to PEM or DER certificates the auditor trusts."""
    import base64

    findings: list[tuple[str, str]] = []
    try:
        der = base64.b64decode(anchor.get("token_der_b64") or "")
        parsed = parse_timestamp_response(der)
    except Exception as exc:  # noqa: BLE001 - any parse failure is one finding
        return [("anchor_token_unparseable", str(exc))]
    if parsed["status"] not in (0, 1):
        findings.append(("anchor_token_not_granted", f"PKIStatus={parsed['status']}"))
    digest = hashlib.sha256(statement).hexdigest()
    if parsed["imprint_hex"] is None:
        findings.append(("anchor_token_imprint_missing", "no TSTInfo messageImprint"))
    elif parsed["imprint_hex"] != digest:
        findings.append(
            ("anchor_token_imprint_mismatch", f"token covers {parsed['imprint_hex'][:16]}…")
        )
    if not tsa_roots:
        findings.append(("anchor_token_signature_not_checked", "no --tsa-root supplied"))
        return findings
    tool = find_openssl(openssl)
    if tool is None:
        findings.append(
            ("anchor_token_signature_not_checked", "needs OpenSSL 1.1 or later on PATH (LibreSSL lacks -partial_chain)")
        )
        return findings
    outcome, reason = _verify_token_signature(
        der, statement, list(tsa_roots), parsed.get("gen_time"), tool
    )
    if outcome == "invalid":
        findings.append(("anchor_token_signature_invalid", reason))
    elif outcome == "not_checked":
        findings.append(("anchor_token_signature_not_checked", reason))
    return findings


#: Findings that make the verdict "failed". Everything else leaves it
#: "unverified" (with the reason) or, when absent, "verified".
FAILING_FINDINGS = frozenset(
    {
        "hash_mismatch",
        "sequence_gap",
        "sequence_duplicate",
        "link_break",
        "truncated_tail",
        "anchor_mismatch",
        "anchor_statement_mismatch",
        "anchor_token_imprint_mismatch",
        "anchor_token_signature_invalid",
        "anchor_token_not_granted",
        "origin_signature_invalid",
        "unchained_after_chain_start",
        "unknown_chain_alg",
        "legacy_export_chain_failed",
    }
)


def _load_origin_pubkey(path: str) -> bytes:
    """SPKI DER bytes from a PEM or DER public-key file."""
    from pathlib import Path

    raw = Path(path).read_bytes()
    if b"BEGIN" in raw:
        from cryptography.hazmat.primitives import serialization

        pub = serialization.load_pem_public_key(raw)
        return pub.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    return raw


def _check_origin_signatures(
    anchor: dict[str, Any],
    statement: str,
    origin_pubkeys: list[str] | None,
) -> list[tuple[str, str]]:
    """Findings about CE origin signatures on one anchor (GAP-TR-03 / §13).

    Missing signatures → informational ``no_origin_signature`` (not failing).
    Present but no pubkey → ``origin_signature_not_checked`` (blocks verified).
    Present + pubkey + bad → ``origin_signature_invalid`` (failing).
    """
    from audit_origin_sign import verify_statement_signature

    sigs = anchor.get("signatures")
    if not isinstance(sigs, list) or not sigs:
        return [("no_origin_signature", "anchor has no producer origin signature")]
    if not origin_pubkeys:
        return [("origin_signature_not_checked", "no --origin-pubkey supplied")]
    keys: list[bytes] = []
    for path in origin_pubkeys:
        try:
            keys.append(_load_origin_pubkey(path))
        except Exception as exc:  # noqa: BLE001
            return [("origin_signature_not_checked", f"unreadable pubkey {path}: {exc}")]
    for sig in sigs:
        if not isinstance(sig, dict):
            return [("origin_signature_invalid", "signature entry is not an object")]
        if any(verify_statement_signature(statement, sig, public_key_spki_der=k) for k in keys):
            return []
    return [
        ("origin_signature_invalid", "no origin signature verified against supplied pubkeys")
    ]


def verify_write_time_chain(
    export: dict[str, Any],
    *,
    tsa_roots: list[str] | None = None,
    openssl: str | None = None,
    origin_pubkeys: list[str] | None = None,
) -> dict[str, Any]:
    """Verify the write-time chain and its anchors from an export file alone.

    Returns::

        {"verdict": "verified" | "failed" | "unverified",
         "findings": [{"finding": str, "seq": int | None, "event_id": str | None,
                       "detail": str}],
         "chained_rows": n, "pre_chain_rows": m, "first_seq", "last_seq",
         "anchors_checked": k, "newest_anchor_seq": int | None,
         "legacy_export_chain": "verified" | "failed" | "absent"}

    Axes, reported separately (one finding per occurrence):
      hash_mismatch          a row's stored chain_hash is not the hash of its
                             content and chain_prev (an edit)
      sequence_gap           chain_seq N present, N+1 absent, N+2 present (a
                             deleted row)
      sequence_duplicate     two rows share a chain_seq (a forged insertion)
      link_break             chain_prev is not the previous row's chain_hash
                             (reorder, insertion or rewrite)
      unchained_after_chain_start  a row without chain fields dated after the
                             first chained row (a live writer regression)
      pre_chain              a row written before the chain existed; labelled,
                             never verified
      unanchored_tail        rows newer than the newest anchor; not a failure,
                             but those rows are not yet dated by a third party
      truncated_tail         the newest anchor attests a seq the export does
                             not reach (rows removed after the anchor)
      no_anchor              the export carries no anchor at all
      anchor_mismatch        an anchor's chain_hash is not the export's at that seq
      anchor_token_*         the RFC 3161 token: parse, status, imprint, signature
      legacy_export_chain_failed   the sha256-v1 export-time chain fails
    """
    findings: list[dict[str, Any]] = []

    def add(finding: str, detail: str = "", seq: int | None = None, event_id: Any = None):
        findings.append(
            {"finding": finding, "seq": seq, "event_id": event_id, "detail": detail}
        )

    events = export.get("events")
    if not isinstance(events, list):
        add("malformed_export", "events is not a list")
        return {"verdict": "failed", "findings": findings}

    chained = [e for e in events if is_chained(e)]
    pre_chain = [e for e in events if not is_chained(e)]
    for e in pre_chain:
        add("pre_chain", "row predates the write-time chain", None, e.get("event_id"))

    # A pre-chain row dated after the chain began is not legacy: it is the
    # writer dropping the chain now. The July 2026 incident's shape, and it
    # must fail.
    # AUD-045: compare UTC instants. String min/compare amnestied post-start
    # hollow unchained rows when a later chained row used a smaller offset
    # wall clock as the "chain_since" string, and false-flagged pre-start rows.
    if chained:
        chained_instants = [
            t
            for t in (
                _parse_event_instant(e.get("timestamp")) for e in chained
            )
            if t is not None
        ]
        if chained_instants:
            chain_since_at = min(chained_instants)
            chain_since = chain_since_at.isoformat()
            for e in pre_chain:
                pre_at = _parse_event_instant(
                    e.get("timestamp") or e.get("ts")
                )
                if pre_at is None or pre_at > chain_since_at:
                    add(
                        "unchained_after_chain_start",
                        f"row dated after the chain began at {chain_since}",
                        None,
                        e.get("event_id"),
                    )

    rows: list[tuple[int, dict[str, Any]]] = []
    for e in chained:
        if e.get("chain_alg") != WRITE_TIME_CHAIN_ALGORITHM:
            add("unknown_chain_alg", str(e.get("chain_alg")), _seq(e), e.get("event_id"))
            continue
        seq = _seq(e)
        if seq is None:
            add("hash_mismatch", "chain_seq is not an integer", None, e.get("event_id"))
            continue
        rows.append((seq, e))
    rows.sort(key=lambda r: r[0])

    seen: set[int] = set()
    previous: tuple[int, dict[str, Any]] | None = None
    for seq, e in rows:
        if seq in seen:
            add("sequence_duplicate", "two rows carry this chain_seq", seq, e.get("event_id"))
        seen.add(seq)
        stored_prev = str(e.get("chain_prev") or "")
        expected = write_time_link_hash(stored_prev, e)
        if expected != e.get("chain_hash"):
            add("hash_mismatch", "stored chain_hash is not the hash of the row", seq, e.get("event_id"))
        if previous is not None:
            prev_seq, prev_event = previous
            if seq > prev_seq + 1:
                add(
                    "sequence_gap",
                    f"chain_seq {prev_seq + 1}..{seq - 1} missing",
                    prev_seq + 1,
                    None,
                )
            if seq == prev_seq + 1 and stored_prev != prev_event.get("chain_hash"):
                add("link_break", "chain_prev is not the previous row's chain_hash", seq, e.get("event_id"))
        elif seq == 1 and stored_prev != GENESIS_HASH:
            add("link_break", "the first row of a chain must have an empty chain_prev", seq, e.get("event_id"))
        previous = (seq, e)

    first_seq = rows[0][0] if rows else None
    last_seq = rows[-1][0] if rows else None
    by_seq = dict(rows)

    anchors = export.get("anchors")
    anchors = anchors if isinstance(anchors, list) else []
    newest_anchor_seq: int | None = None
    checked = 0
    tenant_id = str(export.get("tenant_id") or "")
    for anchor in anchors:
        try:
            a_seq = int(anchor.get("chain_seq"))
        except (TypeError, ValueError):
            add("anchor_mismatch", "anchor has no integer chain_seq")
            continue
        newest_anchor_seq = a_seq if newest_anchor_seq is None else max(newest_anchor_seq, a_seq)
        statement_text = str(anchor.get("statement") or "")
        try:
            stated = json.loads(statement_text)
        except ValueError:
            add("anchor_statement_mismatch", "statement is not JSON", a_seq)
            continue
        statement = statement_text.encode("utf-8")
        if hashlib.sha256(statement).hexdigest() != anchor.get("statement_sha256"):
            add("anchor_statement_mismatch", "statement_sha256 is not the hash of statement", a_seq)
        # ANC-01 names the account ``account_id``; statements made before the
        # ADCR names call it ``tenant_id``.
        stated_account = stated.get("account_id", stated.get("tenant_id"))
        if str(stated.get("chain_seq")) != str(a_seq) or (
            tenant_id and str(stated_account) != tenant_id
        ):
            add("anchor_statement_mismatch", "statement names another seq or tenant", a_seq)
        if a_seq in by_seq:
            if stated.get("chain_hash") != by_seq[a_seq].get("chain_hash"):
                add("anchor_mismatch", "anchored chain_hash differs from the export's row", a_seq, by_seq[a_seq].get("event_id"))
            else:
                checked += 1
        for finding, detail in _check_anchor_token(anchor, statement, tsa_roots, openssl):
            add(finding, detail, a_seq)
        for finding, detail in _check_origin_signatures(anchor, statement_text, origin_pubkeys):
            add(finding, detail, a_seq)

    if not anchors:
        add("no_anchor", "the export carries no qualified-timestamp anchor")
    elif last_seq is not None and newest_anchor_seq is not None:
        if newest_anchor_seq > last_seq:
            add(
                "truncated_tail",
                f"newest anchor attests seq {newest_anchor_seq}; export ends at {last_seq}",
                last_seq,
            )
        elif last_seq > newest_anchor_seq:
            add(
                "unanchored_tail",
                f"{last_seq - newest_anchor_seq} row(s) newer than the newest anchor (seq {newest_anchor_seq})",
                newest_anchor_seq + 1,
            )

    legacy = "absent"
    if export.get("chain_head") is not None:
        legacy = "verified" if verify_audit_export_chain(export) else "failed"
        if legacy == "failed":
            add("legacy_export_chain_failed", "the export-time sha256-v1 chain does not verify")

    names = {f["finding"] for f in findings}
    if names & FAILING_FINDINGS:
        verdict = "failed"
    elif (
        rows
        and checked
        and "anchor_token_signature_not_checked" not in names
        and "origin_signature_not_checked" not in names
        and "unanchored_tail" not in names
    ):
        verdict = "verified"
    else:
        verdict = "unverified"

    return {
        "verdict": verdict,
        "findings": findings,
        "chained_rows": len(rows),
        "pre_chain_rows": len(pre_chain),
        "first_seq": first_seq,
        "last_seq": last_seq,
        "anchors_checked": checked,
        "newest_anchor_seq": newest_anchor_seq,
        "legacy_export_chain": legacy,
    }


def main(argv: list[str] | None = None) -> int:
    """``python -m audit_export verify export.json [--tsa-root root.pem ...]``

    Offline: reads the file, prints the verdict and every finding, exits 0 on
    "verified", 2 on "unverified", 1 on "failed". No network, no credentials.
    """
    import argparse
    import sys

    parser = argparse.ArgumentParser(prog="audit_export", description=main.__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    v = sub.add_parser("verify", help="verify an audit export file offline")
    v.add_argument("export_file")
    v.add_argument(
        "--tsa-root",
        action="append",
        default=[],
        help="PEM or DER certificate of the timestamp authority to trust, e.g. the one the "
        "EU Trusted List publishes for the provider (repeatable)",
    )
    v.add_argument(
        "--openssl",
        default=None,
        help="path to OpenSSL 1.1 or later, used for the signature check (default: openssl on PATH)",
    )
    v.add_argument(
        "--origin-pubkey",
        action="append",
        default=[],
        help="PEM or DER SPKI of the ComplyEdge origin signing key (repeatable); "
        "required to check anchor signatures when present",
    )
    args = parser.parse_args(argv)
    with open(args.export_file, encoding="utf-8") as fh:
        export = json.load(fh)
    result = verify_write_time_chain(
        export,
        tsa_roots=args.tsa_root or None,
        openssl=args.openssl,
        origin_pubkeys=args.origin_pubkey or None,
    )
    print(f"verdict: {result['verdict']}")
    for key in ("chained_rows", "pre_chain_rows", "first_seq", "last_seq",
                "anchors_checked", "newest_anchor_seq", "legacy_export_chain"):
        print(f"{key}: {result.get(key)}")
    for f in result["findings"]:
        where = f" seq={f['seq']}" if f.get("seq") is not None else ""
        who = f" event_id={f['event_id']}" if f.get("event_id") else ""
        print(f"  {f['finding']}{where}{who}: {f['detail']}")
    sys.stdout.flush()
    return {"verified": 0, "failed": 1}.get(result["verdict"], 2)


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
