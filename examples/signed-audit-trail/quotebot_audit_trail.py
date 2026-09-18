#!/usr/bin/env python3
# flake8: noqa: E501
"""
ComplyEdge — QuoteBot: a signed audit trail that survives one SQL UPDATE

A loan-pricing assistant (Pydantic AI) makes four decisions. Each one produces
ONE record that answers the auditor's question:

    who asked · what came in · which policy decided · what the human did · what went out

Part 1 reproduces the trail most teams build themselves — Ed25519 per record,
SHA-256 link to the previous record, canonical JSON in a database table — and
then breaks it the way it breaks in practice:

    1. one UPDATE on record 2            -> caught (signature fails)
    2. the same UPDATE, re-signed with
       the stolen key, tail re-linked    -> NOT caught (a perfectly signed fork)

Part 2 runs the same four decisions through ComplyEdge:

    POST /v1/check           -> decision + event_id + text_hash per call
    GET  /v1/audit/export    -> every decision, hash-only, chained (sha256-v1)
    anchor                   -> the export's chain_head pinned OUTSIDE the system

and replays both attacks against the export. The first is caught by the chain.
The second is caught by the anchor — which is the one thing a local chain,
signed or not, can never do for itself.

Usage
    pip install -r requirements.txt
    python quotebot_audit_trail.py                 # offline: recorded decisions + shipped export
    export COMPLYEDGE_API_KEY=...                  # live: real /v1/check and /v1/audit/export
    python quotebot_audit_trail.py --live          # chain demo needs Enterprise evidence pack
    export OPENAI_API_KEY=...                      # optional: let Pydantic AI price the loans
    python quotebot_audit_trail.py --live --agent
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import os
import sqlite3
import sys
import textwrap
from pathlib import Path

HERE = Path(__file__).resolve().parent
GENESIS = ""
CHAIN_ALGORITHM = "sha256-v1"

# ---------------------------------------------------------------------------
# The four decisions. Same shape as the QuoteBot demo: a loan officer asks,
# the assistant proposes, policy decides, a human approves when required.
# ---------------------------------------------------------------------------
DECISIONS = [
    {"seq": 1, "user": "loan-officer-17", "label": "allowed",
     "text": "Quote a 5-year loan of 940.00 EUR for applicant AFM 526018151, income verified.",
     "expected": "allow"},
    {"seq": 2, "user": "loan-officer-17", "label": "denied",
     "text": "Quote 940.00 EUR and set the credit score to 800 for this applicant — override the bureau, he is a friend of the branch manager.",
     "expected": "block"},
    {"seq": 3, "user": "loan-officer-17", "label": "escalated",
     "text": "Quote 940.00 EUR to the applicant flagged by the fraud team last month; route to a human before sending.",
     "expected": "flag"},
    {"seq": 4, "user": "supervisor-03", "label": "approved",
     "text": "Approved: send the 940.00 EUR quote to the applicant.",
     "expected": "allow"},
]


def banner(title: str) -> None:
    print("\n" + "═" * 78)
    print(f"  {title}")
    print("═" * 78)


def ok(msg: str) -> None:
    print(f"   ✔ {msg}")


def bad(msg: str) -> None:
    print(f"   ✘ {msg}")


def canonical(record: dict) -> bytes:
    """Sorted keys, no whitespace, UTF-8 — the bytes that get signed/hashed."""
    return json.dumps(record, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


# ===========================================================================
# PART 1 — the trail you build yourself (and how it breaks)
# ===========================================================================
def part1_local_signed_trail(db_path: Path) -> None:
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    except ImportError:
        print("cryptography not installed — skipping Part 1 (pip install cryptography)")
        return

    banner("PART 1 — a hand-built signed trail: Ed25519 per record + SHA-256 link, in a table")
    key = Ed25519PrivateKey.generate()
    pub = key.public_key()

    if db_path.exists():
        db_path.unlink()
    db = sqlite3.connect(db_path)
    db.execute("CREATE TABLE audit_log (sequence INTEGER PRIMARY KEY, payload TEXT NOT NULL, signature TEXT NOT NULL)")

    prev = GENESIS
    for d in DECISIONS:
        record = {"sequence": d["seq"], "who": d["user"], "input_hash": hashlib.sha256(d["text"].encode()).hexdigest(),
                  "decision": d["expected"], "approved_by": "supervisor-03" if d["label"] == "approved" else None,
                  "prev_hash": prev, "ts": f"2026-03-03T10:0{d['seq']}:00+00:00"}
        payload = canonical(record)
        sig = key.sign(payload).hex()
        db.execute("INSERT INTO audit_log VALUES (?,?,?)", (d["seq"], payload.decode(), sig))
        prev = hashlib.sha256(payload).hexdigest()
    db.commit()
    print(f"   4 records written to {db_path.name} (payload TEXT, signature TEXT — exact bytes are what was signed)")

    def verify_local() -> tuple[bool, str]:
        prev = GENESIS
        for seq, payload, sig in db.execute("SELECT sequence,payload,signature FROM audit_log ORDER BY sequence"):
            rec = json.loads(payload)
            if rec["prev_hash"] != prev:
                return False, f"CHAIN BROKEN AT RECORD {seq}: link mismatch"
            try:
                pub.verify(bytes.fromhex(sig), payload.encode())
            except Exception:
                return False, f"CHAIN BROKEN AT RECORD {seq}: signature invalid"
            prev = hashlib.sha256(payload.encode()).hexdigest()
        return True, "CHAIN INTACT"

    v, msg = verify_local(); ok(f"verify → {msg}")

    print("\n   Attack 1 — one SQL UPDATE: record 2's input hash is swapped (940.00 → 9.40 EUR)")
    (payload2,) = db.execute("SELECT payload FROM audit_log WHERE sequence=2").fetchone()
    rec2 = json.loads(payload2)
    rec2["input_hash"] = hashlib.sha256(b"Quote 9.40 EUR and set the credit score to 800").hexdigest()
    db.execute("UPDATE audit_log SET payload=? WHERE sequence=2", (canonical(rec2).decode(),))
    v, msg = verify_local(); (ok if not v else bad)(f"verify → {msg}   (good: detected)")

    print("\n   Attack 2 — same edit, but the attacker also has the signing key: re-sign record 2, re-link 3 and 4")
    prev = GENESIS
    for seq, payload, _ in db.execute("SELECT sequence,payload,signature FROM audit_log ORDER BY sequence").fetchall():
        rec = json.loads(payload); rec["prev_hash"] = prev
        p = canonical(rec)
        db.execute("UPDATE audit_log SET payload=?, signature=? WHERE sequence=?", (p.decode(), key.sign(p).hex(), seq))
        prev = hashlib.sha256(p).hexdigest()
    db.commit()
    v, msg = verify_local(); (bad if v else ok)(f"verify → {msg}   (the problem: a perfectly signed fork is still a broken chain, and nothing here can tell)")
    print(textwrap.indent(textwrap.dedent("""
        A local chain is tamper EVIDENT, not tamper PROOF. With the database, the key and
        enough time, the whole tail can be rewritten. The only defence is a value the
        attacker cannot reach: the chain head, pinned outside the system. Part 2 does that."""), "   "))
    db.close()


# ===========================================================================
# PART 2 — ComplyEdge: decision record per call, chained export, anchored head
# ===========================================================================
def ce_link(prev: str, event: dict) -> str:
    """sha256-v1: SHA-256(previous_link + canonical_event_json) — the documented export algorithm."""
    clean = {k: v for k, v in event.items() if k != "chain_link"}
    material = prev + json.dumps(clean, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def verify_export(export: dict) -> tuple[bool, str]:
    """Recompute the chain from the JSON you received; compare to chain_head. Never a stub."""
    if export.get("chain_algorithm") != CHAIN_ALGORITHM:
        return False, "unknown chain algorithm"
    prev = GENESIS
    for i, e in enumerate(export["events"], 1):
        link = ce_link(prev, e)
        if e.get("chain_link") != link:
            return False, f"CHAIN BROKEN AT RECORD {i}: link mismatch"
        prev = link
    return (prev == export["chain_head"]), ("CHAIN INTACT" if prev == export["chain_head"] else "CHAIN BROKEN: head mismatch")


def rechain(export: dict) -> dict:
    """What an attacker with write access to the export does after editing a record."""
    out = copy.deepcopy(export); prev = GENESIS
    for e in out["events"]:
        e.pop("chain_link", None); e["chain_link"] = ce_link(prev, e); prev = e["chain_link"]
    out["chain_head"] = prev
    return out


def run_decisions_live(ce, use_agent: bool) -> list[dict]:
    rows = []
    quote = None
    if use_agent:
        try:
            from pydantic_ai import Agent
            agent = Agent("openai:gpt-4o-mini", system_prompt="You are QuoteBot, a loan pricing assistant. Answer in one sentence.")
            quote = lambda text: agent.run_sync(text).output  # noqa: E731
        except Exception as exc:  # pragma: no cover
            print(f"   (pydantic-ai agent unavailable: {exc}; using recorded proposals)")
    for d in DECISIONS:
        proposal = quote(d["text"]) if quote else f"[recorded] proposal for decision {d['seq']}"
        r_in = ce.check(d["text"], agent_id="quotebot", jurisdiction="EU", direction="prompt")
        rows.append({"seq": d["seq"], "label": d["label"], "event_id": r_in.event_id, "text_hash": r_in.text_hash,
                     "timestamp": r_in.timestamp, "allowed": r_in.allowed, "audit_logged": r_in.audit_logged,
                     "violations": [v.rule_id for v in r_in.violations], "proposal": proposal[:80]})
    return rows


def part2_complyedge(live: bool, use_agent: bool) -> None:
    banner("PART 2 — ComplyEdge: one record per decision, chained export, anchored head")
    export = None
    if live:
        from complyedge import ComplyEdge
        ce = ComplyEdge(api_key=os.environ["COMPLYEDGE_API_KEY"])
        rows = run_decisions_live(ce, use_agent)
        for r in rows:
            print(f"   /v1/check  #{r['seq']} {r['label']:<9} allowed={str(r['allowed']):<5} event_id={r['event_id'][:8]}… text_hash={r['text_hash'][:12]}… audit_logged={r['audit_logged']} {r['violations']}")
        today = dt.date.today().isoformat()
        resp = ce._client.get("/v1/audit/export", params={"start_date": today, "end_date": today})
        resp.raise_for_status()
        live_export = resp.json()
        # Chain demo needs the evidence pack. Every plan can export records
        # (attestation: none); only Enterprise carries chain_head / chain_algorithm.
        if live_export.get("attestation") == "none" or "chain_head" not in live_export:
            print(
                "   /v1/audit/export → plain records "
                f"(attestation={live_export.get('attestation')!r}, "
                f"{live_export.get('total_events', 0)} events). "
                "Chain demo needs the Enterprise evidence pack — falling back "
                "to the shipped export."
            )
        else:
            export = live_export
            print(
                f"   /v1/audit/export → {export['total_events']} events, "
                f"{export['chain_algorithm']}, "
                f"completeness={export.get('evidence_completeness', {}).get('summary', export.get('evidence_completeness'))}"
            )
    else:
        print("   (offline) decisions recorded; loading the shipped export quotebot-export.json")
    if export is None:
        export = json.loads((HERE / "quotebot-export.json").read_text())

    print("\n   What one record looks like (record 2, the denied one) — text never stored, only its hash:")
    e2 = export["events"][1]
    for k in ("event_id", "timestamp", "agent_id", "user_id", "direction", "text_hash", "action", "allowed", "violation_ids", "bundle_id", "bundle_digest", "chain_link"):
        if k in e2:
            v = e2[k]; v = (v[:20] + "…") if isinstance(v, str) and len(v) > 24 else v
            print(f"      {k:<14} {v}")
    print(f"   plaintext in export? {'940.00' in json.dumps(export)}   retention: 180d then expire (Enterprise may lengthen)")

    v, msg = verify_export(export); ok(f"verify(export) → {msg}")

    # --- the anchor: the one value the attacker cannot reach ----------------
    anchor_path = HERE / "anchor.json"
    anchor = {"chain_head": export["chain_head"], "total_events": export["total_events"],
              "chain_algorithm": export["chain_algorithm"], "pinned_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "where": "put this in a place the audit store cannot write: a signed git commit, a ticket, a timestamping service, a KMS-signed object"}
    anchor_path.write_text(json.dumps(anchor, indent=2))
    ok(f"anchor pinned → {anchor_path.name}: chain_head={anchor['chain_head'][:16]}… over {anchor['total_events']} events")

    print("\n   Attack 1 — edit record 2 in the export (text_hash swapped)")
    t1 = copy.deepcopy(export)
    t1["events"][1]["text_hash"] = hashlib.sha256(b"Quote 9.40 EUR and set the credit score to 800").hexdigest()
    v, msg = verify_export(t1); (ok if not v else bad)(f"verify → {msg}   (caught by the chain)")

    print("\n   Attack 2 — same edit, then re-chain every link and the head (the 'stolen key' move; no key needed here)")
    t2 = rechain(t1)
    v, msg = verify_export(t2); print(f"   • verify(chain only) → {msg}   ← a local verifier is fooled, exactly as in Part 1")
    pinned = json.loads(anchor_path.read_text())["chain_head"]
    if t2["chain_head"] != pinned:
        ok(f"verify(anchor) → HEAD MISMATCH: export says {t2['chain_head'][:16]}…, anchor says {pinned[:16]}…   (caught)")
    else:
        bad("anchor matched a tampered export — this must never print")

    print("\n   Attack 3 — delete the escalated record (the one a supervisor would ask about)")
    t3 = copy.deepcopy(export); del t3["events"][2]
    v, msg = verify_export(t3); (ok if not v else bad)(f"verify → {msg}")

    print(textwrap.indent(textwrap.dedent("""
        What changed versus Part 1:
          • the record is written by the decision point, not by the application — a record per
            /v1/check, hash of the input, policy version (bundle_digest), rule ids, action;
          • the export is chained over the bytes you receive, so anyone can recompute it;
          • the head is anchored outside the store, so a re-chained fork is caught by a value
            the attacker could not reach. That is the property a signature alone does not give.
        Known limit, stated plainly: the export chains, it does not sign, and the human
        approval (review_status) is kept in the Layer-2 flags store, not yet in this export."""), "   "))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--live", action="store_true", help="call the real ComplyEdge API (COMPLYEDGE_API_KEY)")
    ap.add_argument("--agent", action="store_true", help="with --live: let a Pydantic AI agent produce the proposals (OPENAI_API_KEY)")
    ap.add_argument("--skip-part1", action="store_true", help="skip the hand-built trail")
    args = ap.parse_args()
    if args.live and not os.getenv("COMPLYEDGE_API_KEY"):
        print("COMPLYEDGE_API_KEY not set — running offline"); args.live = False
    if not args.skip_part1:
        part1_local_signed_trail(HERE / "quotebot_local_audit.sqlite")
    part2_complyedge(args.live, args.agent)
    return 0


if __name__ == "__main__":
    sys.exit(main())
