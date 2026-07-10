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
from typing import Any, Dict, List, Optional

CHAIN_ALGORITHM = "sha256-v1"
GENESIS_HASH = ""


def canonical_event_json(event: Dict[str, Any]) -> str:
    """Stable JSON for hashing — sorted keys, no whitespace."""
    payload = {k: v for k, v in event.items() if k != "chain_link"}
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str)


def _link_hash(previous_hash: str, event: Dict[str, Any]) -> str:
    material = previous_hash + canonical_event_json(event)
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def _sort_events_chronologically(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return sorted(
        events,
        key=lambda e: (e.get("timestamp") or "", e.get("event_id") or ""),
    )


def _compute_chain_head_in_order(events: List[Dict[str, Any]]) -> Optional[str]:
    """Walk events in export order; return None if any chain_link is invalid."""
    previous = GENESIS_HASH
    for event in events:
        clean = {k: v for k, v in event.items() if k != "chain_link"}
        link = _link_hash(previous, clean)
        if event.get("chain_link") != link:
            return None
        previous = link
    return previous


def build_hash_chain(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Build a tamper-evident hash chain over audit events.

    Returns events annotated with per-link ``chain_link``, plus envelope
    metadata ``chain_head`` and ``chain_algorithm``.
    """
    ordered = _sort_events_chronologically(events)
    previous = GENESIS_HASH
    chained_events: List[Dict[str, Any]] = []

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


def verify_audit_export_chain(export: Dict[str, Any]) -> bool:
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
