"""GAP-TR-05 / AUD-222: SDK receipt journal never stores prompt text."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sdks" / "python"))

from complyedge import ComplianceResult, ReceiptJournal  # noqa: E402
from complyedge.receipt_journal import ReceiptEntry  # noqa: E402


def _result(**overrides) -> ComplianceResult:
    base = dict(
        event_id="e-1",
        allowed=True,
        violations=[],
        latency_ms=1,
        bundle_version="unknown",
        evaluated_rules=[],
        text_hash="abc",
        text_hash_alg="hmac-sha256-1",
        bundle_digest="deadbeef",
        timestamp="2026-10-16T12:00:00Z",
        engine_path="opa",
        audit_logged=True,
        sandbox=False,
    )
    base.update(overrides)
    return ComplianceResult(**base)


def test_append_result_writes_linkage_not_text(tmp_path):
    path = tmp_path / "receipts.jsonl"
    journal = ReceiptJournal(path)
    journal.append_result(_result())
    rows = list(journal.iter_entries())
    assert len(rows) == 1
    row = rows[0]
    assert row["event_id"] == "e-1"
    assert row["text_hash"] == "abc"
    assert row["bundle_digest"] == "deadbeef"
    assert "text" not in row
    assert "prompt" not in row
    raw = path.read_text(encoding="utf-8")
    assert "the secret prompt" not in raw


def test_refuses_text_field(tmp_path):
    journal = ReceiptJournal(tmp_path / "r.jsonl")
    with pytest.raises(ValueError, match="refuses"):
        journal.append({"event_id": "e", "text": "prompt body"})


def test_skips_sandbox_by_default(tmp_path):
    journal = ReceiptJournal(tmp_path / "r.jsonl")
    assert journal.append_result(_result(sandbox=True, event_id="sand")) is None
    assert journal.latest(5) == []


def test_get_returns_last_for_event_id(tmp_path):
    journal = ReceiptJournal(tmp_path / "r.jsonl")
    journal.append_result(_result(event_id="e-1", text_hash="a"))
    journal.append_result(_result(event_id="e-1", text_hash="b"))
    assert journal.get("e-1")["text_hash"] == "b"
    assert journal.get("missing") is None


def test_receipt_entry_round_trip(tmp_path):
    journal = ReceiptJournal(tmp_path / "r.jsonl")
    entry = ReceiptEntry(
        event_id="e-9",
        text_hash="h",
        text_hash_alg=None,
        bundle_digest=None,
        allowed=False,
        timestamp=None,
        recorded_at="2026-10-16T00:00:00Z",
        audit_logged=True,
        sandbox=False,
    )
    journal.append(entry)
    assert journal.get("e-9")["allowed"] is False
    # File is one JSON object per line
    line = (tmp_path / "r.jsonl").read_text(encoding="utf-8").strip()
    assert json.loads(line)["event_id"] == "e-9"


def test_creates_parent_dirs(tmp_path):
    path = tmp_path / "nested" / "dir" / "r.jsonl"
    journal = ReceiptJournal(path)
    journal.append_result(_result(event_id="nested-1"))
    assert path.is_file()


def test_append_result_skips_empty_event_id(tmp_path):
    journal = ReceiptJournal(tmp_path / "r.jsonl")
    assert journal.append_result(_result(event_id="")) is None
    assert list(journal.iter_entries()) == []


def test_append_mapping_requires_event_id(tmp_path):
    journal = ReceiptJournal(tmp_path / "r.jsonl")
    with pytest.raises(ValueError, match="event_id"):
        journal.append({"text_hash": "x"})


def test_latest_zero_and_skips_corrupt_lines(tmp_path):
    path = tmp_path / "r.jsonl"
    path.write_text(
        "\nnot-json\n" + json.dumps({"event_id": "ok", "text_hash": "h"}) + "\n",
        encoding="utf-8",
    )
    journal = ReceiptJournal(path)
    assert journal.latest(0) == []
    assert journal.latest(1)[0]["event_id"] == "ok"
    assert list(journal.iter_entries()) == [{"event_id": "ok", "text_hash": "h"}]


def test_iter_empty_when_file_missing(tmp_path):
    journal = ReceiptJournal(tmp_path / "missing.jsonl")
    assert list(journal.iter_entries()) == []
