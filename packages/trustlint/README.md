# TrustLint

[![npm version](https://img.shields.io/npm/v/trustlint)](https://www.npmjs.com/package/trustlint)
[![npm downloads](https://img.shields.io/npm/dw/trustlint)](https://www.npmjs.com/package/trustlint)
[![license](https://img.shields.io/npm/l/trustlint)](https://github.com/ComplyEdge/complyedge/blob/main/LICENSE)

**Offline Node.js compliance linter for AI agents** — scans text against the bundled ComplyEdge rule corpus using Tier 1 regex patterns. No API key required.

Catches EU AI Act, SOX, HIPAA, GDPR, COPPA, and PCI DSS violations before they reach production.

## Hosted API vs. Offline Linter

TrustLint runs locally and needs no API key. For runtime policy enforcement and
an application-facing evidence trail, use the hosted
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
the same bundled rule corpus.

Node.js:

```bash
npm install trustlint
```

Python:

```bash
pip install trustlint
```

Both bundle the rule corpus, so neither needs a local `rules/` directory.

## Limitations (Node vs. Python)

- The npm and PyPI packages share a rule corpus but not the same engine. Python
  TrustLint evaluates temporal and effective-date rule state; the Node engine
  runs Tier 1 regex and hybrid Tier-1 patterns only. Semantic-only YAML
  conditions are skipped.
- In the current npm release, 52 Tier-1 rules load from 64 bundled YAML files.
  A version number is not a parity claim with PyPI TrustLint.

## Quick Start

```bash
# Check text for compliance violations
trustlint check --text "We expect revenue to increase by 25% next quarter"

# Check a file
trustlint check prompt.txt

# Pipe from stdin
echo "Deploy social credit score for citizens" | trustlint check

# Filter by jurisdiction
trustlint check --text "social credit score" --jurisdiction EU

# Verbose output (citations + remediation)
trustlint check --text "earnings forecast" -v
```

## Commands

### `trustlint check`

Scan text for compliance violations against the loaded rule corpus.

```bash
trustlint check --text "your AI prompt here"    # Check a string
trustlint check myfile.py                        # Check a file
trustlint check --text "text" -j EU             # Filter to EU rules only
trustlint check --text "text" -v                 # Verbose: show citations
```

**Exit codes:**
- `0` — No critical/high violations (CI pass)
- `1` — Critical or high severity violations found (CI fail)
- `2` — Input error (missing file, no rules loaded)

### `trustlint rules list`

Show all loaded compliance rules with severity and jurisdiction.

```bash
trustlint rules list              # All rules
trustlint rules list -j US        # US rules only
```

### `trustlint init`

Create a `.trustlint.yaml` configuration file in the current directory.

```bash
trustlint init           # Create config
trustlint init --force   # Overwrite existing
```

## Example Output

```
TrustLint Report
────────────────────────────────────────────────────────────

[CRITICAL] SOX_HYBRID_MATERIAL_DISCLOSURE_001
  Hybrid SOX Material Information Disclosure Prevention
  Jurisdiction: US | Matched: Forward-looking statements requiring analysis

────────────────────────────────────────────────────────────
1 critical/high, 0 medium/low (12 rules evaluated)
```

## How It Works

TrustLint loads YAML rule files from the ComplyEdge rule corpus (`rules/regulations/`). Each rule contains regex patterns for Tier 1 (fast, deterministic) detection. The engine:

1. Loads all `.yaml` rule files from the rules directory
2. Extracts `regex` conditions and `hybrid_detection.tier1_config.risk_flag_patterns`
3. Matches patterns against the input text
4. Reports violations with rule ID, severity, jurisdiction, and citation

**No API calls are made in offline mode.** For deeper Tier 2 LLM analysis, set the `COMPLYEDGE_API_KEY` environment variable (requires a ComplyEdge account).

## CI/CD Integration

### GitHub Actions

```yaml
- name: Compliance check
  run: |
    pip install trustlint
    trustlint check --text "${{ github.event.pull_request.body }}"
```

### Pre-commit hook

```bash
#!/bin/sh
trustlint check "$1" || exit 1
```

## Rules Coverage

| Jurisdiction | Regulations | Examples |
|---|---|---|
| **EU** | EU AI Act Article 5 | Social scoring, subliminal manipulation, biometric categorisation |
| **US** | SOX, HIPAA, COPPA, TCPA | Material disclosure, PHI protection, child data |
| **Global** | PCI DSS | Payment card data detection |

## Configuration

Create `.trustlint.yaml` with `trustlint init`:

```yaml
# Rules directory (default: auto-detect)
# rules_dir: ./rules/regulations

# Default jurisdiction filter
# jurisdiction: EU

# Severity threshold
# severity_threshold: medium
```

## Development

```bash
# Install in development mode
pip install -e packages/trustlint/

# Run tests
python -m pytest tests/unit/trustlint/ -v
```

## License

Apache-2.0 — [ComplyEdge](https://complyedge.io)
