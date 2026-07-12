# Changelog

All notable changes to the public ComplyEdge packages are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/); versions
follow [Semantic Versioning](https://semver.org/).

`complyedge` (the SDK) and `trustlint` (the offline linter) are separate
packages and version independently.

## complyedge

### [0.2.5]
- Corpus aligned to leaf-basis counting: **64 YAML rules** + **51 deterministic
  leaf OPA/Rego policies** (+ 5 package aggregators) across EU, US, global, and
  universal jurisdictions — matching the live website and hosted API.
- Added EU AI Act leaf coverage (Art. 6 Annex III 5b/5c, Art. 6(3) derogation,
  GPAI open-source exemption, Article 50 emotion permitted-context notice).
- Runtime benchmark results refreshed (see `scripts/benchmark/results/`).

### [0.2.4]
- Runtime EU AI Act enforcement via the `@compliance_check` decorator and the
  `/v1/check` API, returning OPA/Rego rule IDs (e.g. `rego-art5-1c-001`),
  legal citations, and an immutable audit record per decision.
- Corpus at release: OPA/Rego hot path + YAML rules across EU, US, global, and
  universal jurisdictions (superseded by 0.2.5 leaf-basis counts above).

### [0.2.2]
- **Default behavior changed:** OPA-only by default. The LLM Layer 2 is now
  opt-in per request via `use_semantic_fallback=True`.

## trustlint

### [2.0.3]
- Tracks the current YAML rule corpus used by the offline linter.

### [2.0.0]
- Offline regex linter over the YAML rule corpus. No API key required; emits
  `EU_AI_ACT_*` rule IDs for CI/CD use. Exit code `1` on any violation.
