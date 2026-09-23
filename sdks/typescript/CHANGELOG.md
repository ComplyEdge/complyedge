# Changelog

All notable changes to `@complyedge/sdk` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This record begins at 0.2.2.** Earlier releases shipped before the changelog
existed; 0.2.1 is reconstructed from its commits, and anything not evidenced
there is left out rather than guessed at.

The Python SDK (`complyedge` on PyPI) is versioned independently. Version
numbers are deliberately not kept level between the two — they are separate
implementations with different capability surfaces, so matching numbers would
imply a parity that does not exist.

## [Unreleased]

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
  `/v1/check`, with nothing recorded — no audit entry, no usage, no rate-limit
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
- Package-map capability table (CE-vs-CE only): offline vs hosted, Rego/OPA,
  Article 12, bundled corpus, ESM/CJS, MCP. Named competitor comparisons stay
  gated — they need an explicit messaging decision against the no-first/only
  doctrine.

### Fixed
- Release-path fact: publishes still authenticate with a long-lived npm
  credential. The 0.2.2 changelog entry that claimed OIDC Trusted Publishing
  described an attempt that was reverted — `repository.url` names the public
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
- `Limitations and honest scope` section in the README — the SDK calls the
  hosted API and is not an offline engine, a rule finding is technical evidence
  rather than legal advice, and the OpenAI middleware is not a security sandbox.
- Explicit note that the package works in both ESM and CommonJS projects.
- Cross-links to `@complyedge/mcp`, `trustlint`, and the PyPI packages.

### Changed
- Description rewritten to name what the SDK actually does: OPA/Rego policy
  checks, Article 12 audit trails, risk assessment, OpenAI middleware.
- Keywords: 5 → 16, replacing generic terms with the ones a compliance buyer
  searches. `opa` and `rego` are kept here because this package does call the
  OPA hot path — they were removed from `trustlint`, which does not.

## 0.2.0 and earlier

Released before this changelog existed. See the repository history.

[0.2.4]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.4
[0.2.3]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.3
[0.2.2]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.2
[0.2.1]: https://www.npmjs.com/package/@complyedge/sdk/v/0.2.1
