# Changelog

All notable changes to `@complyedge/sdk` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This record begins at 0.2.2.** Earlier releases shipped before the changelog
existed; 0.2.1 is reconstructed from its commits, and anything not evidenced
there is left out rather than guessed at.

The Python SDK (`complyedge` on PyPI) is versioned independently. Version
numbers are deliberately not kept level between the two: they are separate
implementations with different capability surfaces, so matching numbers would
imply a parity that does not exist.

## [Unreleased]

### Added
- `ReceiptJournal` / `receiptJournalPath` on `ComplyEdgeConfig`: optional append-only JSONL of check linkage (`eventId`, `textHash`, digests, timestamps). Never stores the prompt or answer. Sandbox checks are skipped. Pairing text still uses `verifyInput` against the caller's own copy.
- `bundleDigest` on check results: the SHA-256 digest of the rule set that decided, the same value as the audit entry and the ADCR record's `rule_set.digest`. `undefined` when the API does not return it.
- `client.verifyInput(eventId, text)`: resolves `true` when the audit record `eventId` was a decision about exactly `text`. It calls `POST /v1/audit/verify`; the comparison runs server-side because the record's hash is keyed with the account's own key, which never leaves ComplyEdge. The text is used for that request only and is not stored or logged. Resolves `false` when the text differs or the account's key was destroyed; an unknown `eventId` rejects (404). Needs an API version that serves `/v1/audit/verify`.
- `textHashAlg` on check results: `"hmac-sha256-1"` when `textHash` is the keyed commitment (HMAC-SHA-256 under the account's key over `commitment:` and the text), `undefined` on responses from an API that still returns a plain SHA-256.
- `decisionContext` on `ComplianceContext`: the audit record fields only the caller knows (deciding system version, purpose, data categories, legal basis, references), sent to `check()` as `decision_context` and written to the record as ADCR 0.1.0 fields. Omitted when not given; a check without it is decided and recorded, but its record does not meet ADCR class Record.
- `decisionContext` option on `withCompliance()`, sent with every check the middleware makes.
- `DecisionContext` type: `decision_mode`, `notice`, `explanation_inputs`, `withheld` and `escrow_ref`, which the API requires when `subject` is set (`escrow_ref` when `withheld` is true).
- `direction: "action"`: an action the AI system is about to take.

### Changed
- README: the record comes first. Store the `eventId` from every check next to your own copy of the text and prove the pair later with `verifyInput`; ComplyEdge never stores the prompt or the answer.
- Package keywords: dropped `guardrails` and `llm-security`, added `audit-record` and `verifiable-ai-decisions`.
- Package description rewritten around the decision record (was "EU AI Act runtime enforcement SDK: OPA/Rego policy checks, Article 12 audit trails, risk assessment, and OpenAI middleware.").
- `DecisionContext`: `deciding_system`, `purpose_ref` and `data_categories` are required in the type, as the API requires them whenever the object is sent.

### Fixed
- `withCompliance()` accepts a class instance such as `new OpenAI()`. Its type bound was `Record<string, unknown>`, which a class instance does not satisfy, so the README example did not compile.
- README: `enginePath` values are `opa`, `llm`, `hybrid`, `fallback_block` and `trustlint`; `ruleDescription` is the rule's legal citation; the `wrong_region` body is `{"detail":{"error":"wrong_region","use":...}}`.

### Docs
- `sandbox` option: sandbox calls do not count against the plan's daily limit
  but have their own caps (60 a minute, 1,000 a day); the README and the type
  comment used to say "no rate-limit count". No code change.

## [0.2.6] - 2026-09-30

### Added
- `userId` and `sessionId` on `ComplianceContext`, and `userId` / `userRole` / `sessionId` client defaults on `ComplyEdgeConfig`. `check()` and `detectSensitivity()` send all three in `context`, recorded on the audit entry. The OpenAI middleware records the request's `user` as `userId`.

### Fixed
- `detectSensitivity()` sent `user_role` at the top level of the request, where the API ignores it, so it never reached the audit record. It is now sent in `context`.
- `check()` sent only `user_role`; `user_id` and `session_id` could not be sent at all.

## [0.2.5] - 2026-09-25

### Changed
- No `baseUrl`, `COMPLYEDGE_API_URL`, or `region`, and no `ce_` / `ce_eu_`
  prefix, now resolves to `https://eu.api.complyedge.io`. Legacy `ce_` keys
  still use the US host. The 0.2.4 fallback was the US host.

### Docs
- Key rotation now lives on the dashboard's API Key page (Rotate asks before
  minting; every active key is listed there). The public trust surface shows
  one company name, set under Account, Profile; `display_name` on
  `PATCH /v1/tenant/trust` sets the same value. No code change.
