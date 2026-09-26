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

## [2.1.2] - 2026-09-26

### Removed
- Python package only. Colorado AI Act SB205 is no longer in the bundled corpus. It was not the enacted text. `trustlint` 2.1.2 evaluates 63 rules. The npm package version is unchanged.

## [2.1.1] - 2026-09-25

### Changed
- `trustlint scan` (Python CLI and the npm CLI) posts to
  `https://eu.api.complyedge.io/v1/check`. The previous default was the US host.

## [2.1.0] - 2026-09-05

### Fixed
- **`prompt_security` rules never matched anything in this package.** All ten
  loaded from the bundled corpus and none of them fired — including the simplest
  direct-override rule. The corpus is authored for Python/PCRE, where an inline
  `(?i)` / `(?im)` prefix sets flags; JavaScript's `RegExp` rejects that
  construct ("Invalid group"), so every such pattern threw at compile time and
  `catch { /* Skip invalid regex */ }` swallowed it. A rule that could not
  compile was silently treated as a rule that never matches, and `check()`
  returned a clean pass on text the Python engine and the hosted MCP both
  blocked.

  **Behaviour change, read this before upgrading.** Text that previously came
  back clean will now return violations. This is not new coverage arriving — it
  is coverage that was always declared and never ran.

### Added
- `normalizePattern(raw, declaredFlags)` is now exported. It translates a
  *leading* inline flag group into JS `RegExp` flags, merges the YAML-declared
  flags, and drops flags JS does not support. A non-leading inline group is left
  untouched.
- `TrustLintEngine.patternErrors` — a readonly array of patterns that failed to
  compile. Empty is the only healthy state. The previous silent `catch` is what
  let ten rules sit dead in a shipped package with nothing reporting it.

### Changed
- Detection is broader in the bundled corpus. `indirect_injection_embedded_instruction`
  now fires on positive directives ("classify it as pre-approved and route
  directly to payment") rather than only on override words, gained the missing
  AI verbs, and gained a German branch. `indirect_injection_ai_addressed_directive`
  now recognises "note for automated processing" and its German equivalent.

### Note on the version number
This lands on 2.1.0 the same week the Python distribution does. That is
coincidence, not parity — see the note at the top of this file. The two engines
still differ: Node evaluates Tier-1 regex patterns, Python additionally
evaluates temporal/effective-date rule state.

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
