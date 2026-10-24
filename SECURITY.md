# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub issue for security reports.**

Email **support@complyedge.io** with:

- a description of the issue and its impact,
- steps to reproduce (a prompt, request, or rule that misbehaves),
- the affected package and version (`pip show complyedge`, `pip show trustlint`,
  or `npm ls @complyedge/sdk @complyedge/mcp trustlint`).

## Scope

Reports are accepted for:

- The packages built from this repository: the `complyedge` Python SDK (PyPI),
  the `@complyedge/sdk` TypeScript SDK (npm), the `@complyedge/mcp` MCP server
  (npm), and the `trustlint` offline linter (PyPI and npm).
- The audit-export verifier in `services/api/` (`audit_export.py` and the
  modules it imports).
- The OPA/Rego policies and YAML rule set in this repository.
- The hosted ComplyEdge service (the API, the dashboard and the hosted MCP
  server). Its code is not in this repository; report issues with it through
  the same private channel above.

Not a security report:

- Rule **misclassification** (a prompt that should block but passes, or vice
  versa): open an issue with the prompt and the expected decision. This is a
  correctness bug.
- Denial of service through deliberately oversized inputs.

## Supported Versions

Fixes land in the latest released version of each package, on PyPI and on npm.
Older versions do not receive security backports: upgrade to the latest release.
