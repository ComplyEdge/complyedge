# TrustLint

[![PyPI version](https://img.shields.io/pypi/v/trustlint.svg)](https://pypi.org/project/trustlint/)
[![Python versions](https://img.shields.io/pypi/pyversions/trustlint.svg)](https://pypi.org/project/trustlint/)
[![PyPI provenance](https://img.shields.io/badge/PyPI-PEP%20740%20provenance-3775A9)](https://docs.pypi.org/attestations/)

**Offline Python compliance linter for AI agents** — scans text against the
bundled ComplyEdge rule corpus. No API key is required for local checks.

TrustLint catches rule-backed EU AI Act, SOX, HIPAA, GDPR, COPPA, and PCI DSS
risks before text reaches production.

## Install

```bash
pip install trustlint
```

The wheel includes its rule corpus, so it does not need a local `rules/`
directory.

## Quick Start

```bash
trustlint check --text "Deploy social credit score for citizens"
```

Use `trustlint check prompt.txt` to scan a file, or
`trustlint rules list` to inspect the available rules.

## Hosted API vs. Offline Linter

TrustLint runs locally and needs no API key. For runtime policy enforcement and
an application-facing evidence trail, use the hosted
[ComplyEdge Python SDK](https://pypi.org/project/complyedge/).

- [ComplyEdge Python SDK](https://pypi.org/project/complyedge/)
- [TrustLint npm package](https://www.npmjs.com/package/trustlint)
- [Documentation](https://complyedge.io/docs)
- [Trust portal](https://trust.complyedge.io)
- [Source and issues](https://github.com/ComplyEdge/complyedge)

## Scope

TrustLint is an offline linter. Its Python engine evaluates the bundled rule
corpus, including temporal and effective-date rule state. It does not replace
the hosted ComplyEdge API when an application needs runtime policy enforcement
and an evidence trail.

## License

Apache-2.0 — [ComplyEdge](https://complyedge.io)
