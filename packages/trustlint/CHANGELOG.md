# Changelog

All notable changes to the `trustlint` package are documented here: the npm
package, and from 2.1.1 on also the Python package on PyPI where an entry says so.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This file was started at 2.0.4**, together with the 2.0.2 and 2.0.3 entries.
Releases 1.0.7 through 1.0.9 shipped before it and are listed without notes
rather than reconstructed: a history written after the fact from guesswork would
look authoritative and be wrong.

The Python distribution of TrustLint is versioned independently. Equal version
numbers do not mean the two engines match: the Node engine evaluates Tier-1 regex patterns, the Python engine additionally evaluates
temporal/effective-date rule state, so matching numbers would imply a parity
that does not exist.

## [Unreleased]

## [2.2.0] - 2026-10-23

### Changed
- npm description states 63 rules (was 64). Dropped the `prompt-security` and `security` keywords and the `Topic :: Security` classifier; the README leads with the audit record and points to the hosted check for it.

### Fixed
- The rules you installed are the rules that run. `trustlint rules update` (both CLIs)
  downloaded the 2026-07 GitHub release (64 rules, including the withdrawn Colorado
  SB205 rule) into `~/.trustlint/rules`, and both engines read that directory before
  the bundled rule set, so every later check and upgrade kept using it. The engines no
  longer read `~/.trustlint/rules`; `rules update` downloads nothing and tells you to
  upgrade the package. Order is now `--rules-dir`, then `rules/regulations` in or above
  the current directory, then the bundled rules.
- `trustlint scan` calls the host of your key's region (`ce_eu_` to
  eu.api.complyedge.io, `ce_` to api.complyedge.io). It called the EU host for every key.
- `scan` help no longer calls the hosted check a "Tier 2 LLM compliance analysis" and
  says it writes an audit record.
- `trustlint check` in the npm CLI reads piped stdin (`echo "..." | trustlint check`),
  as the Python CLI does; it exited 2.
- Every finding now carries a citation. `PCI_DSS_INPUT_001` and `UNIVERSAL_PII_INPUT_001` rest on no legal article and returned an empty citation; both engines (Node and Python) now fall back to the rule's `provision_label`, which names the standard or says the rule is not law.

### Removed
- `trustlint init` (both CLIs). It wrote a `.trustlint.yaml` that no command read, so
  its rules directory, jurisdiction, severity and include/exclude settings never took
  effect. Use `--rules-dir`, `--jurisdiction` and (Python) `--severity-threshold`.

## [2.1.2] - 2026-09-26 (Python), 2026-10-01 (npm)

### Removed
- Colorado AI Act SB205 is no longer in the bundled corpus. It was not the enacted text. `trustlint` 2.1.2 evaluates 63 rules. Shipped to PyPI on 2026-09-26 and to npm on 2026-10-01; npm 2.1.1 still bundles the 64-rule corpus.

## [2.1.1] - 2026-09-25

### Changed
- `trustlint scan` (Python CLI and the npm CLI) posts to
  `https://eu.api.complyedge.io/v1/check`. The previous default was the US host.

## [2.1.0] - 2026-09-07

### Fixed
- **`prompt_security` rules never matched anything in this package.** All ten
  loaded from the bundled corpus and none of them fired, including the simplest
  direct-override rule. The corpus is authored for Python/PCRE, where an inline
  `(?i)` / `(?im)` prefix sets flags; JavaScript's `RegExp` rejects that
  construct ("Invalid group"), so every such pattern threw at compile time and
  `catch { /* Skip invalid regex */ }` swallowed it. A rule that could not
  compile was silently treated as a rule that never matches, and `check()`
  returned a clean pass on text the Python engine and the hosted MCP both
  blocked.

  **Behaviour change, read this before upgrading.** Text that previously came
  back clean will now return violations. This is not new coverage arriving; it
  is coverage that was always declared and never ran.

### Added
- `normalizePattern(raw, declaredFlags)` in the engine module
  (`trustlint/dist/engine.js`; the package entry exports only `TrustLintEngine`
  and the types). It translates a
  *leading* inline flag group into JS `RegExp` flags, merges the YAML-declared
  flags, and drops flags JS does not support. A non-leading inline group is left
  untouched.
- `TrustLintEngine.patternErrors`: a readonly array of patterns that failed to
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
coincidence, not parity; see the note at the top of this file. The two engines
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
- Description rewritten to name the regulations covered (Art. 5 prohibited
  practices, Art. 50 transparency, GDPR, HIPAA, SOX, PCI DSS, COPPA) rather
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
  install loaded zero rules and exited 2: the linter installed but could not
  lint without an external `--rules-dir`.
- Release now runs through a CI workflow that refuses to publish a package whose
  declared entry points are missing, or whose `dist/` contains Python build
  artifacts rather than a JavaScript build.

## 2.0.2 - 2026-08-16

First release after a 15-month gap; npm had served 1.0.9 since 2025-05-08 while
the source moved on. Published to restore the npm distribution.

## 1.0.7 to 1.0.9

Released before this changelog existed. See the repository history.

[Unreleased]: https://github.com/ComplyEdge/complyedge/commits/main/packages/trustlint
[2.2.0]: https://www.npmjs.com/package/trustlint/v/2.2.0
[2.1.2]: https://www.npmjs.com/package/trustlint/v/2.1.2
[2.1.1]: https://www.npmjs.com/package/trustlint/v/2.1.1
[2.1.0]: https://www.npmjs.com/package/trustlint/v/2.1.0
[2.0.5]: https://www.npmjs.com/package/trustlint/v/2.0.5
[2.0.4]: https://www.npmjs.com/package/trustlint/v/2.0.4
[2.0.3]: https://www.npmjs.com/package/trustlint/v/2.0.3
