"""Local append-only custody for check linkage.

Stores the fields a deployer needs to find a decision later: event_id,
text_hash, bundle_digest, timestamps. Never stores the prompt or answer.
Pairing text back to a record still needs the caller's own copy plus
``verify_input`` (server-side). This is not an offline chain/anchor verifier.
"""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

# Keys that must never land in the journal (prompt / answer / secrets).
_FORBIDDEN = frozenset(
    {
        "text",
        "prompt",
        "output",
        "input",
        "content",
        "message",
        "body",
        "password",
        "api_key",
        "secret",
        "token",
    }
)


@dataclass(frozen=True)
class ReceiptEntry:
    """One check linkage row. No prompt text."""

    event_id: str
    text_hash: str
    text_hash_alg: str | None
    bundle_digest: str | None
    allowed: bool
    timestamp: str | None
    recorded_at: str
    audit_logged: bool
    sandbox: bool

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class ReceiptJournal:
    """Append-only JSONL file of check linkage rows."""

    def __init__(self, path: str | os.PathLike[str]):
        self.path = Path(path)
        if self.path.parent and not self.path.parent.exists():
            self.path.parent.mkdir(parents=True, exist_ok=True)

    def append_result(self, result: Any, *, skip_sandbox: bool = True) -> ReceiptEntry | None:
        """Append from a ``ComplianceResult``. Skips sandbox by default."""
        sandbox = bool(getattr(result, "sandbox", False))
        if skip_sandbox and sandbox:
            return None
        event_id = str(getattr(result, "event_id", "") or "")
        if not event_id:
            return None
        entry = ReceiptEntry(
            event_id=event_id,
            text_hash=str(getattr(result, "text_hash", "") or ""),
            text_hash_alg=getattr(result, "text_hash_alg", None),
            bundle_digest=getattr(result, "bundle_digest", None),
            allowed=bool(getattr(result, "allowed", False)),
            timestamp=getattr(result, "timestamp", None),
            recorded_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            audit_logged=bool(getattr(result, "audit_logged", False)),
            sandbox=sandbox,
        )
        self.append(entry)
        return entry

    def append(self, entry: ReceiptEntry | Mapping[str, Any]) -> None:
        """Append one row. Rejects forbidden keys that would store text."""
        if isinstance(entry, ReceiptEntry):
            payload = entry.to_dict()
        else:
            payload = dict(entry)
            bad = _FORBIDDEN.intersection(k.lower() for k in payload)
            if bad:
                raise ValueError(
                    f"receipt journal refuses text/secret fields: {sorted(bad)}"
                )
            if not payload.get("event_id"):
                raise ValueError("receipt journal requires event_id")
            payload.setdefault(
                "recorded_at",
                datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            )
        line = json.dumps(payload, separators=(",", ":"), sort_keys=True)
        with self.path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")

    def get(self, event_id: str) -> dict[str, Any] | None:
        """Last row for ``event_id``, or None."""
        found: dict[str, Any] | None = None
        for row in self.iter_entries():
            if row.get("event_id") == event_id:
                found = row
        return found

    def latest(self, n: int = 1) -> list[dict[str, Any]]:
        """Newest ``n`` rows (file order; last lines win)."""
        if n < 1:
            return []
        rows = list(self.iter_entries())
        return rows[-n:]

    def iter_entries(self):
        """Yield each JSON object in file order. Skips blank/corrupt lines."""
        if not self.path.is_file():
            return
        with self.path.open("r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(row, dict):
                    yield row
