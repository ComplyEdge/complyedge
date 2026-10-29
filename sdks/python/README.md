# ComplyEdge Python SDK

Prove what your AI decided, without keeping what it saw. Every request and answer is checked against open EU AI Act rules that cite the law: one record per decision, never a copy of the text.

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

## Quick Start: EU AI Act in Three Lines

```python
from complyedge import compliance_check

@compliance_check(
    jurisdiction="EU",
    agent_id="my-agent",
    decision_context={  # what only you know, for an ADCR-complete record
        "deciding_system": {"version": "gpt-5.4-2026-08-01"},
        "purpose_ref": "purpose:support-replies",
        "data_categories": ["contact"],
    },
)
def my_agent(prompt):
    return llm.generate(prompt)  # every input and output checked
```

That's it. Every input and output is checked against the EU AI Act rule set (Article 5, Article 50, GPAI). Every check gets a record with an `event_id`, the rules that fired (if any), a timestamp and a keyed hash of the text. A block by a rule also gets its legal citation. On a paid plan the injection check can also block when the month's model budget covers it, and that block names the law. A wider-review block does not cite an article. If that review is on and clears every hit, the request is allowed. `decision_context` is optional: without it every check still runs and is recorded, but the record does not meet ADCR class Record (see [Tell the record what only you know](#tell-the-record-what-only-you-know)). With the default fail mode, `open`, an API outage lets traffic through unchecked and unrecorded; set `COMPLYEDGE_FAIL_MODE=closed`, or pass `config=ComplianceConfig(fail_mode="closed")`, to raise `ComplianceUnavailableError` instead. Without an API key the decorator always runs the function unchecked.

Classifiers (`eu-ai-act-*` MCPs) score the *system*. ComplyEdge checks and records *this* prompt or output. Article 50 here is unlabeled or deceptive use, not C2PA watermarking.

Each line is an alternative; pick the one you need.

```bash
pip install complyedge                               # this SDK: hosted checks and the decorator
pip install 'complyedge[mcp]'                        # plus the MCP server: complyedge-mcp
pip install 'complyedge[agents]'                     # plus the OpenAI Agents guardrail
pip install trustlint                                # offline linter CLI, separate package
npx -y @complyedge/mcp                               # the MCP server on Node, no Python
claude mcp add complyedge -- npx -y @complyedge/mcp  # add the Node MCP server to Claude Code
```

OpenAI Agents extra (hosted path; needs `COMPLYEDGE_API_KEY`): `from complyedge.agents import create_compliance_guardrail`

GitHub Action: `uses: complyedge/trustlint-action@v1`

The decorator reads your API key from the `COMPLYEDGE_API_KEY` environment variable by default. Pass `api_key_env="MY_VAR"` to use a different one.

## Multi-Jurisdiction Enforcement

`jurisdiction` is where the end user is, not where your company is based: the EU AI Act applies when an AI system's output is used in the EU, wherever the provider or deployer is established ([Art. 2(1)(c)](https://eur-lex.europa.eu/eli/reg/2024/1689)). Default: `EU`.

| Value | What the phrase rules cover |
|---|---|
| `EU` | EU AI Act: Article 5 prohibited practices, plus Article 6 high-risk, Article 50 and GPAI (Articles 51 to 55) rules that fire on text describing a missing control; prompt-injection detection; personal data and secrets (citing GDPR). Any rule that fires blocks the call. |
| `US`, `US-*` | SEC Regulation FD selective disclosure + prompt-injection detection |

On a paid plan, a clean pass then runs an injection check when the month's model budget covers it, which can block. The wider review runs only when you turn it on and that budget covers it.

HIPAA, COPPA, TCPA, BIPA, CCPA, NYC LL144 and ECPA rules, and the GDPR YAML rules (consent, data minimisation, DPIA, erasure, breach notification, transfers), run offline in TrustLint (`pip install trustlint`), not on the hosted `/v1/check` path. The hosted personal data and secrets rules above cite GDPR Articles 5(1)(c) and 32(1).

```python
@compliance_check(jurisdiction="EU", agent_id="hr-screening")
def hr_screening(candidate: str) -> str:
    return llm.generate(candidate)
```

Per-rule scoping (e.g. only Article 5) is planned but not yet exposed in the SDK: all rules for the selected jurisdiction run today.

## Additional Installation Options

```bash
# Development setup
pip install 'complyedge[dev]'

# Local development from source
pip install -e ./sdks/python
```

## Client API: Without the Decorator

```python
from complyedge import ComplyEdge

ce = ComplyEdge(api_key="your-key")
result = ce.check("AI-generated content", jurisdiction="EU")

if result.allowed:
    print("Content approved")
else:
    for v in result.violations:
        print(f"{v.rule_id}: {v.rule_description}")  # the rule's legal citation
```

### Record who each check acts for

Every audit record has `user_id`, `user_role` and `session_id`. They are filled
only when you send them; leave them out and those columns are blank in your
audit export.

```python
# Per call
ce.check(text, user_id="ref_5d81e2c4", user_role="recruiter", session_id="conv_abc")

# Client defaults for an agent that always acts for the same person
ce = ComplyEdge(api_key=api_key, user_id="ref_5d81e2c4", user_role="recruiter", session_id=run_id)

# Decorator: a dict, or a zero-argument function read on every call
@compliance_check(jurisdiction="EU",
                  attribution=lambda: {"user_id": current_user.id, "session_id": request_id})
def answer(prompt: str) -> str:
    ...
```

`ComplyEdgeClient.check_compliance()` and the async client take the same three
keyword arguments; they override the same keys in `context`. Use a stable
identifier from your own system, never a name or an email address. `user_id`
and `session_id` are stored as keyed pseudonyms (`p1:...`) under your account's
own key, not as sent; `user_role` is stored as sent, so it must name a role, not
a person.

Never send a credential in these fields: a login token, session cookie, JWT or
API key would sit in every audit record and export. If your session id doubles
as a login token, send a hash of it (for example the first 16 hex characters of
its SHA-256). ComplyEdge replaces any token- or key-shaped value with
`redacted:` plus a hash before the record is written.

### Prove a record was about a given text

ComplyEdge never stores the prompt or the answer. The record keeps `text_hash`, a
keyed hash (HMAC-SHA-256) of the input under your account's own key, so it cannot
be recomputed locally. Keep the `event_id` next to your own copy of the text, and
ask the API when you need to prove the pair:

```python
result = ce.check(text)
app_log.info("chat turn", prompt=text, complyedge_event_id=result.event_id)  # your own log
# later, in an audit or a complaint:
assert ce.verify_input(result.event_id, text)  # True only for this exact text
```

Optional: pass `receipt_journal="/var/lib/app/complyedge-receipts.jsonl"` to
`ComplyEdge(...)` (or use `ReceiptJournal` yourself) to append `event_id`,
`text_hash`, and digests locally after each non-sandbox check. The journal never
stores the prompt; your app log still holds the text.

The full walkthrough, including what happens if you delete your copy early:
https://complyedge.io/docs/audit-reconciliation.html

`result.text_hash_alg` is `"hmac-sha256-1"`;
records written before the keyed hash was introduced carry none and hold a plain
SHA-256, which `verify_input` also checks.

### Tell the record what only you know

The audit record can carry fields ComplyEdge cannot know: the version of your AI
system, the purpose of the processing and the categories of personal data the
decision used. Pass them as `decision_context`; they are written to the record as
ADCR 0.1.0 fields (https://complyedge.io/producer-profile/). `decision_context` is
optional: without it the check runs and is recorded, but the record does not meet
ADCR class Record. When you send it, `deciding_system.version`, `purpose_ref` and
`data_categories` (`[]` when none) are required; every other key is optional.
`check()`, `is_safe()`, the global `check()` and `is_safe()`, `check_compliance()`
and the decorator (a dict, or a zero-argument function read on every call) all
take it.

```python
result = ce.check(
    text,
    decision_context={
        "deciding_system": {"version": "gpt-5.4-2026-08-01"},
        "purpose_ref": "purpose:support-replies",
        "data_categories": ["contact"],
    },
)
```

### Try a case without recording it

`sandbox=True` calls `POST /v1/sandbox/check`: the same rules, the same tenant
settings and the same verdict, but no audit entry, no usage and no count against
your plan's daily limit (sandbox calls have their own caps: 60 a minute, 1,000 a day). Use it to test cases before wiring an integration. A sandbox result is
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

Two regions, one home per account, chosen when you sign up and create your first API key: EU
(`eu.api.complyedge.io`, key prefix `ce_eu_`) or US (`api.complyedge.io`, key
prefix `ce_`). The SDK reads the prefix and picks the host. To change the
region later, use Request a region change in the dashboard; you get a new key for it.
`base_url`, `region`, `COMPLYEDGE_API_URL`, and `COMPLYEDGE_REGION` only
choose which host to call. They do not change the account's region.

The region is where your checks run and your audit records are stored. The prompt and the AI's answer are never stored. On a paid plan, after the phrase rules pass, the injection check sends that text to OpenAI in the US when the month's model budget covers it. The wider review sends it only when you turn it on and the month's model budget covers it.
It does not decide which laws are checked: the `jurisdiction` field on each
check does. No general law requires either region. US law does not require US
storage, and GDPR allows transfers outside the EU with safeguards such as
standard contractual clauses (Chapter V). Choose the region your own contracts
or customers ask for.

```python
ce = ComplyEdge(api_key="ce_eu_...")   # -> https://eu.api.complyedge.io
ce = ComplyEdge(api_key="ce_...")      # -> https://api.complyedge.io
```

To override, highest precedence first: `base_url=` (or `COMPLYEDGE_API_URL`),
then `region="us" | "eu"` (or `COMPLYEDGE_REGION`), then the key prefix, then EU. A key
presented to the other region's stack is refused with
`401 {"detail": {"error": "wrong_region", "use": "<host>"}}` before any lookup.

## MCP Server: Use ComplyEdge as an AI Agent Tool

<!-- mcp-name: io.github.ComplyEdge/complyedge -->

Agent/MCP tools that check prompts and outputs against ComplyEdge’s TrustLint
corpus with cited findings: not another EU AI Act risk-tier chatbot
and not a law-search database.

**Hosted Streamable HTTP (preferred for remote clients):**
`https://mcp.complyedge.io/mcp`

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

**Exposed tools** (TrustLint offline YAML rule set):

| Tool | Description |
|------|-------------|
| `check_compliance` | Check text against TrustLint rules. Returns PASS/FAIL with cited findings. |
| `list_rules` | List available TrustLint rules, filterable by jurisdiction. |
| `scan_prompt` | Pre-generation prompt scan. Returns SAFE or RISK_DETECTED. |

No API key is required for these tools. The optional extra installs `mcp` and
`trustlint` (engine + bundled rules). This MCP path does not run the REST API
policy engine.

**Optional hosted sandbox.** Set `COMPLYEDGE_API_KEY` in the server's
environment and a fourth tool appears:

| Tool | Description |
|------|-------------|
| `sandbox_check` | Hosted enforcement in sandbox mode (`POST /v1/sandbox/check`): your tenant's real rules and settings, same verdict as production, and nothing recorded: no audit entry, no usage, and no count against your plan's daily limit (sandbox calls have their own caps: 60 a minute, 1,000 a day). Returns BLOCKED or ALLOWED. A phrase-rule block carries the rule ID and the article. An injection block names the law. A wider-review block does not cite an article. Never evidence. |

Without the key the tool is not listed and the server stays fully offline.

On the hosted server (`https://mcp.complyedge.io/mcp`) `sandbox_check` is
always listed and works only for a caller that sends its own key as the
`Authorization: Bearer <key>` header on the MCP connection (set it in your MCP
client's headers). The key is never a tool argument and never logged; the
hosted server keeps no keys.

## Documentation

- [Quick start](https://complyedge.io/docs/quick-start.html)
- [API reference](https://complyedge.io/docs/api-reference.html)
- [Browser playground](https://complyedge.io/docs/playground.html)
- [Enforcement Seal embed](https://complyedge.io/docs/trust-badge.html)
