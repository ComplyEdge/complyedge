# Changelog

All notable changes to the public ComplyEdge packages are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/); versions
follow [Semantic Versioning](https://semver.org/).

`complyedge` (the SDK) and `trustlint` (the offline linter) are separate
packages and version independently.

## complyedge

### [0.2.4]
- Runtime EU AI Act enforcement via the `@compliance_check` decorator and the
  `/v1/check` API, returning OPA/Rego rule IDs (e.g. `rego-art5-1c-001`),
  legal citations, and an immutable audit record per decision.
- Corpus: 28 OPA/Rego policies (Article 5, Article 6, Article 50, GPAI) + 53 YAML rules
  across EU, US, global, and universal jurisdictions.

### [0.2.2]
- **Default behavior changed:** OPA-only by default. The LLM Layer 2 is now
  opt-in per request via `use_semantic_fallback=True`.

## trustlint

### [2.0.0]
- Offline regex linter over the YAML rule corpus. No API key required; emits
  `EU_AI_ACT_*` rule IDs for CI/CD use. Exit code `1` on any violation.
