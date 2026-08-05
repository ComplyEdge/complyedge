![Layer-1 p99](https://img.shields.io/badge/Layer--1_p99-4.866ms-brightgreen)

_Layer-1 deterministic hot path (OPA/Rego + TrustLint regex, no LLM) · 500 iterations · 2026-08-04T21:51:24.259645+00:00_

- OPA single-package p99 (parallel path): 3.549 ms
- OPA 6-package sequential p99 (conservative): 17.529 ms
- TrustLint regex p99: 1.317 ms
- **Realized Layer-1 hot-path p99: 4.866 ms** — <100ms claim: PASS
