# TrustLint

[![npm version](https://img.shields.io/npm/v/trustlint)](https://www.npmjs.com/package/trustlint)
[![npm downloads](https://img.shields.io/npm/dw/trustlint)](https://www.npmjs.com/package/trustlint)
[![license](https://img.shields.io/npm/l/trustlint)](https://github.com/ComplyEdge/complyedge/blob/main/LICENSE)

**Offline Node.js compliance linter for AI agents**: scans text against its bundled TrustLint rule set using Tier 1 regex patterns. No API key required.

Flags text that matches EU AI Act, SOX, HIPAA, GDPR, COPPA and PCI DSS rules before it ships.

## Hosted API vs. Offline Linter

`trustlint check` and `trustlint rules list` run locally, need no API key and record
nothing. `trustlint scan` with `COMPLYEDGE_API_KEY` sends the text to the hosted check
(`ce_eu_` keys to eu.api.complyedge.io, `ce_` keys to api.complyedge.io), which writes
an audit record. For the hosted
check and its audit record (for every decision a timestamp, a keyed hash of the
text and an `event_id`, plus the rule IDs and citations when a rule fires; never
the text itself), use the
[ComplyEdge TypeScript SDK](https://www.npmjs.com/package/@complyedge/sdk) or the
[ComplyEdge Python SDK](https://pypi.org/project/complyedge/).

- [ComplyEdge TypeScript SDK](https://www.npmjs.com/package/@complyedge/sdk)
- [ComplyEdge MCP server](https://www.npmjs.com/package/@complyedge/mcp)
- [ComplyEdge on PyPI](https://pypi.org/project/complyedge/)
- [TrustLint on PyPI](https://pypi.org/project/trustlint/)
- [Documentation](https://complyedge.io/docs)
- [Trust portal](https://trust.complyedge.io)

## Installation

This is the npm package README. PyPI uses its own
[Python-first long description](PYPI_README.md), while both distributions use
the same bundled rule set.

Node.js:

```bash
npm install trustlint
```

Python:

```bash
pip install trustlint
```

Both bundle the rule set, so neither needs a local `rules/` directory.

## Limitations (Node vs. Python)

- The npm and PyPI packages share a rule set but not the same engine. Python
  TrustLint applies a rule's `effective_window` and `conditional_on` state (the
  sanctions transition rules); it does not read `effective_date`, and the Node
  engine reads none of the three. Both engines run only `regex` conditions and
  the Tier 1 patterns of `hybrid_detection` conditions. A `semantic` condition
  in a YAML rule is not run by either engine.
- The npm package bundles the 63 YAML rules of the TrustLint rule set, and the
  Node engine loads all 63; inside them, only the Tier-1 conditions run.
  A version number is not a parity claim with PyPI TrustLint.

## Quick Start

```bash
# Check text for compliance violations
trustlint check --text "We expect revenue to increase by 25% next quarter"

# Check a file
trustlint check prompt.txt

# Pipe from stdin
echo "Deploy social credit score for citizens" | trustlint check

# Rules for an end user in the EU (EU and GLOBAL rules; US includes US-CA and US-NY)
trustlint check --text "social credit score" --jurisdiction EU

# Text a user sends: rules scoped to AI output do not run
trustlint check --text "I am 9 years old" --direction input

# Verbose output (citations + remediation)
trustlint check --text "We expect revenue to increase by 25% next quarter" -v
```

## Commands

### `trustlint check`

Scan text for compliance violations against the loaded rule set.

```bash
trustlint check --text "your AI prompt here"    # Check a string
trustlint check myfile.py                        # Check a file
trustlint check --text "text" -j EU             # Filter to EU rules only
trustlint check --text "text" -v                 # Verbose: show citations
```

**Exit codes:**
- `0`: no critical/high violations (CI pass)
- `1`: critical or high severity violations found (CI fail)
- `2`: input error (missing file, no rules loaded)

### `trustlint rules list`

Show all loaded compliance rules with severity and jurisdiction.

```bash
trustlint rules list              # All rules
trustlint rules list -j US        # US rules only
```

## Example Output

```
TrustLint Report
────────────────────────────────────────────────────────────

[CRITICAL] SOX_HYBRID_MATERIAL_DISCLOSURE_001
  Hybrid SOX Material Information Disclosure Prevention
  Jurisdiction: US | Matched: Forward-looking statements requiring analysis

────────────────────────────────────────────────────────────
1 critical/high, 0 medium/low (63 rules evaluated)
```

## How It Works

TrustLint loads its YAML rule files (bundled in the package; `rules/regulations/` in this repo). Each rule contains regex patterns for Tier 1 (fast, deterministic) detection. The engine:

1. Loads all `.yaml` rule files from the rules directory
2. Extracts `regex` conditions and `hybrid_detection.tier1_config.risk_flag_patterns`
3. Matches patterns against the input text
4. Reports violations with rule ID, severity, jurisdiction, and citation

**`check` and `rules list` make no API calls.** `trustlint scan` with an API key sends the text to the hosted check, which writes an audit record; so does the SDK (`@complyedge/sdk` or `complyedge` on PyPI).

## CI/CD Integration

### GitHub Actions

Use the TrustLint action:

```yaml
- uses: complyedge/trustlint-action@v1
```

Or run the npm CLI directly:

```yaml
- name: Compliance check
  env:
    PR_BODY: ${{ github.event.pull_request.body }}  # untrusted input: pass via env, never inline in run
  run: npx -y trustlint check --text "$PR_BODY"
```

### Pre-commit hook

Git runs the hook with no arguments, so check the staged files:

```bash
#!/bin/sh
# .git/hooks/pre-commit
git diff --cached --name-only --diff-filter=ACM | while read -r f; do
  trustlint check "$f" || exit 1
done || exit 1
```

## Rules Coverage

| Jurisdiction | Regulations | Examples |
|---|---|---|
| **EU** | EU AI Act: Article 5 prohibited practices, Article 50 transparency, Article 6 and Annex III high-risk, Articles 4, 9, 10, 12 to 16, 26 and 27, GPAI (Articles 51 to 55); GDPR | Social scoring, chatbot disclosure, missing human oversight, GPAI technical documentation, data minimisation |
| **US** | SOX, HIPAA, COPPA, TCPA, BIPA, CCPA, NYC LL144, ECPA, OFAC sanctions | Material disclosure, PHI protection, child data, biometric consent |
| **Global** | PCI DSS | Payment card data detection |
| **Universal** | PII detection; prompt injection (Article 15(5)) | Personal data in prompts, instruction override, system-prompt leak |

## Rules directory

TrustLint reads, in order: `--rules-dir`, a `rules/regulations` folder in the current
directory or above it, then the bundled rules. Update the rules by upgrading the
package (`npm install trustlint@latest`).

## Development

```bash
cd packages/trustlint
npm install
npm run build   # bundles the rule set from rules/regulations/
npm test
```

## License

Apache-2.0, [ComplyEdge](https://complyedge.io)
