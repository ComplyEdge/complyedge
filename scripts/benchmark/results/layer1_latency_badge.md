![Layer-1 p99](https://img.shields.io/badge/Layer--1_p99-1.508ms-brightgreen)

_Layer-1 deterministic hot path (OPA/Rego + TrustLint regex, no LLM) · 500 iterations · 2026-07-07T13:47:39.415881+00:00_

- OPA single-package p99 (parallel path): 1.176 ms
- OPA 4-package sequential p99 (conservative): 3.677 ms
- TrustLint regex p99: 0.332 ms
- **Realized Layer-1 hot-path p99: 1.508 ms** — <100ms claim: PASS
