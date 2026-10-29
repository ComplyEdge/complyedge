# TrustLint

[![PyPI version](https://img.shields.io/pypi/v/trustlint.svg)](https://pypi.org/project/trustlint/)
[![Python versions](https://img.shields.io/pypi/pyversions/trustlint.svg)](https://pypi.org/project/trustlint/)
[![PyPI provenance](https://img.shields.io/badge/PyPI-PEP%20740%20provenance-3775A9)](https://docs.pypi.org/attestations/)

**Offline Python compliance linter for AI agents**: EU AI Act Article 5 and
Article 50 (and related corpus rules). Scans text against its bundled TrustLint
rule set. No API key is required for local checks.

TrustLint catches rule-backed EU AI Act, SOX, HIPAA, GDPR, COPPA, and PCI DSS
risks before text reaches production.

## Install

```bash
pip install trustlint
```

The wheel includes its rule set, so it does not need a local `rules/`
directory. TrustLint reads, in order: `--rules-dir`, a `rules/regulations` folder in
the current directory or above it, then the bundled rules. Update the rules by
upgrading the package (`pip install -U trustlint`).

## Quick Start

```bash
trustlint check --text "Deploy social credit score for citizens"
```

Use `trustlint check prompt.txt` to scan a file, or
`trustlint rules list` to inspect the available rules.

## Hosted API vs. Offline Linter

`trustlint check` and `trustlint rules list` run locally, need no API key and record
nothing. `trustlint scan` with `COMPLYEDGE_API_KEY` sends the text to the hosted check
(`ce_eu_` keys to eu.api.complyedge.io, `ce_` keys to api.complyedge.io), which writes
an audit record. For the hosted
check and its audit record (for every decision a timestamp, a keyed hash of the
text and an `event_id`, plus the rule and the law named when a phrase rule or the injection check fired. A wider-review block does not cite an article; never
the text itself), use the
[ComplyEdge Python SDK](https://pypi.org/project/complyedge/).

- [ComplyEdge Python SDK](https://pypi.org/project/complyedge/)
- [TrustLint npm package](https://www.npmjs.com/package/trustlint)
- [Documentation](https://complyedge.io/docs)
- [Trust portal](https://trust.complyedge.io)
- [Source and issues](https://github.com/ComplyEdge/complyedge)

## Scope

TrustLint is an offline linter. Its Python engine runs the regex conditions of
the bundled rule corpus and applies the sanctions rules' effective-window and
carve-out state; semantic conditions in the rule files are not run. It does not replace
the hosted ComplyEdge API when an application needs runtime policy enforcement
and an evidence trail.

## License

Apache-2.0, [ComplyEdge](https://complyedge.io)
