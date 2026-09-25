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
  and verdict as `/v1/check`, with nothing recorded — no audit entry, no usage,
  no rate-limit count. For trying cases before wiring an integration; never
  evidence. `ComplianceResult.sandbox` is `True` only when the server says so,
  beside `audit_logged=False`. Default is unchanged (`/v1/check`).
- MCP (`complyedge[mcp]`, `complyedge-mcp` stdio): optional fourth tool
  `sandbox_check`, listed only when `COMPLYEDGE_API_KEY` is set. Calls the
  hosted sandbox through the SDK client (region from the key prefix), returns
  `BLOCKED` / `ALLOWED` with rule ID and citation, `audit_logged: false`,
  `sandbox: true`; refuses to report a response the server did not mark as
  sandbox. Without the key the server is exactly the three offline tools.
- Hosted MCP (`mcp.complyedge.io/mcp`): `sandbox_check` is always listed and
  works only for a caller that sends its own key as `Authorization: Bearer`
  on the MCP connection. The key is read per request from the HTTP request,
  never a tool argument, never logged; the hosted server keeps no keys.
  `/health` reports it under `optional_tools`.

## [0.2.17] - 2026-09-17

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
