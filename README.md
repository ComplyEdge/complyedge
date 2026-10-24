# ComplyEdge

[![PyPI](https://img.shields.io/pypi/v/complyedge)](https://pypi.org/project/complyedge/)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Smithery](https://img.shields.io/badge/Smithery-listed-6b46c1)](https://smithery.ai/servers/complyedge/complyedge)

**Prove what your AI decided. Without keeping what it saw.**

Every AI call routed through ComplyEdge is checked against rules that cite the law. One record per decision, never a copy of the text.

Each record holds the rules that fired and the article behind each, the exact rule set that decided (`bundle_digest`), the time, a keyed hash of the text and an `event_id`. It is kept outside your AI system, and you keep the text: with the `event_id` you can prove to an auditor, a data protection officer or a certifier which text a record was about, and ComplyEdge never keeps the content. When a rule that covers the act itself fires (Article 5 practices, prompt injection under Article 15(5), and on EU checks personal data and secrets such as email, phone, IBAN, card and national ID numbers, API keys and private keys), the request or answer is blocked and the block is recorded with its citation. Article 50, GPAI and high-risk rules fire on text that describes a missing control, and when one fires the call is blocked and recorded the same way. It checks *this* prompt or output; it does not classify your system. The rules in this repository are the rule set ComplyEdge runs. What a decision record must contain and prove is a separate document, ADCR, the open rulebook: [complyedge.io/rulebook](https://complyedge.io/rulebook/).

The same rules are available to your agent as an **MCP server** that checks the text you pass it, offline, with an article citation on every finding.

Ships three ways: a Python SDK, an offline CI linter (TrustLint), and an **MCP server**, a Model Context Protocol server that exposes compliance checks as tools to any MCP host (Claude, Cursor, MCP Inspector).

**When an auditor, a regulator or a large customer asks "which rule decided this, under which law, and can you prove it was this text?", the answer is a record, not a log line.** Each record names the rule and the article, and you can prove which text it was about without sending the text to anyone who did not already have it. The sections "Verify a record" and "The rulebook" below show how.

> What does your compliance tool tell a regulator when it blocks a request? A probability score?
>
> ComplyEdge says: **Article 5(1)(a), rule `rego-art5-1a-001`, timestamp, keyed input hash.** One is an audit trail. One is a guess.

## MCP Server (Model Context Protocol)

ComplyEdge TrustLint is an MCP server built on the official [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk) (`mcp>=1.9`). It gives an agent article-cited compliance checks instead of a probability score, and it runs fully offline: no API key, no network call, rules evaluated from the bundled YAML rule set.

**Tools** (the server exposes MCP tools only: no resources, no prompts; all are read-only and idempotent):

| Tool | What it does |
|---|---|
| `check_compliance` | Check text against the TrustLint rule set. Returns PASS/FAIL with rule ID, severity, and the article citation behind each finding. |
| `list_rules` | List available rules, filterable by jurisdiction (`EU`, `US`, `Global`, `Universal`). |
| `scan_prompt` | Pre-generation prompt scan. Returns `SAFE` or `RISK_DETECTED` before the model is called. |
| `sandbox_check` | Optional, with your API key: hosted enforcement in sandbox mode (`POST /v1/sandbox/check`). Your tenant's real rules and settings, the same verdict as production, and nothing recorded: no audit entry, no usage, no rate-limit count. Returns `BLOCKED`/`ALLOWED` with rule ID and article citation. Never evidence. |

**Local (stdio)**: for Claude Desktop, Cursor, MCP Inspector, or any MCP host:

```bash
pip install 'complyedge[mcp]'
complyedge-mcp          # or: python -m complyedge.mcp_server
```

```json
{
  "mcpServers": {
    "complyedge": {
      "command": "complyedge-mcp"
    }
  }
}
```

**Remote (Streamable HTTP):** `https://mcp.complyedge.io/mcp`

`sandbox_check` is the one tool that needs a key. Locally, set `COMPLYEDGE_API_KEY`
in the server's environment (without it the tool is not listed and the server stays
fully offline). On the hosted server it is always listed and works only for a caller
that sends its own key as the `Authorization: Bearer <key>` header on the MCP
connection; the key is never a tool argument, never logged, and the hosted server
keeps no keys.

```json
{
  "mcpServers": {
    "complyedge": {
      "url": "https://mcp.complyedge.io/mcp",
      "headers": { "Authorization": "Bearer ce_your_api_key" }
    }
  }
}
```

Server source: [`sdks/python/complyedge/mcp_server.py`](sdks/python/complyedge/mcp_server.py). Full MCP docs: [`sdks/python/README.md`](sdks/python/README.md). The three offline tools use the TrustLint engine and never call the hosted OPA/Rego policy API; `sandbox_check` is the one that does, and only with your key.

**Install (coding agents):**

```bash
pip install complyedge
pip install trustlint
pip install 'complyedge[mcp]'
npx -y @complyedge/mcp
claude mcp add complyedge -- npx -y @complyedge/mcp
```

Listing: [smithery.ai/servers/complyedge/complyedge](https://smithery.ai/servers/complyedge/complyedge)

Cursor one-click: [Install TrustLint MCP](cursor://anysphere.cursor-deeplink/mcp/install?name=ComplyEdge%20TrustLint%20EU%20AI%20Act&config=eyJ1cmwiOiAiaHR0cHM6Ly9tY3AuY29tcGx5ZWRnZS5pby9tY3AifQ)

OpenAI Agents extra (hosted path; needs `COMPLYEDGE_API_KEY`):

```bash
pip install 'complyedge[agents]'
```

```python
from complyedge.agents import create_compliance_guardrail
```

CI: `uses: complyedge/trustlint-action@v1`

## Live enforcement seals

Not a static badge. These seals reflect live `/v1/check` traffic from open-source projects
embedding ComplyEdge: they change as real enforcement happens.

Both projects below are our own. ComplyEdge runs in production against our own code
before we ask anyone else to run it against theirs. You choose the region
when you create an account: EU (`https://eu.api.complyedge.io`, key prefix `ce_eu_`)
or US (`https://api.complyedge.io`, key prefix `ce_`). The seals below use the US
host because those accounts live in the US. The SDK reads the key and calls that
host. To move an existing account, use Request a region change in the dashboard.
Support moves the account and issues a new key.
Setting an API URL does not move the account.
The region is where checks run and audit records are stored; prompt text is never stored, only a keyed hash of it (HMAC-SHA-256 under your account's own key).
It does not decide which laws are checked: the `jurisdiction` field on each
check does. No general law requires either region. US law does not require US
storage, and GDPR allows transfers outside the EU with safeguards such as
standard contractual clauses (Chapter V). Choose the region your own contracts
or customers ask for.

[![IVD Framework: runtime enforcement](https://api.complyedge.io/v1/public/badge/ivd.svg)](https://trust.complyedge.io/ivd)
[![Horizon: runtime enforcement](https://api.complyedge.io/v1/public/badge/horizon.svg)](https://trust.complyedge.io/horizon)

| Project | Live AI Trust Center |
|---------|-----------------|
| **IVD Framework** | [trust.complyedge.io/ivd](https://trust.complyedge.io/ivd) |
| **Horizon** | [trust.complyedge.io/horizon](https://trust.complyedge.io/horizon) |

Each AI Trust Center is generated from that project's real audit trail: enforcement status, check
volume, and the EU AI Act articles its traffic is checked against. (GitHub proxies and caches images, so the
seal above can lag; the AI Trust Center is always current.)

Embed one on your own project: [Enforcement Seal docs](https://complyedge.io/docs/trust-badge.html).

## Quick Start

```bash
pip install complyedge
```

```python
from complyedge import compliance_check

@compliance_check(jurisdiction="EU", agent_id="my-agent")
def my_agent(prompt):
    return llm.generate(prompt)  # every input and output checked
```

Three lines. Every AI input and output evaluated against the EU AI Act rule set (Article 5, Article 50, GPAI). Every decision gets a record with an `event_id`, the rules that fired (if any), a timestamp and a keyed text hash; every block also gets its legal citation. Inputs and outputs that break a blocking rule are stopped before they reach the user. With the default `fail_mode="open"`, an API outage lets traffic through unchecked and unrecorded; use `fail_mode="closed"` to block instead.

Set `COMPLYEDGE_API_KEY` to your key. The decorator activates by default; to disable without removing the key (e.g., in CI), set `COMPLYEDGE_ENABLED=false`.

## Without a decorator

```python
from complyedge import is_safe, check
import os

api_key = os.environ["COMPLYEDGE_API_KEY"]

# Boolean check: returns True if no violations
if not is_safe(prompt, api_key=api_key, jurisdiction="EU"):
    raise ValueError("Prompt violates EU AI Act")

# Full result: returns ComplianceResult with the violations that blocked it
result = check(prompt, api_key=api_key, jurisdiction="EU")
if not result.allowed:
    for v in result.violations:
        print(v.rule_id, v.severity, v.rule_description)
```

## Verify a record

ComplyEdge never stores your prompts or outputs. The record keeps `text_hash`, a keyed hash (HMAC-SHA-256, `text_hash_alg: "hmac-sha256-1"`) of the text under your account's own key, which never leaves ComplyEdge. User and session identifiers you send are stored as keyed pseudonyms (`p1:...`), not as sent. So the record proves a decision without holding the content, and the reconciliation step is yours:

1. **Store the `event_id`** returned by every check next to your own copy of the prompt or output.
2. **Verify the pair later** with `POST /v1/audit/verify` (`{"event_id": ..., "text": ...}`), or from the SDK:

```python
from complyedge import ComplyEdge

ce = ComplyEdge(api_key=api_key)
result = ce.check(text, jurisdiction="EU")
my_log.write(prompt=text, complyedge_event_id=result.event_id)   # your own copy

# later, in an audit or a complaint
assert ce.verify_input(result.event_id, text)   # True only for this exact text
```

In TypeScript the same call is `client.verifyInput(eventId, text)`. The text you send to verify is used for that request only; it is not stored and not logged. If your copy of the text is gone, the record still proves that a decision was made and which rule made it, but not which text it was about. Full walkthrough: [complyedge.io/docs/audit-reconciliation.html](https://complyedge.io/docs/audit-reconciliation.html).

Each record joins your account's hash chain as it is written, in the same transaction. On Enterprise, the audit export carries that chain and is tamper-evident: any edit, deletion or reordering of a record is detectable, and a reviewer can check it offline with `python -m audit_export verify export.json` ([`services/api/audit_export.py`](services/api/audit_export.py)).

This is compliance evidence, not a security control. It is written for the people who have to judge a decision afterwards: an auditor, a data protection officer, a certifier. It records what was checked and what was decided; it does not prove that every AI call went through it (only routed calls are checked), and it does not decide whether a law applies to your system.

## The rule set and the rulebook

The rules in [`rules/`](rules) are the rule set ComplyEdge runs: one rule per legal provision, each with its citation and approval status; [`rules/README.md`](rules/README.md) maps the directories. What a decision record must contain and prove is a separate, open document: ADCR, the AI Decision Check Record, published at [complyedge.io/rulebook](https://complyedge.io/rulebook/) as version 0.1.0, in development, with its schemas, an offline verifier and test vectors. A record names the rule set that decided it by digest. ComplyEdge is ADCR's first implementation. No conformance class is claimed; the gaps are listed field by field in Annex C of the rulebook.

- **Rule IDs.** Every rule has a stable ID that names the provision: `rego-art5-1c-001` is AI Act Article 5(1)(c), first rule. Other forms cover Annex III points (`rego-art6-annex3-5b-001`), the Article 15(5) prompt-injection family (`rego-art15-ipi-001`), GPAI (`rego-gpai-53a-001`), GDPR (`rego-gdpr5-1c-001`) and SOX (`rego-sox-302-001`). The full scheme is in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md).
- **Citations.** Each rule's `citation` names the instrument and the provision at paragraph and point level, then the text of that provision, for example `Regulation (EU) 2024/1689, Article 5(1)(c): ...`. That string is what goes into the record when the rule fires.
- **Approval states.** Each rule header carries `Status: approved`, `review`, `pending re-approval`, or no status line yet. Only `approved` means a named person read the provision in full and signed off the rule. The status of every rule is published per rule; today all 75 of the 75 runtime rules are approved.
- **Bundle digest.** Every check response and every record carries `bundle_digest`, a SHA-256 over the rule files that were loaded when the decision was made. It changes whenever any rule changes, so a record names the exact rule set that decided it.

`rule_id` is the citation key: every rule carries its article reference in the rule set (`rego-art5-1c-001` → Article 5(1)(c)), and the full citation text ships with the rule under [`rules/`](rules).

`jurisdiction` is where the end user is, not where your company is based: the EU AI Act applies when an AI system's output is used in the EU, wherever the provider or deployer is established ([Art. 2(1)(c)](https://eur-lex.europa.eu/eli/reg/2024/1689)). Default: `EU`. On the hosted API's deterministic path, `EU` runs the EU AI Act rules, `US` and `US-*` run the SOX §302 disclosure rule, and every check runs prompt-injection detection. The other US rules (HIPAA, COPPA, TCPA, BIPA, CCPA, NYC LL144, ECPA) and the GDPR rules run offline in TrustLint, not on the hosted `/v1/check` path. The opt-in Layer 2 (`use_semantic_fallback=True`) adds two LLM judges: a prompt-injection classifier that judges by meaning against the same Article 15 categories and cites them, and a general LLM review. Neither runs the other rules.

## TrustLint, Offline Linter

No API key required. Scans text against the YAML rule set using regex patterns. Published as a standalone package, versioned independently of the SDK.

```bash
pip install trustlint

trustlint check --text "We use social credit scoring to evaluate applicants"
# → CRITICAL: EU_AI_ACT_ART5_SOCIAL_SCORING_001, Article 5(1)(c)
```

Exit codes: `0` = pass, `1` = violations found. Designed for CI/CD pipelines. Source: [`packages/trustlint/`](packages/trustlint).

## Rule IDs: two namespaces

ComplyEdge resolves the same regulations through two engines, each with its own rule-ID namespace:

- **Runtime API (OPA/Rego):** IDs like `rego-art5-1c-001`: returned by `compliance_check` and the `/v1/check` API. This is the audit trail your production system logs.
- **TrustLint (offline, YAML rule set):** IDs like `EU_AI_ACT_ART5_SOCIAL_SCORING_001`: emitted by the offline linter.

Both cite the same legal article and differ only in engine. Map between them via the article reference carried in every rule.

## What's In This Repo

```
sdks/python/          Python SDK (@compliance_check decorator, CLI)
  └ complyedge/mcp_server.py   MCP server (stdio): check_compliance, list_rules, scan_prompt
packages/trustlint/   Offline regex linter (TrustLint): no API key, for CI/CD
rules/regulations/    63 YAML rules (EU AI Act, GDPR, HIPAA, SOX, PCI DSS, and more)
rules/rego/           75 leaf OPA/Rego policies + 8 package aggregators
rules/schemas/        Rule validation schema
rules/scripts/        Schema validator (`validate_rules.py`)
examples/             Usage examples (decorators, OpenAI Agents)
scripts/benchmark/    Runtime benchmark (runner + prompt YAMLs + committed results)
tests/                Rule validation + acceptance tests
```

## Rules

63 YAML rules (EU, US, global and universal) + 75 deterministic leaf OPA/Rego policies (+ 8 package aggregators).

**What a decision from these policies establishes is not uniform, and we publish the split.** Every leaf decides by matching the evaluated text (no LLM on the hot path). For 32 of them the text *is* the regulated act (Article 5 prohibited practices, Article 15 prompt-injection resilience, personal data and secrets matched by format and checksum, one US disclosure control) so a block prevents the act and the citation on the decision is load-bearing. The other 43 fire on text *describing* a state the engine cannot verify: no text matcher can establish whether a technical file, a quality management system, a human-oversight assignment or a FRIA exists. Those are useful for triage; they are not a compliance finding, and their silence is not one either. On the hosted API any leaf that fires blocks the call and records it with its citation, whichever group it is in. Per-rule table: [`docs/rules-management/corpus-evidence-classification.md`](docs/rules-management/corpus-evidence-classification.md).

| Jurisdiction | Rules | Regulations |
|---|---|---|
| **EU** | 36 YAML | EU AI Act Articles 4–6, 9–10, 12–16, 26–27, 50, 53, GPAI + Art 15 IPI (hosted); GDPR (offline, TrustLint) |
| **US** | 15 YAML | SOX §302 (hosted, US checks); HIPAA, SOX §§404/802, COPPA, TCPA, BIPA, CCPA, NYC LL144, ECPA (offline, TrustLint) |
| **Global** | 1 YAML | PCI DSS |
| **Universal** | 11 YAML | PII detection, prompt injection (direct + indirect) |

Each rule specifies conditions, severity, detection scope, and remediation with legal citations. See the [rule schema](rules/schemas/rule-schema.json) for the format.

### Writing Custom Rules

```yaml
id: MY_CUSTOM_RULE_001
jurisdiction: EU
effective_date: "2025-02-02"
description: "Detect prohibited practice X under Article Y"
severity: critical
conditions:
  - type: regex
    value: "prohibited pattern"
source:
  regulation: "EU AI Act"
  article: "Article Y(1)(z)"
```

Validate: `cd rules && python scripts/validate_rules.py`

## Architecture

**Layer 1, Deterministic (hot path):** 75 leaf OPA/Rego policies (+ 8 package aggregators) evaluate every request, no LLM. The engine (OPA/Rego + TrustLint) evaluates in 4.87ms p99 in a local microbenchmark against the current 6-package bundle (`layer1_latency_latest.json`, best of 5 trials, 2026-08-04). End-to-end through the live API, the published 60-prompt run measured a p50 of 139ms and p95 of 2,519ms across the 39 OPA-decided prompts, with individual requests spanning 47ms to 10.7s (`runtime_benchmark_latest.json`, 2026-07-28). That run mixes cold and concurrent invocations against a Lambda-backed API, which is where the long tail comes from; we publish the whole run rather than a hand-picked warm figure. Opting into the Layer 2 LLM adds 2–5s on the long tail. Binary pass/block, legal citation when a rule fires. (TrustLint applies the same regex corpus offline for CI use.)

**Layer 2, Interpretive (synchronous, opt-in):** When called with `use_semantic_fallback=True`, two LLM judges run in parallel after the rules pass, and either can block: a prompt-injection classifier that judges by meaning against the Article 15 `prompt_security` categories (a block is `llm-art15-ipi-*`, carries the Article 15 citation, and must quote the injected text from the request) and a general LLM review. If either cannot answer, the request is denied. Off by default since v0.2.2. Adds 2–5s latency per request.

**ComplyEdge is compliance evidence, not a security control.** It is written for the auditor, the data protection officer and the certifier who have to judge an AI decision afterwards. Security products protect AI from bad actors; ComplyEdge records every decision with the rule and the law behind it, and blocks a request or answer only when a rule that covers the act itself fires. The record is kept outside your AI system, so it is evidence your system did not write about itself.

## Benchmark

A 60-prompt corpus runs against the live API. The runner, prompt YAMLs, and the latest result JSON are committed under [`scripts/benchmark/`](scripts/benchmark): inspect the results directly, or re-run with your own `COMPLYEDGE_API_KEY`.

**False positives, measured.** The false-positive battery is 1,185 texts that must be allowed: plain explanations of the law, policies, refusals, negations and realistic outputs that mention regulated topics without doing them. Each is checked under both the EU and the US jurisdiction, so one run is 2,370 checks, evaluated by `opa eval` over the same Rego packages the API reads. The latest run (2026-10-10) blocked 514 of 2,370 checks, a false-positive rate of 0.2169 on this battery, with the count per rule in [`scripts/benchmark/results/false_positive_measure_opa_latest.json`](scripts/benchmark/results/false_positive_measure_opa_latest.json). The battery runs in CI against a baseline that may only shrink: a new false positive fails the build.

**GPAI leaderboard.** The [GPAI provider leaderboard](scripts/benchmark/results/leaderboard.md) scores providers' published documentation against Articles 50(2), 51 to 53 and 55. Every row is marked `needs_review`: the scores are a reading of public documents, not a legal verdict, and none has been confirmed by the provider or anyone else. Method: [`scripts/benchmark/gpai_benchmark_methodology.md`](scripts/benchmark/gpai_benchmark_methodology.md).

## Contributing

We welcome rule contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

Every rule must include: article + paragraph citation, verifiable detection condition, and test cases.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md). Do not open a public issue for security reports.

## License

Apache License 2.0: see [LICENSE](LICENSE).

## Links

- **Website**: [complyedge.io](https://complyedge.io)
- **MCP server docs**: [sdks/python/README.md](sdks/python/README.md) · remote endpoint `https://mcp.complyedge.io/mcp`
- **Blog**: [complyedge.io/blog/](https://complyedge.io/blog/)
- **GPAI Compliance Benchmark**: [complyedge.io/blog/gpai-compliance-benchmark.html](https://complyedge.io/blog/gpai-compliance-benchmark.html)
- **Why OPA/Rego for EU AI Act**: [complyedge.io/blog/why-opa-rego-eu-ai-act.html](https://complyedge.io/blog/why-opa-rego-eu-ai-act.html)
- **PyPI**: [pypi.org/project/complyedge](https://pypi.org/project/complyedge/)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **Rule Schema**: [rules/schemas/rule-schema.json](rules/schemas/rule-schema.json)
