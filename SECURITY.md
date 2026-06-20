# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub issue for security reports.**

Email **support@complyedge.io** with:

- a description of the issue and its impact,
- steps to reproduce (a prompt, request, or rule that misbehaves),
- the affected version (`pip show complyedge` / `pip show trustlint`).

We acknowledge reports within 72 hours and aim to ship a fix or mitigation
within 14 days for confirmed issues. We will credit reporters who wish to be
named once a fix is released.

## Scope

In scope:

- The `complyedge` Python SDK and the `trustlint` offline linter.
- The OPA/Rego policies and YAML rule corpus in this repository.
- Rule **misclassification** (a prompt that should block but passes, or vice
  versa) — open an issue with the prompt and expected decision; this is a
  correctness bug, not a security report.

Out of scope:

- The hosted API backend and infrastructure (report those to
  support@complyedge.io directly).
- Denial-of-service via deliberately oversized inputs.

## Supported Versions

We support the latest released version of each package on PyPI. Older versions
do not receive security backports — pin to the latest release.