- Key rotation guidance in the README: rotate in the dashboard (mint, swap,
  revoke previous) or with `POST` then `DELETE /v1/account/api-keys`; both
  keys work until the old one is revoked. No code change.

### Added
- `sandbox: true` on `ComplianceContext` routes `check()` to
  `POST /v1/sandbox/check`: the same rules, tenant settings and verdict as
  `/v1/check`, with nothing recorded: no audit entry, no usage, no rate-limit
  count. For trying cases before wiring an integration; never evidence.
  `ComplianceResult.sandbox` is `true` only when the server says so, beside
  `auditLogged: false`. Default is unchanged (`/v1/check`).

## [0.2.4] - 2026-09-16

### Added
- `region: "us" | "eu"` config option and `COMPLYEDGE_REGION` environment
  variable. The client now picks the API host from the key prefix
  (`ce_eu_` -> `https://eu.api.complyedge.io`, `ce_` -> `https://api.complyedge.io`)
  when neither `baseUrl` nor `COMPLYEDGE_API_URL` is set. Exported helpers:
  `resolveBaseUrl`, `regionFromApiKey`, `REGION_BASE_URLS`, type `Region`.
  Precedence: `baseUrl` > `COMPLYEDGE_API_URL` > `region` / `COMPLYEDGE_REGION`
  > key prefix > US. Existing configurations resolve exactly as before.

## [0.2.3] - 2026-08-20

### Added
- Package-map capability table across the ComplyEdge packages: offline vs
  hosted, Rego/OPA, Article 12, bundled corpus, ESM/CJS, MCP.

### Fixed
- Release-path fact: publishes still authenticate with a long-lived npm
  credential. The 0.2.2 changelog entry that claimed OIDC Trusted Publishing
  described an attempt that was reverted: `repository.url` names the public
  repository while the release workflow runs in the private platform one, and
  npm matches those two when authenticating. Provenance stays unavailable
  until that layout changes.

## [0.2.2] - 2026-08-20

### Changed
- Releases now publish through npm Trusted Publishing (OIDC). Each publish uses
  a short-lived, workflow-scoped credential instead of a long-lived token, and
  the token has been removed from the release workflow rather than left in place
  as a fallback.

### Added
- This changelog.

### Note
- Provenance attestations are still not generated. npm produces them only when
  publishing from a public repository, and the release workflow lives in a
  private one. No package page claims provenance.

## [0.2.1] - 2026-08-16

### Added
- `repository` field, which the package had never carried.
- `Limitations and honest scope` section in the README: the SDK calls the
  hosted API and is not an offline engine, a rule finding is technical evidence
  rather than legal advice, and the OpenAI middleware is not a security sandbox.
- Explicit note that the package works in both ESM and CommonJS projects.
- Cross-links to `@complyedge/mcp`, `trustlint`, and the PyPI packages.

### Changed
- Description rewritten to name what the SDK actually does: OPA/Rego policy
  checks, Article 12 audit trails, risk assessment, OpenAI middleware.
- Keywords: 5 → 16, replacing generic terms with the ones a compliance buyer
  searches. `opa` and `rego` are kept here because this package does call the
  OPA hot path; they were removed from `trustlint`, which does not.

## 0.2.0 and earlier

Released before this changelog existed. See the repository history.

[Unreleased]: https://github.com/ComplyEdge/complyedge/commits/main/sdks/typescript
[0.2.6]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.6
[0.2.5]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.5
[0.2.4]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.4
[0.2.3]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.3
[0.2.2]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.2
[0.2.1]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.1
