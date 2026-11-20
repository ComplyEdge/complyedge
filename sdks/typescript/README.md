# @complyedge/sdk

TypeScript/JavaScript SDK for [ComplyEdge](https://complyedge.io). The evidence AI laws ask for, collected on every AI call. Each call is checked against the law and logged, ready for your auditor. We never store the conversation. Rules today: the EU AI Act, US companion chatbot laws and prompt injection.

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
| Bundled YAML rules | No | Yes | Yes |
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
  direction: "prompt",     // "prompt", "output" or "action" the AI is about to take; left out, the API reads "output"
  jurisdiction: "EU",
  agentId: "hr-screening",
  userId: "ref_5d81e2c4",     // who the agent acts for
  userRole: "recruiter",   // their role
  sessionId: "conv_abc",   // the conversation, run or job
});
```

`decisionContext` carries the ADCR facts only you know (see the quick
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

### Companion chatbots (California, New York, Washington, Oregon)

Send `useCase: "companion_chatbot"` and ComplyEdge checks each message against
the companion chatbot laws for the user's state (`jurisdiction` `US-CA`,
`US-NY`, `US-WA` or `US-OR`) and tells your app what it must do for it. Such a
check needs `direction` (`"prompt"` for the user's message, `"output"` for the
bot's reply) and a `sessionId`. Without either the SDK refuses the check
before sending anything.

`direction` is sent only when you give it. On any other check the API then
treats the text as `"output"`.

Companion facts go in `companion`, in the API's snake_case, and are sent in
the request's `context`. You can leave any key out; one you leave out means
unknown, never "adult":

| Key | Values |
|---|---|
| `age_status` | `known_minor`, `child`, `reason_to_believe_minor`, `adult`, `treated_as_child`, `unknown` |
| `age_source` | `os_signal`, `sb976_fallback`, `self_declared`, `operator_known`, `age_assurance`, `none` |
| `directed_to_minors`, `uses_prior_personal_memory`, `under_25`, `parent_linked`, `parent_changed_time_limit`, `fda_regulated_device`, `is_session_start` | `true` or `false` |
| `parent_changed_memory_default`, `parent_changed_push_default`, `child_16_plus`, `memory_risk_guardrails`, `parent_disabled_access` (California child defaults) | `true` or `false` |
| `ad_targeting` | `none`, `contextual`, `chat_personal_info`, `cross_context` |
| `ny_art47_excluded`, `ny_art48_off_purpose_refused`, `wa_excluded`, `or_excluded` (your system is outside that state's law; left out means covered) | `true` or `false` |
| `ny_art48_exempt_purpose` | `customer_service`, `efficiency_research_technical`, `internal` |
| `session_started_at` | ISO 8601 time the session started |
| `minutes_today`, `referrals_this_session` | whole numbers |

The result carries four more fields:

| Field | Meaning |
|---|---|
| `companionAssessment` | `"assessed"`, `"not_assessed"` or `"operator_asserted"` (you sent `operator_labels` in `context`, so the meaning check did not run); `null` on any other check. Not assessed is never a clean pass |
| `companionNotAssessedReason` | `plan`, `budget`, `unavailable`, `no_direction` or `no_session`; else `null` |
| `companionFallback` | `true` when ComplyEdge could not work out the actions: apply your own protocol to this message |
| `companionWarnings` | Codes for what your requests show is wrong with the integration: `age_status_missing`, `session_start_changed`. Empty when nothing is. A warning never changes the actions |
| `requiredActions` | `{ action, ruleIds, jurisdiction, reasonCode, dueAt, intervalKey, counted }[]` |

After your app shows a notice, record it with `confirmAction`. Pass the
`requiredActions` entry and the check result; the call fills the action, the
check's id and timestamp, the interval key, the state and the rule id from
them. The check is recorded a moment after it returns, so while it is not
there yet the call retries with growing waits, for up to 10 minutes after the
check's timestamp. `block_reply`, `disable_prior_personal_memory` and `disable_push_notifications` are applied
in your response and never confirmed. `preserve_conversation` is recorded with `preserve`, whose answer lists `accountDuties`.
On a reply check, pass the user's last message as `companionUserMessage` so the
rules about leaving and requested products can be judged; it is never stored.

When a law asks you to keep a conversation, `preserve` sends it once.
ComplyEdge keeps a keyed hash of it, never the text. The SDK first puts it in
one canonical form (a JSON array of `role`, `text`, `sent_at`, text in Unicode
NFC, written by RFC 8785), so the copy you keep verifies later whatever its
whitespace or key order. `canonicalConversation(conversation)` returns that
string.

```typescript
const ce = new ComplyEdgeClient({ apiKey, agentId: "pal", sessionId });

const result = await ce.check(userMessage, {
  jurisdiction: "US-CA",
  direction: "prompt",
  useCase: "companion_chatbot",
  companion: { age_status: "known_minor", age_source: "os_signal", minutes_today: 42 },
});
for (const needed of result.requiredActions) {
  if (needed.action === "show_crisis_referral") {
    showCrisisReferral(); // your app shows it
    await ce.confirmAction({
      requiredAction: needed,
      check: result,
      confirmationId: `${result.eventId}:${needed.intervalKey}`,
      source: "complyedge",
      shownAt: new Date(),
      format: "app",
      decidingSystemVersion: "pal-3",
      language: "en",
    });
  }
}

await ce.preserve({
  conversation: [{ role: "user", text: userMessage, sent_at: sentAt }],
  trigger: "parent_notified",
  preservedAt: new Date(),
  decidingSystemVersion: "pal-3",
});
```

A refused check still says what the law asks. When the daily limit is reached
(429) or the service cannot answer (503), `check` throws, and `checkRefusal`
reads the same fields from the error. Show those notices too:

```typescript
import { checkRefusal } from "@complyedge/sdk";

let actions;
try {
  actions = (await ce.check(userMessage, companionContext)).requiredActions;
} catch (err) {
  const refusal = checkRefusal(err);
  if (!refusal) throw err;
  actions = refusal.requiredActions; // empty when the error names none
}
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

## Appeals: a person asks about a decision

When a person asks for a human review, an explanation or a correction of a
decision your AI made (GDPR Art. 22, EU AI Act Art. 86), record the request
and, later, your answer. Enterprise plan.

```typescript
// The person asks. The agent and system version are read from the decision.
const requestId = await ce.recordAppeal({
  decisionId: decision.eventId,
  kind: "human_intervention",
  requestedAt: ticket.createdAt,
});

// Your team answers. statementRef points at the reply in your own system.
await ce.recordAnswer(requestId, {
  outcome: "upheld",
  statementRef: `ticket:${ticket.id}`,
  reviewer: `staff:${agent.id}`,
});

// Appeals with no answer yet, late ones first, each with its due date.
for (const appeal of await ce.listAppeals()) {
  if (appeal.late) console.log(appeal.requestId, "was due", appeal.dueAt);
}
```

Retrying `recordAppeal` with the same `requestedAt` returns the same id.
Each appeal also lists every answer and extension, oldest first (`answers`,
`extensions`). `answer` is the one recorded last; `answeredLate` is judged on the first.
Full guide: https://complyedge.io/docs/appeals.html

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
`check()` for the hosted check against AI laws.

## Errors

Network and HTTP failures surface as `AxiosError`. The middleware throws
`ComplianceError` when a check blocks a request. An error thrown by `check`
for an HTTP answer also has `refusal`: the status, the parsed body, and the
companion fields when the body holds them (`checkRefusal(err)` returns the
same).

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
