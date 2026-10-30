# Changelog

All notable changes to `complyedge` (PyPI) are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This record begins at 0.2.17.** Earlier releases shipped before the changelog
existed; 0.2.16 and 0.2.17 are reconstructed from their commits, and anything
not evidenced there is left out rather than guessed at.

The TypeScript SDK (`@complyedge/sdk` on npm) is versioned independently.
Matching numbers would imply a parity that does not exist.

## [Unreleased]

## [0.2.24] - 2026-10-30

### Fixed
- The CLI now writes the saved API key owner-only from the first byte. It used to create the file with the process umask and only then restrict it, so the key sat readable by other users for a moment. The config directory is now owner-only too.

### Changed
- The `use_semantic_fallback` docstring and the `sandbox_check` tool description now say what the check does: phrase rules run on every check, a paid plan then runs an injection check when the month's model budget covers it, and the wider review runs only when you turn it on.

## [0.2.23] - 2026-10-26

### Removed
- `smithery.ai` and `www.smithery.ai` from the hosted MCP HTTP server's default allowed origins. Set `MCP_ALLOWED_ORIGINS` (comma-separated) to choose the origins yourself.

## [0.2.22] - 2026-10-23

### Added
- `ReceiptJournal` / `receipt_journal=` on `ComplyEdge`: optional append-only JSONL of check linkage (`event_id`, `text_hash`, digests, timestamps). Never stores the prompt or answer. Sandbox checks are skipped. Pairing text still uses `verify_input` against the caller's own copy.
- `bundle_digest` on check results: the SHA-256 digest of the rule set that decided, the same value as the audit entry and the ADCR record's `rule_set.digest`. `None` when the API does not return it.
- `ComplyEdge.verify_input(event_id, text)`: returns `True` when the audit record `event_id` was a decision about exactly `text`. It calls `POST /v1/audit/verify`; the comparison runs server-side because the record's hash is keyed with the account's own key, which never leaves ComplyEdge. The text is used for that request only and is not stored or logged. Returns `False` when the text differs or when the account's key was destroyed; an unknown `event_id` raises `ComplianceError`. Needs an API version that serves `/v1/audit/verify`.
- `text_hash_alg` on check results: `"hmac-sha256-1"` when `text_hash` is the keyed commitment (HMAC-SHA-256 under the account's key over `commitment:` and the text), `None` on responses from an API that still returns a plain SHA-256.
- `decision_context` on `ComplyEdge.check()` and on both clients' `check_compliance()`: the audit record fields only the caller knows (deciding system version, purpose, data categories, legal basis, references), written to the record as ADCR 0.1.0 fields. Also on the `@compliance_check` decorator and `ComplianceConfig` (a dict, or a zero-argument callable read on every call), `ComplyEdge.is_safe()` and the global `check()` and `is_safe()`. Optional: a check without it is decided and recorded, but its record does not meet ADCR class Record. When sent, `deciding_system`, `purpose_ref` and `data_categories` are required.
- `DirectionType.ACTION` (`"action"`): an action the AI system is about to take.

### Changed
- README: the record comes first. Store the `event_id` from every check next to your own copy of the text and prove the pair later with `verify_input`; ComplyEdge never stores the prompt or the answer. `user_id` and `session_id` are stored as keyed pseudonyms (`p1:...`) by the API.
- Package metadata: dropped the `Topic :: Security` classifier. This package records compliance evidence; it is not a security control.

### Fixed
- README: the violation example printed `v.citation`, which does not exist (`rule_description` holds the citation); `fail_mode="closed"` was shown as a decorator argument, which the decorator rejects (use `COMPLYEDGE_FAIL_MODE=closed` or `ComplianceConfig(fail_mode="closed")`); the `wrong_region` body is `{"detail": {"error": "wrong_region", "use": ...}}`.
- The MCP server (`complyedge-mcp` and the hosted MCP) now loads the rule corpus
  the installed `trustlint` bundles unless `TRUSTLINT_RULES_DIR` is set. With no
  directory, trustlint loaded `~/.trustlint/rules` or a `rules/regulations` folder
  above the working directory first, so an old cache meant an old corpus.
- Sandbox docs and docstrings: sandbox calls do not count against the plan's
  daily limit but have their own caps (60 a minute, 1,000 a day); they used to
  say "no rate-limit count".

## [0.2.21] - 2026-10-01

### Fixed
- `bundle_version` on a check result is `"unknown"` when the API response omits it. It used to fall back to `"opa-rego-v1"`, a value the API no longer reports; the API now derives `bundle_version` from the rule-corpus digest.

## [0.2.20] - 2026-09-30

### Added
- `user_id`, `user_role` and `session_id` on `ComplyEdge` (client defaults and per `check()` call), on the module-level `check()` / `is_safe()`, on `ComplyEdgeClient.check_compliance()` and the async client; `attribution=` on `@compliance_check` / `ComplianceConfig` (a dict, or a function read on every call) and on `create_compliance_guardrail()` (a dict, or a function given the run context). They are recorded on the audit entry; before, the simple client and the decorator could not send them, so those export columns were always blank.

### Fixed
- A 429 is retried only when the server's wait fits the retry budget. The daily check cap (`rate_limit_exceeded`, resets 00:00 UTC) and the 60-second sandbox limit now raise `ComplianceError` on the first attempt instead of retrying three times over about 14 seconds. Short 429s and 5xx errors still retry.

### Changed
- Docs only. The region (EU or US) is chosen when you sign up and create your first API key; to change it later, contact support. This corrects the 0.2.19 note that a US host is only for an account support has moved: US accounts can be created at sign-up.

## [0.2.19] - 2026-09-26

### Changed
- Docs only. The key still chooses the host, and it still does not move the account. With no key, the client still calls `https://eu.api.complyedge.io`. A US host is only for an account support has moved. No request behavior change from 0.2.18.

## [0.2.18] - 2026-09-25

### Changed
- A key with no region prefix, and a client with no `base_url` /
  `COMPLYEDGE_API_URL` / `region`, now calls `https://eu.api.complyedge.io`.
  Legacy `ce_` keys still use `https://api.complyedge.io`. The 0.2.16
  fallback was the US host.

### Docs
- Key rotation now lives on the dashboard's API Key page (Rotate asks before
  minting; every active key is listed there). The public trust surface shows
  one company name, set under Account, Profile; `display_name` on
  `PATCH /v1/tenant/trust` sets the same value. No code change.
