# QuoteBot — a signed audit trail that survives one SQL UPDATE

**The question this answers:** *"My AI assistant priced a loan. Six months later the auditor asks who
asked, what came in, which rule decided, who approved it, and whether that record is the original.
Can I prove it — even against someone who has my database and my signing key?"*

This is the ask that comes up every time a team ships an agent into a regulated workflow and then
builds its own "signed audit log" — Ed25519 per record, a SHA-256 link to the previous one, canonical
JSON in a Postgres table. The example runs that design, breaks it the way it breaks in practice, and
then runs the same four decisions through ComplyEdge.

## Run it

```bash
cd examples/signed-audit-trail
pip install -r requirements.txt
python quotebot_audit_trail.py            # offline: recorded decisions + the shipped export
```

```bash
export COMPLYEDGE_API_KEY=ce_live_...     # live: /v1/check + export; chain demo needs Enterprise evidence pack
python quotebot_audit_trail.py --live
export OPENAI_API_KEY=...                 # optional: a Pydantic AI agent writes the loan proposals
python quotebot_audit_trail.py --live --agent
```

Stack reproduced: **Pydantic AI** agent (optional), **Ed25519** via `cryptography`, an
`audit_log(sequence, payload TEXT, signature TEXT)` table (SQLite stands in for Postgres), canonical JSON
`sort_keys=True, separators=(",",":")`.

## What it prints

**Part 1 — the hand-built trail.** Four records: allowed, denied, escalated, approved.

| Attack | Local Ed25519 + hash chain |
|---|---|
| `UPDATE audit_log` on record 2 (940.00 → 9.40 EUR) | caught — signature invalid |
| Same edit, re-signed with the stolen key, records 3–4 re-linked | **not caught — "CHAIN INTACT"** |

A signed chain is tamper *evident*, not tamper *proof*. With the table and the key, the whole tail can
be rewritten and every verifier you own will say yes.

**Part 2 — ComplyEdge.** Each decision goes through `POST /v1/check`; `GET /v1/audit/export`
returns every decision as a hash-only record. On **Enterprise** the export is an evidence pack
chained with `sha256-v1` — `link = SHA-256(previous_link + canonical_json(record))`, `chain_head`
over the whole export. Free/Developer get the same records with `attestation: "none"` (no chain);
`--live` falls back to the shipped fixture when the key is not Enterprise so the chain attacks still run.
The example then pins `chain_head` to an **anchor** the audit store cannot write to.

| Attack | Chain | Anchor |
|---|---|---|
| Edit record 2 in the export | caught | — |
| Edit + re-chain every link and the head | *fooled* (same as Part 1) | **caught — head mismatch** |
| Delete the escalated record | caught | — |

The anchor is the one thing a local chain, signed or not, cannot give itself: a value the attacker could
not reach. Put it in a signed git commit, a ticket, a timestamping service, or a KMS-signed object —
whatever your auditor will accept.

## What a ComplyEdge record carries

Written by the decision point, not by the application, so it cannot be skipped by the code path that
made the call:

```
event_id · timestamp · agent_id · user_id · direction · text_hash (SHA-256, text never stored)
bundle_id + bundle_digest (which policy version decided) · violation_ids · action · allowed · chain_link
```

Retention is 180 days by default (`AUDIT_RETENTION_DAYS`), then records expire.
Enterprise tenants may lengthen retention (or set never-expire) for **new** rows only;
older rows keep the ttl they were written with. The export refuses to present
itself as complete if any record lacks `text_hash`, `agent_id` or `timestamp` (`evidence_completeness`).

## Limits, stated plainly

- The export **chains, it does not sign**. Integrity comes from recomputing the chain over the bytes you
  received plus the external anchor — not from a ComplyEdge signature.
- The human approval ("supervisor-03 approved") lives in the review-flags store, not yet in the export.
  In this example it is a fourth `/v1/check` call by the supervisor, which is what gets chained.
- `quotebot-export.json` is a recorded fixture produced by the same chain code the API uses, so the
  offline run exercises the real algorithm; `--live` replaces it with a real export.

## Files

| File | What |
|---|---|
| `quotebot_audit_trail.py` | The runnable example (Part 1 + Part 2) |
| `quotebot-export.json` | Recorded `/v1/audit/export` for the four decisions |
| `requirements.txt` | `complyedge`, `cryptography`, optional `pydantic-ai` |

Generated on each run and safe to delete: `quotebot_local_audit.sqlite`, `anchor.json`.
