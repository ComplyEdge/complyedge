# ComplyEdge Python SDK

Runtime EU AI Act Article 5 and Article 50 enforcement. Open source.

## Choose the Right Package

`complyedge` is the Python client for the hosted ComplyEdge runtime API. It
enforces policy decisions in your application and records the resulting
evidence trail. For an offline command-line linter with no API key, use
[TrustLint](https://pypi.org/project/trustlint/) instead.

- [ComplyEdge package](https://pypi.org/project/complyedge/)
- [TrustLint package](https://pypi.org/project/trustlint/)
- [Documentation](https://complyedge.io/docs)
- [Trust portal](https://trust.complyedge.io)

## Installation

```bash
pip install complyedge
```

## Quick Start — EU AI Act in Three Lines

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt):
    return llm.generate(prompt)  # every input and output checked
```

That's it. Every input and output is checked against the EU AI Act rule corpus (Article 5, Article 50, GPAI). Violations are blocked before they reach the user, with legal citation, rule ID, and timestamp on every check.

Classifiers (`eu-ai-act-*` MCPs) score the *system*. ComplyEdge denies *this* prompt or output now. Article 50 here is unlabeled or deceptive use, not C2PA watermarking.

```bash
pip install complyedge
pip install trustlint
pip install 'complyedge[mcp]'
pip install 'complyedge[agents]'
npx -y @complyedge/mcp
claude mcp add complyedge -- npx -y @complyedge/mcp
```

OpenAI Agents extra (hosted path; needs `COMPLYEDGE_API_KEY`): `from complyedge.agents import create_compliance_guardrail`

GitHub Action: `uses: complyedge/trustlint-action@v1`

GOPAL is an OPA library in your process. ComplyEdge is per-request deny + citation + AI Trust Center + MCP.

The decorator reads your API key from the `COMPLYEDGE_API_KEY` environment variable by default. Pass `api_key_env="MY_VAR"` to use a different one.

## Multi-Jurisdiction Enforcement

`jurisdiction` selects which rule corpus is evaluated server-side.

| Value | Corpus |
|---|---|
| `EU` | EU AI Act Article 5 + Article 50 + GPAI (Articles 51–55) |
| `US` | HIPAA, SOX, COPPA, TCPA, BIPA |

```python
@compliance_check(jurisdiction="EU", agent_id="hr-screening")
def hr_screening(candidate: str) -> str:
    return llm.generate(candidate)
```

Per-rule scoping (e.g. only Article 5) is planned but not yet exposed in the SDK — all rules for the selected jurisdiction run today.

## Additional Installation Options

```bash
# Development setup
pip install complyedge[dev]

# Local development from source
pip install -e ./sdks/python
```

## Client API — Without the Decorator

```python
from complyedge import ComplyEdge

ce = ComplyEdge(api_key="your-key")
result = ce.check("AI-generated content", jurisdiction="EU")

if result.allowed:
    print("Content approved")
else:
    for v in result.violations:
        print(f"{v.rule_id}: {v.citation}")
```

### Try a case without recording it

`sandbox=True` calls `POST /v1/sandbox/check`: the same rules, the same tenant
settings and the same verdict, but no audit entry, no usage and no rate-limit
count. Use it to test cases before wiring an integration. A sandbox result is
never evidence: `result.sandbox` is `True` and `result.audit_logged` is `False`.

```python
result = ce.check("Score users based on their social behavior", sandbox=True)
print(result.blocked, result.sandbox)  # True True
```

Or the global convenience functions:

```python
from complyedge import is_safe, check
import os

api_key = os.environ["COMPLYEDGE_API_KEY"]

# Boolean check
if not is_safe(text, api_key=api_key, jurisdiction="EU"):
    raise ValueError("Compliance violation")

# Full result
result = check(text, api_key=api_key, jurisdiction="EU")
```

## Rotating your key

Keys are shown once, at creation, and stored as a hash: a lost key cannot be
recovered, only replaced. Rotate without downtime, in this order:

1. In the dashboard, open **API Key** and click **Rotate key** on the card
   (or **Rotate** on a row under Other active keys), then confirm. A new key
   is minted and shown once; the old one keeps working.
2. Put the new key in your integration (`COMPLYEDGE_API_KEY` or the `api_key` you pass to the client) and deploy.
3. Back in the reveal, click **Revoke previous key**. Requests with the old key
   fail from that moment. If you need more time, **Keep both for now** and
   revoke it later from the API Key page, where every active key is listed.

Compromised key: revoke first (Revoke this key on the card, or Revoke on the
row), then rotate. Via the API the same flow is `POST /v1/account/api-keys`,
then `DELETE /v1/account/api-keys/{key_id}` for the old key.

## Company name on the public trust surface

Your public AI Trust Center and Enforcement Seal show one company name: the
one set in the dashboard under Account, Profile. `display_name` on
`PATCH /v1/tenant/trust` sets the same value, so an API call and the profile
never disagree. Email is your sign-in and cannot be changed from the dashboard.

## Regions

ComplyEdge runs one independent stack per region — US (`api.complyedge.io`) and
EU (`eu.api.complyedge.io`, Frankfurt). Your tenant, its audit trail and its
API keys live in exactly one of them. The key says which: keys issued by the EU
stack start with `ce_eu_`, US keys with `ce_`. The SDK reads the prefix and
picks the host, so nothing needs configuring:

```python
ce = ComplyEdge(api_key="ce_eu_...")   # -> https://eu.api.complyedge.io
ce = ComplyEdge(api_key="ce_...")      # -> https://api.complyedge.io
```

To override, highest precedence first: `base_url=` (or `COMPLYEDGE_API_URL`),
then `region="us" | "eu"` (or `COMPLYEDGE_REGION`), then the key prefix. A key
presented to the other region's stack is refused with
`401 {"error": "wrong_region", "use": "<host>"}` before any lookup.

## MCP Server — Use ComplyEdge as an AI Agent Tool

<!-- mcp-name: io.github.ComplyEdge/complyedge -->

[![Smithery](https://img.shields.io/badge/Smithery-listed-6b46c1)](https://smithery.ai/servers/complyedge/complyedge)

Agent/MCP tools that check prompts and outputs against ComplyEdge’s TrustLint
corpus with article-cited findings — not another EU AI Act risk-tier chatbot
and not a law-search database.

**Hosted Streamable HTTP (preferred for remote / Smithery Toolbox):**
`https://mcp.complyedge.io/mcp`

```bash
npx -y @smithery/cli@latest mcp add complyedge/complyedge --client cursor
```

**Local stdio** for any MCP-compatible host (Claude, Cursor, Inspector):

```bash
pip install 'complyedge[mcp]>=0.2.8'
python -m complyedge.mcp_server
# or: complyedge-mcp
```

Add to your MCP client config (e.g. `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "complyedge": {
      "command": "complyedge-mcp"
    }
  }
}
```

(`command`/`args` with `python -m complyedge.mcp_server` is also valid.)

**Exposed tools** (TrustLint offline YAML corpus):

| Tool | Description |
|------|-------------|
| `check_compliance` | Check text against TrustLint rules. Returns PASS/FAIL with article-cited findings. |
| `list_rules` | List available TrustLint rules, filterable by jurisdiction. |
| `scan_prompt` | Pre-generation prompt scan. Returns SAFE or RISK_DETECTED. |

No API key is required for these tools. The optional extra installs `mcp` and
`trustlint` (engine + bundled rules). This MCP path does not run the REST API
policy engine.

**Optional hosted sandbox.** Set `COMPLYEDGE_API_KEY` in the server's
environment and a fourth tool appears:

| Tool | Description |
|------|-------------|
| `sandbox_check` | Hosted enforcement in sandbox mode (`POST /v1/sandbox/check`): your tenant's real rules and settings, same verdict as production, and nothing recorded: no audit entry, no usage, no rate-limit count. Returns BLOCKED/ALLOWED with rule ID and article citation. Never evidence. |

Without the key the tool is not listed and the server stays fully offline.

On the hosted server (`https://mcp.complyedge.io/mcp`) `sandbox_check` is
always listed and works only for a caller that sends its own key as the
`Authorization: Bearer <key>` header on the MCP connection (set it in your MCP
client's headers). The key is never a tool argument and never logged; the
hosted server keeps no keys.

## Documentation

- [Quick start](https://www.complyedge.io/docs/quick-start.html)
- [API reference](https://www.complyedge.io/docs/api-reference.html)
- [Browser playground](https://www.complyedge.io/docs/playground.html)
- [Enforcement Seal embed](https://www.complyedge.io/docs/trust-badge.html)