- Key rotation guidance in the README: rotate in the dashboard (mint, swap,
  revoke previous) or with `POST` then `DELETE /v1/account/api-keys`; both
  keys work until the old one is revoked. No code change.

### Added
- `sandbox=True` on `ComplyEdge.check()`, `ComplyEdgeClient.check_compliance()`,
  `AsyncComplyEdgeClient.check_compliance()` and the module-level `check()`
  routes the call to `POST /v1/sandbox/check`: the same rules, tenant settings
  and verdict as `/v1/check`, with nothing recorded: no audit entry, no usage,
  no count against the plan's daily limit (sandbox calls have their own caps:
  60 a minute, 1,000 a day). For trying cases before wiring an integration; never
  evidence. `ComplianceResult.sandbox` is `True` only when the server says so,
  beside `audit_logged=False`. Default is unchanged (`/v1/check`).
- MCP (`complyedge[mcp]`, `complyedge-mcp` stdio): optional fourth tool
  `sandbox_check`, listed only when `COMPLYEDGE_API_KEY` is set. Calls the
  hosted sandbox through the SDK client (region from the key prefix), returns
  `BLOCKED` with rule ID and citation or `ALLOWED`, `audit_logged: false`,
  `sandbox: true`; refuses to report a response the server did not mark as
  sandbox. Without the key the server is exactly the three offline tools.
- Hosted MCP (`mcp.complyedge.io/mcp`): `sandbox_check` is always listed and
  works only for a caller that sends its own key as `Authorization: Bearer`
  on the MCP connection. The key is read per request from the HTTP request,
  never a tool argument, never logged; the hosted server keeps no keys.
  `/health` reports it under `optional_tools`.

## [0.2.17] - 2026-09-23

### Fixed
- `create_compliance_guardrail` (the `[agents]` extra) dropped `agent_id`
  (every check landed as agent `default`), discarded `jurisdiction`, and always
  called `check()` with the client's default direction, so input guardrails
  were filed in the Article 12 trail as model outputs. Same defect the
  decorator had fixed earlier. README shows input + output guardrails with
  `agent_id`.

## [0.2.16] - 2026-09-16

### Added
- `region="us" | "eu"` and the `COMPLYEDGE_REGION` environment variable. The
  client picks the API host from the key prefix (`ce_eu_` ->
  `https://eu.api.complyedge.io`, `ce_` -> `https://api.complyedge.io`) when
  neither `base_url` nor `COMPLYEDGE_API_URL` is set. Precedence: `base_url`
  > `COMPLYEDGE_API_URL` > `region` / `COMPLYEDGE_REGION` > key prefix > US.

[Unreleased]: https://github.com/ComplyEdge/complyedge/commits/main/sdks/python
[0.2.24]: https://pypi.org/project/complyedge/0.2.24/
[0.2.23]: https://pypi.org/project/complyedge/0.2.23/
[0.2.22]: https://pypi.org/project/complyedge/0.2.22/
[0.2.21]: https://pypi.org/project/complyedge/0.2.21/
[0.2.20]: https://pypi.org/project/complyedge/0.2.20/
[0.2.19]: https://pypi.org/project/complyedge/0.2.19/
[0.2.18]: https://pypi.org/project/complyedge/0.2.18/
[0.2.17]: https://pypi.org/project/complyedge/0.2.17/
[0.2.16]: https://pypi.org/project/complyedge/0.2.16/
