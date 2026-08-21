# Changelog

All notable changes to `@complyedge/mcp` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This record begins at 0.1.3.** Releases 0.1.0 through 0.1.2 shipped before the
changelog existed; they are listed from their commits rather than reconstructed
from memory, and anything not evidenced is left out instead of guessed at.

## [0.1.5] - 2026-08-21

### Changed
- Keywords: 9 -> 22. The other two npm packages were given a buyer-search
  keyword set; this one was published afterwards and never received the same
  treatment. Added the regulation nouns the bundled corpus actually covers
  (`gdpr`, `hipaa`, `sox`, `pci-dss`, `coppa`), the two EU AI Act articles it
  cites in findings (`article-5`, `article-50`), and the terms describing how
  it runs (`mcp-server`, `offline`, `prompt-scanning`, `prompt-injection` -- the corpus
  carries nine `PROMPT_SECURITY` rules for injection and exfiltration).
- Description rewritten to name the corpus size, the specific regulations, and
  the three things this package deliberately does not need: Python, an API key,
  a network call.

### Removed
- `audit-trail` keyword. This server has no audit capability -- it holds no
  state and writes nothing. The Article 12 audit trail belongs to
  [`@complyedge/sdk`](https://www.npmjs.com/package/@complyedge/sdk), which
  calls the hosted API, and this package's own README already said so. A
  keyword that advertises a capability the package does not have is the same
  defect as `opa`/`rego` on `trustlint`, removed in that package for the same
  reason.

## [0.1.4] - 2026-08-20

### Added
- `CHANGELOG.md` and `LICENSE` are now on the `files` whitelist, so both ship
  in the published tarball. 0.1.3 declared a changelog on disk but the
  published package still omitted it.

### Changed
- Runtime dependency floor: `trustlint` `^2.0.4` → `^2.0.5` (publish order:
  trustlint first, then this package).

## [0.1.3] - 2026-08-20

### Fixed
- The server reported the wrong version to MCP hosts. `serverInfo.version` was a
  hardcoded string in `server.ts`, so the published 0.1.2 introduced itself as
  0.1.1 — and the registry entry advertised a third number. It now derives from
  `package.json`.

  This was the third occurrence of one defect in this codebase: the TrustLint
  CLI held a hardcoded version against its own `package.json`, and the Python
  packaging carries a note recording the same bug there first. A regression test
  now asserts that `serverInfo.version` equals `package.json`, so the property
  is checked rather than the literal.

## [0.1.2] - 2026-08-19

### Added
- `LICENSE` (Apache-2.0) now ships in the tarball. The package declared
  Apache-2.0 and conveyed no license text.
- Tool reference table, a "Limitations and honest scope" section, and
  cross-links to the sibling npm and PyPI packages.
- Badges for version, weekly downloads and license.

### Changed
- Release workflow now verifies every runtime dependency already resolves on the
  registry *before* publishing. `trustlint` resolves locally through the
  workspace, so a dependency range that did not exist on npm would previously
  have been discovered only after the version was burned.

## [0.1.1] - 2026-08-16

### Changed
- Documentation and packaging corrections following the first release.

## [0.1.0] - 2026-08-16

### Added
- First release. Node-native MCP server exposing `check_compliance`,
  `scan_prompt` and `list_rules` against the bundled offline TrustLint corpus.
  Runs via `npx` with no Python runtime and no API key.

[0.1.5]: https://www.npmjs.com/package/@complyedge/mcp/v/0.1.5
[0.1.4]: https://www.npmjs.com/package/@complyedge/mcp/v/0.1.4
[0.1.3]: https://www.npmjs.com/package/@complyedge/mcp/v/0.1.3
[0.1.2]: https://www.npmjs.com/package/@complyedge/mcp/v/0.1.2
[0.1.1]: https://www.npmjs.com/package/@complyedge/mcp/v/0.1.1
[0.1.0]: https://www.npmjs.com/package/@complyedge/mcp/v/0.1.0
