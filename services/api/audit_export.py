"""
Tamper-evident hash chain for enterprise audit trail exports.

Chains events at export time (no DynamoDB schema change). Each link is
SHA-256(previous_link + canonical_event_json). Verification recomputes the
chain and compares chain_head — never a stub (contrast AGT verify_chain defect).

EU AI Act Art 12 record-keeping / DD exhibit.
"""

from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

CHAIN_ALGORITHM = "sha256-v1"
GENESIS_HASH = ""

# ---------------------------------------------------------------------------
# Evidence completeness (incident AUD-001; see the audit evidence integrity
# ledger in the private repo — this file ships publicly, so no internal path)
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


class IncompleteEvidenceError(RuntimeError):
    """A post-contract audit record is missing Article 12 evidence fields.

    Raised rather than returned: an export is a legal artifact, and shipping a
    silently hollow one is worse than shipping none. If this fires, the write
    path is dropping evidence again — check for a second writer on the EVENT#
    keyspace before touching this module.
    """


def _missing_evidence(event: dict[str, Any]) -> list[str]:
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

    for event in events:
        missing = _missing_evidence(event)
        if not missing:
            complete += 1
            continue
        timestamp = str(event.get("timestamp") or event.get("ts") or "")
        target = (
            live_regressions
            if timestamp >= EVIDENCE_CONTRACT_SINCE
            else legacy_incomplete
        )
        target.append(f"{event.get('event_id', '<no event_id>')} missing {missing}")

    if live_regressions:
        raise IncompleteEvidenceError(
            f"{len(live_regressions)} record(s) written after "
            f"{EVIDENCE_CONTRACT_SINCE} are missing Article 12 evidence fields. "
            "The audit write path is dropping evidence: check that nothing "
            "overwrites the audit item after it is persisted (incident AUD-001). "
            f"First: {live_regressions[0]}"
        )

    summary: dict[str, Any] = {
        "required_fields": list(EVIDENCE_FIELDS),
        "complete": complete,
        "incomplete": len(legacy_incomplete),
    }
    if legacy_incomplete:
        summary["note"] = (
            "Records predating the 2026-07-25 audit-write fix (incident AUD-001) "
            "were overwritten in place by a telemetry dual-write and permanently "
            "lost their evidence fields. They are listed rather than hidden: this "
            "export is complete for every record written after that date."
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
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, dict):
        return {k: normalize_event(v) for k, v in value.items()}
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
    return json.dumps(
        normalize_event(payload), sort_keys=True, separators=(",", ":")
    )


def _link_hash(previous_hash: str, event: dict[str, Any]) -> str:
    material = previous_hash + canonical_event_json(event)
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def _sort_events_chronologically(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        events,
        key=lambda e: (e.get("timestamp") or "", e.get("event_id") or ""),
    )


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
    normalized = [normalize_event(e) for e in events]
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
