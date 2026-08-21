# @complyedge/sdk

TypeScript/JavaScript SDK for [ComplyEdge](https://www.complyedge.io): runtime EU AI Act enforcement for AI agents.

Every `check()` call is evaluated against a deterministic Rego rule bundle, returns article-cited violations, and is written to an Article 12 audit trail.

![npm version](https://img.shields.io/npm/v/%40complyedge%2Fsdk)
![npm downloads](https://img.shields.io/npm/dw/%40complyedge%2Fsdk)
![license](https://img.shields.io/npm/l/%40complyedge%2Fsdk)

## Install

```bash
npm install @complyedge/sdk
```

Requires Node.js 18 or later. Get an API key at [dashboard.complyedge.io](https://dashboard.complyedge.io/?intent=get-started).

The SDK works in both ESM and CommonJS projects; no bundler-specific setup is required.

## Package map

- [`@complyedge/mcp`](https://www.npmjs.com/package/@complyedge/mcp) runs the local, offline TrustLint MCP tools with `npx`.
- [`trustlint`](https://www.npmjs.com/package/trustlint) is the local Node.js CLI for offline rule checks.
- [`complyedge` on PyPI](https://pypi.org/project/complyedge/) is the Python SDK with the same enforcement API.
- [Documentation](https://www.complyedge.io/docs) covers the hosted API; the [trust portal](https://trust.complyedge.io) covers security and reliability information.

| | `@complyedge/sdk` | `trustlint` | `@complyedge/mcp` |
|---|:-:|:-:|:-:|
| Runs offline, no API key | ✗ | ✓ | ✓ |
| Rego / OPA evaluation | ✓ | ✗ | ✗ |
| Article 12 audit trail | ✓ | ✗ | ✗ |
| Bundled 64-rule corpus | ✗ | ✓ | ✓ |
| Temporal / effective-date rules | ✗ | ✗ | ✗ |
| ESM + CommonJS | ✓ | ✓ | ESM only |
| MCP host integration | ✗ | ✗ | ✓ |

Temporal / effective-date evaluation lives in the Python engine only. A shared version number across npm and PyPI is not a parity claim.

## Version policy

The TypeScript SDK and Python `complyedge` package have independent semantic versions. A version number does not imply feature parity across languages; each release documents and tests its own supported API surface.

## Quick start

```typescript
import { ComplyEdgeClient } from "@complyedge/sdk";

const ce = new ComplyEdgeClient({ apiKey: process.env.COMPLYEDGE_API_KEY! });

const result = await ce.check("Score users based on their social behavior");

if (!result.allowed) {
  console.log("Blocked:", result.violations[0].ruleId);
  console.log("Why:", result.violations[0].ruleDescription);
  console.log("Audit event:", result.eventId);
}
```

Blocked output:

```
Blocked: rego-art5-1c-001
Why: Social scoring prohibited under Article 5(1)(c)
Audit event: evt_01J...
```

## Configuration

```typescript
const ce = new ComplyEdgeClient({
  apiKey: process.env.COMPLYEDGE_API_KEY!,
  jurisdiction: "EU",   // default: "EU"
  agentId: "support-bot", // default: "default"
  timeout: 30_000,      // ms, default: 30_000
  baseUrl: "https://api.complyedge.io", // or COMPLYEDGE_API_URL
});
```

## `check(text, context?)`

Calls `POST /v1/check`, the deterministic OPA hot path. Returns:

| Field | Type | Meaning |
|-------|------|---------|
| `allowed` | `boolean` | `false` means block before the model sees it |
| `status` | `"safe" \| "violation"` | Convenience mirror of `allowed` |
| `violations` | `ComplianceViolation[]` | Rule ID, description, severity, reason, confidence |
| `eventId` | `string` | Identifier of the audit record for this decision |
| `auditLogged` | `boolean` | Whether the decision reached the Article 12 trail |
| `enginePath` | `string` | `opa`, `opa_fallback_llm`, or `opa_error` |
| `latencyMs` / `opaLatencyMs` | `number` | Server-reported latency |
| `bundleVersion` | `string` | Rule bundle the decision was evaluated against |
| `evaluatedRules` | `string[]` | Rule IDs considered |

Per-call context overrides the client defaults:

```typescript
await ce.check(userPrompt, {
  direction: "prompt",     // "prompt" (user input) or "output" (model output)
  jurisdiction: "EU",
  agentId: "hr-screening",
  userRole: "recruiter",   // recorded for audit attribution
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
  { jurisdiction: "EU", blockOnViolation: true }
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
callers. It runs the TrustLint and LLM pipeline, not OPA, and does **not** write
the Article 12 audit trail. Use `check()` for runtime enforcement.

## Errors

Network and HTTP failures surface as `AxiosError`. The middleware throws
`ComplianceError` when a check blocks a request.

## Limitations and honest scope

- This SDK calls the hosted ComplyEdge API; it is not an offline rules engine.
  Use `trustlint` or `@complyedge/mcp` when a local-only check is required.
- A rule finding is technical compliance evidence, not legal advice or a legal
  determination of an AI system's full regulatory classification.
- The OpenAI middleware checks the request path shown above. It is not a
  general-purpose security sandbox and does not automatically govern other
  model providers or application code.

## Links

- Quick start: https://www.complyedge.io/docs/quick-start.html
- API reference: https://www.complyedge.io/docs/api-reference.html
- Browser playground: https://www.complyedge.io/docs/playground.html
- Trust badge setup: https://www.complyedge.io/docs/trust-badge.html
- Python SDK: `pip install complyedge`

## License

Apache-2.0. See [LICENSE](./LICENSE).
