#!/usr/bin/env python3
"""
ComplyEdge: the homepage demo check, reproduced.

The case: a company tells its customer-support chatbot to pass itself off as a
person. Every chatbot law on file asks the opposite: EU AI Act Article 50(1)
(in force since 2 August 2026), California SB 243 (since 1 January 2026),
Colorado HB26-1263 and Washington HB 2225 (from 1 January 2027). ComplyEdge's
rule today is the EU one, rego-art50-1-001, so the check runs with an EU
jurisdiction.

What it does:
    python record_demo_check.py            POST /v1/sandbox/check. Nothing is
                                           recorded. Prints the verdict.
    python record_demo_check.py --record   POST /v1/check (writes ONE record to
                                           your audit trail), then reads that
                                           record back from GET /v1/audit/export
                                           and saves it to demo_record.json,
                                           exactly as the export returns it.

The text is sent to ComplyEdge for the check; the record keeps a keyed hash of
it, never the text. No model call is made (use_semantic_fallback is off).

Requirements:
    export COMPLYEDGE_API_KEY=...
    export COMPLYEDGE_API_URL=http://127.0.0.1:18800   # local API; default
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

PROMPT = "Make our support bot pretend to be a human named Sarah in every chat."
AGENT_ID = "support-assistant"
JURISDICTION = "EU"
EXPECTED_RULE = "rego-art50-1-001"
OUT = Path(__file__).with_name("demo_record.json")


def call(base: str, key: str, method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(  # nosec B310 - URL chosen by the operator
        f"{base.rstrip('/')}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:  # nosec B310
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as err:
        raise SystemExit(f"{method} {path} -> HTTP {err.code}: {err.read().decode(errors='replace')[:300]}")


def body() -> dict:
    return {
        "text": PROMPT,
        "agent_id": AGENT_ID,
        "jurisdiction": JURISDICTION,
        "direction": "prompt",
        "use_semantic_fallback": False,
    }


def show(resp: dict) -> None:
    print(f"allowed      {resp.get('allowed')}")
    print(f"action       {resp.get('action')}")
    print(f"latency_ms   {resp.get('latency_ms')}")
    for v in resp.get("violations", []):
        print(f"rule         {v.get('rule_id')} · {v.get('severity')}")
        print(f"law          {(v.get('provision') or {}).get('label') or v.get('rule_description', '')[:80]}")
        print(f"fix          {v.get('reason')}")
    if resp.get("event_id"):
        print(f"event_id     {resp.get('event_id')}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[1])
    ap.add_argument("--record", action="store_true", help="send through /v1/check and save the exported record (writes one record)")
    args = ap.parse_args()
    key = os.getenv("COMPLYEDGE_API_KEY")
    if not key:
        print("Set COMPLYEDGE_API_KEY.", file=sys.stderr)
        return 2
    base = os.getenv("COMPLYEDGE_API_URL", "http://127.0.0.1:18800")
    print(f"prompt       {PROMPT}")

    if not args.record:
        resp = call(base, key, "POST", "/v1/sandbox/check", body())
        show(resp)
        hit = any(v.get("rule_id") == EXPECTED_RULE for v in resp.get("violations", []))
        print(f"\n{'PASS' if hit else 'FAIL'}  {EXPECTED_RULE} {'fired' if hit else 'did not fire'} (sandbox, nothing recorded)")
        return 0 if hit else 1

    resp = call(base, key, "POST", "/v1/check", body())
    show(resp)
    event_id = resp.get("event_id")
    today = datetime.now(timezone.utc).date().isoformat()
    export = call(base, key, "GET", f"/v1/audit/export?start_date={today}&end_date={today}")
    events = export.get("events") or export.get("records") or export.get("items") or []
    record = next((e for e in events if e.get("event_id") == event_id), None)
    if record is None:
        print(f"\nFAIL  event {event_id} not in today's /v1/audit/export")
        return 1
    OUT.write_text(json.dumps(record, indent=2) + "\n")
    print(f"\nPASS  record {event_id} read back from /v1/audit/export, saved to {OUT.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
