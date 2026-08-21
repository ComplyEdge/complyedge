# Changelog

All notable changes to the npm `trustlint` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This record begins at 2.0.4.** Releases 1.0.7 through 2.0.3 shipped before the
changelog existed and are listed without notes rather than reconstructed — a
history written after the fact from guesswork would look authoritative and be
wrong.

The Python distribution of TrustLint is versioned independently and is currently
ahead of this one. Version numbers are deliberately not kept level: the Node
engine evaluates Tier-1 regex patterns, the Python engine additionally evaluates
temporal/effective-date rule state, so matching numbers would imply a parity
that does not exist.

## [2.0.5] - 2026-08-20

### Added
- `CHANGELOG.md` and `LICENSE` are now on the `files` whitelist, so both ship
  in the published tarball. 2.0.4 declared a changelog on disk but the
  published package still omitted it (`files` was only `dist` + `README.md`).

## [2.0.4] - 2026-08-19

### Added
- `LICENSE` (Apache-2.0) now ships in the published tarball. The package
  declared `"license": "Apache-2.0"` while conveying no license text, which
  Apache-2.0 §4(a) requires to accompany every distribution.
- `bugs`, `homepage` and `engines` fields. `engines` is `>=18.0.0`, taken from
  the actual dependency floor (`commander@12` declares `>=18`).
- Badges for version, weekly downloads and license.

### Changed
- Description rewritten to name the regulations covered — Art. 5 prohibited
  practices, Art. 50 transparency, GDPR, HIPAA, SOX, PCI DSS, COPPA — rather
  than describing the tool in the abstract.
- Keywords: 9 → 18, aimed at the terms a compliance buyer actually searches.

### Removed
- `opa` and `rego` keywords. This package ships no `.rego` files and its engine
  evaluates regex; the canonical Rego corpus lives in a directory the build
  never copies. Both terms remain on `@complyedge/sdk`, which does call the OPA
  hot path.

### Fixed
- `trustlint --version` reported `2.0.0` on every release since the constant was
  written, because the CLI held a hardcoded version string that drifted from
  `package.json`. It now derives from `package.json`.

## [2.0.3] - 2026-08-16

### Added
- The rule corpus is now bundled in the published package. Before this, a clean
  install loaded zero rules and exited 2 — the linter installed but could not
  lint without an external `--rules-dir`.
- Release now runs through a CI workflow that refuses to publish a package whose
  declared entry points are missing, or whose `dist/` contains Python build
  artifacts rather than a JavaScript build.

## 2.0.2 - 2026-08-16

First release after a 15-month gap; npm had served 1.0.9 since 2025-05-08 while
the source moved on. Published to restore the npm distribution.

## 1.0.9 and earlier

Released before this changelog existed. See the repository history.

[2.0.5]: https://www.npmjs.com/package/trustlint/v/2.0.5
[2.0.4]: https://www.npmjs.com/package/trustlint/v/2.0.4
[2.0.3]: https://www.npmjs.com/package/trustlint/v/2.0.3
