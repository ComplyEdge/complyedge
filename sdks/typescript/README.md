# @complyedge/sdk

TypeScript/JavaScript SDK for [ComplyEdge](https://complyedge.io): prove what your AI decided, without keeping what it saw. Every `check()` runs against open EU AI Act rules that cite the law and leaves one record per decision, never a copy of the text.

Phrase rules run on every check. On a paid plan a clean pass then runs an injection check when the month's model budget covers it, which can block. The wider review runs only when you turn it on and that budget covers it. A rule block cites the article, and the record is kept outside your AI system.

![npm version](https://img.shields.io/npm/v/%40complyedge%2Fsdk)
![npm downloads](https://img.shields.io/npm/dw/%40complyedge%2Fsdk)
![license](https://img.shields.io/npm/l/%40complyedge%2Fsdk)

## Install

```bash
npm install @complyedge/sdk
```

Requires Node.js 18 or later. Get an API key at [dashboard.complyedge.io](https://dashboard.complyedge.io/?intent=get-started).

The SDK works in both ESM and CommonJS projects; no bundler-specific setup is required.

## Rotating your key

Keys are shown once, at creation, and stored as a hash: a lost key cannot be
recovered, only replaced. Rotate without downtime, in this order:

1. In the dashboard, open **API Key** and click **Rotate key** on the card
   (or **Rotate** on a row under Other active keys), then confirm. A new key
   is minted and shown once; the old one keeps working.
2. Put the new key in your integration (`COMPLYEDGE_API_KEY` or the `apiKey` you pass to the client) and deploy.
3. Back in the reveal, click **Revoke previous key**. Requests with the old key
   fail from that moment. If you need more time, **Keep both for now** and
   revoke it later from the API Key page, where every active key is listed.

Compromised key: revoke first (Revoke this key on the card, or Revoke on the
row), then rotate. Via the API the same flow is `POST /v1/account/api-keys`,
then `DELETE /v1/account/api-keys/{key_id}` for the old key.

## Company name on the public trust surface

Your public AI Trust Center and Enforcement Seal show one company name: the
one set in the dashboard under Account, Profile. `display_name` on
`PATCH /v1/tenant/trust` sets the same value, so an API call and the profile
never disagree. Email is your sign-in and cannot be changed from the dashboard.

## Package map

- [`@complyedge/mcp`](https://www.npmjs.com/package/@complyedge/mcp) runs the local, offline TrustLint MCP tools with `npx`.
- [`trustlint`](https://www.npmjs.com/package/trustlint) is the local Node.js CLI for offline rule checks.
- [`complyedge` on PyPI](https://pypi.org/project/complyedge/) is the Python SDK with the same enforcement API.
- [Documentation](https://complyedge.io/docs) covers the hosted API; the [trust portal](https://trust.complyedge.io) covers security and reliability information.

| | `@complyedge/sdk` | `trustlint` | `@complyedge/mcp` |
|---|:-:|:-:|:-:|
| Runs offline, no API key | No | Yes | Yes |
| Rego / OPA evaluation | Yes | No | No |
| Audit record outside your AI system | Yes | No | No |
| Bundled 63 YAML rules | No | Yes | Yes |
| Temporal / effective-date rules | No | No | No |
| ESM + CommonJS | Yes | Yes | ESM only |
| MCP host integration | No | No | Yes |

Temporal / effective-date evaluation lives in the Python engine only. A shared version number across npm and PyPI is not a parity claim.

## Version policy

The TypeScript SDK and Python `complyedge` package have independent semantic versions. A version number does not imply feature parity across languages; each release documents and tests its own supported API surface.

## Quick start

```typescript
import { ComplyEdgeClient } from "@complyedge/sdk";

const ce = new ComplyEdgeClient({ apiKey: process.env.COMPLYEDGE_API_KEY! });

const result = await ce.check("Score users based on their social behavior", {
  // What only you know, for an ADCR-complete record (optional; see below)
  decisionContext: {
    deciding_system: { version: "gpt-5.4-2026-08-01" },
    purpose_ref: "purpose:support-replies",
    data_categories: [],
  },
});

if (!result.allowed) {
  console.log("Blocked:", result.violations[0].ruleId);
  console.log("Why:", result.violations[0].ruleDescription);
  console.log("Audit event:", result.eventId);
}

// ComplyEdge keeps the decision, not the text: store eventId next to your own copy
appLog.info({ prompt: "Score users based on their social behavior", complyedgeEventId: result.eventId });
```

Blocked output:

```
Blocked: rego-art5-1c-001
Why: Regulation (EU) 2024/1689, Article 5(1)(c): the placing on the market, ...
Audit event: evt_01J...
```

### Try a case without recording it

`{ sandbox: true }` calls `POST /v1/sandbox/check`: the same rules, the same
tenant settings and the same verdict, but no audit entry, no usage and no
count against your plan's daily limit (sandbox calls have their own caps:
60 a minute, 1,000 a day). Use it to test cases before wiring an integration. A sandbox
result is never evidence: `result.sandbox` is `true` and `result.auditLogged`
is `false`.

```typescript
const trial = await ce.check("Score users based on their social behavior", { sandbox: true });
console.log(trial.allowed, trial.sandbox); // false true
```

## Configuration

```typescript
const ce = new ComplyEdgeClient({
  apiKey: process.env.COMPLYEDGE_API_KEY!,
  jurisdiction: "EU",   // default: "EU"
  agentId: "support-bot", // default: "default"
  timeout: 30_000,      // ms, default: 30_000
  region: "eu",         // "us" | "eu"; default: read from the key prefix (ce_eu_ -> eu)
  baseUrl: "https://eu.api.complyedge.io", // or COMPLYEDGE_API_URL; overrides region
});
```

### Regions

Two regions, one home per account, chosen when you sign up and create your first API key: EU
(`eu.api.complyedge.io`, key prefix `ce_eu_`) or US (`api.complyedge.io`, key
prefix `ce_`). The client reads the prefix and picks the host. To change the
region later, use Request a region change in the dashboard; you get a new key for it.
`baseUrl`, `region`, `COMPLYEDGE_API_URL`, and `COMPLYEDGE_REGION` only choose
which host to call. They do not change the account's region. Precedence, highest first:
`baseUrl` / `COMPLYEDGE_API_URL`, then `region` / `COMPLYEDGE_REGION`, then
the key prefix, then EU. A key presented to the other region's stack is
refused with `401 {"detail":{"error":"wrong_region","use":"<host>"}}` before any lookup.

The region is where your checks run and your audit records are stored. The prompt and the AI's answer are never stored. On a paid plan, after the phrase rules pass, the injection check sends that text to OpenAI in the US when the month's model budget covers it. The wider review sends it only when you turn it on and the month's model budget covers it.
It does not decide which laws are checked: the `jurisdiction` field on each
check does. No general law requires either region. US law does not require US
storage, and GDPR allows transfers outside the EU with safeguards such as
standard contractual clauses (Chapter V). Choose the region your own contracts
or customers ask for.

## `check(text, context?)`

Calls `POST /v1/check`. Phrase rules run on every check. On a paid plan a clean pass then runs an injection check when the month's model budget covers it, which can block. The wider review runs only when you turn it on and that budget covers it. Returns:

| Field | Type | Meaning |
|-------|------|---------|
| `allowed` | `boolean` | `false` means block: a request before your AI sees it, an answer before your user does |
| `status` | `"safe" \| "violation"` | Convenience mirror of `allowed` |
| `violations` | `ComplianceViolation[]` | Rule ID, `ruleDescription` (the rule's legal citation), severity, reason, confidence |
| `eventId` | `string` | Identifier of the audit record for this decision |
| `textHash` | `string` | Keyed hash (HMAC-SHA-256, your account's key) of the evaluated text; check it with `verifyInput` |
| `textHashAlg` | `string` | `"hmac-sha256-1"`; absent on records written before the keyed hash was introduced (plain SHA-256) |
| `auditLogged` | `boolean` | Whether the decision reached the audit record |
| `enginePath` | `string` | `opa`, `llm`, `hybrid`, `fallback_block` or `trustlint` |
| `latencyMs` / `opaLatencyMs` | `number` | Server-reported latency |
| `bundleVersion` | `string` | Rule bundle the decision was evaluated against |
| `evaluatedRules` | `string[]` | Rule IDs considered |
| `bundleDigest` | `string` | Content digest of the rule set that decided |
| `sandbox` | `boolean` | `true` only for a `{ sandbox: true }` check |
| `jurisdiction` / `timestamp` / `processingTimeMs` | | As evaluated and reported by the server |

Per-call context overrides the client defaults:

```typescript
await ce.check(userPrompt, {
  direction: "prompt",     // "prompt", "output" (default) or "action" the AI is about to take
  jurisdiction: "EU",
  agentId: "hr-screening",
  userId: "ref_5d81e2c4",     // who the agent acts for
  userRole: "recruiter",   // their role
  sessionId: "conv_abc",   // the conversation, run or job
});
```

`decisionContext` carries the ADCR 0.1.0 facts only you know (see the quick
start). It is optional: without it the check runs and is recorded, but the
record does not meet ADCR class Record. When you send it, `deciding_system`,
`purpose_ref` and `data_categories` are required; with `subject` the API also
requires `decision_mode`, `notice` and `explanation_inputs`. The
`DecisionContext` type says the same.

`userId`, `userRole` and `sessionId` are written on the audit record as
`user_id`, `user_role` and `session_id`. Leave them out and those columns stay
blank in your audit export. Send a stable identifier from your own system, never
a name or an email address: `user_id` and `session_id` are stored as keyed
pseudonyms (`p1:...`) under your account's own key, not as sent. `userRole` is
stored as sent, so it must name a role, not a person.

Never send a credential in these fields: a login token, session cookie, JWT or
API key would sit in every audit record and export. If your session id doubles
as a login token, send a hash of it (for example the first 16 hex characters of
its SHA-256). ComplyEdge replaces any token- or key-shaped value with
`redacted:` plus a hash before the record is written.

To prove a record was about a given text (the stored hash is keyed, so it
cannot be recomputed locally):

```typescript
const ok = await ce.verifyInput(result.eventId, userPrompt); // true only for this exact text

// Optional: append eventId + textHash (+ digests) locally after each check.
// Never stores the prompt. Your app log still holds the text.
// new ComplyEdgeClient({ apiKey, receiptJournalPath: "/var/lib/app/ce-receipts.jsonl" })
```

The full walkthrough, including what happens if you delete your copy early:
https://complyedge.io/docs/audit-reconciliation.html

For an agent that always acts for the same person,
set them once on the client:

```typescript
const ce = new ComplyEdgeClient({
  apiKey: process.env.COMPLYEDGE_API_KEY!,
  agentId: "hr-screening",
  userId: "ref_5d81e2c4",
  userRole: "recruiter",
  sessionId: runId,
});
```

## OpenAI middleware

Wrap an OpenAI client so user messages are checked before they reach the model:

```typescript
import OpenAI from "openai";
import { ComplyEdgeClient, withCompliance, ComplianceError } from "@complyedge/sdk";

const openai = withCompliance(
  new OpenAI(),
  new ComplyEdgeClient({ apiKey: process.env.COMPLYEDGE_API_KEY! }),
  {
    jurisdiction: "EU",
    blockOnViolation: true,
    decisionContext: {
      deciding_system: { version: "1.4.0" },
      purpose_ref: "customer-support",
      data_categories: ["contact"],
    },
  }
);

try {
  await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [{ role: "user", content: prompt }],
  });
} catch (err) {
  if (err instanceof ComplianceError) {
    // Blocked before the request left your system.
  }
}
```

When the OpenAI request sets `user`, the middleware records it as `userId`.
Role and session come from the client defaults. Pass `decisionContext` in the
options to send it with every check the middleware makes.

`openai` is an optional peer dependency. Install it only if you use the middleware.

## Pre-deployment assessment

```typescript
const assessment = await ce.assessPreDeployment({
  systemPrompt: "You screen CVs and rank candidates.",
  jurisdiction: "EU",
});

console.log(assessment.riskTier);        // "high"
console.log(assessment.euAiActCategory); // "employment-workers"
```

## `detectSensitivity(text, context?)`

Legacy sensitivity detection (`POST /v1/sensitivity/detect`), kept for existing
callers. It runs the TrustLint and LLM pipeline, not OPA, and writes an audit
record with the same `userId`, `userRole` and `sessionId` attribution. Use
`check()` for runtime enforcement.

## Errors

Network and HTTP failures surface as `AxiosError`. The middleware throws
`ComplianceError` when a check blocks a request.

## Limitations and honest scope

- This SDK calls the hosted ComplyEdge API; it is not an offline rules engine.
  Use `trustlint` or `@complyedge/mcp` when a local-only check is required.
- A rule finding is a record of which rule fired, not legal advice or a legal
  determination of an AI system's full regulatory classification.
- The OpenAI middleware checks the request path shown above. It is not a
  general-purpose security sandbox and does not automatically govern other
  model providers or application code.

## Links

- Quick start: https://complyedge.io/docs/quick-start.html
- API reference: https://complyedge.io/docs/api-reference.html
- Browser playground: https://complyedge.io/docs/playground.html
- Enforcement Seal embed: https://complyedge.io/docs/trust-badge.html
- Python SDK: `pip install complyedge`

## License

Apache-2.0. See [LICENSE](./LICENSE).
