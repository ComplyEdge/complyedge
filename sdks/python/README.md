# ComplyEdge Python SDK

Runtime compliance engine for EU AI Act. Open source. Deterministic.

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

## MCP Server — Use ComplyEdge as an AI Agent Tool

ComplyEdge runs as an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server,
giving any MCP-compatible agent (Claude, Cursor, etc.) compliance checking with zero integration code.

```bash
pip install complyedge[mcp]
```

Add to your MCP client config (e.g. `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "complyedge": {
      "command": "python",
      "args": ["-m", "complyedge.mcp_server"]
    }
  }
}
```

**Exposed tools:**

| Tool | Description |
|------|-------------|
| `check_compliance` | Check text against regulation rules. Returns violations or PASS. |
| `list_rules` | List available rules, filterable by jurisdiction. |
| `scan_prompt` | Pre-generation compliance check on prompts. |

The MCP server uses the same engine as the REST API — deterministic OPA/Rego on the hot path.

## Documentation

See the [ComplyEdge Documentation](https://docs.complyedge.io) for complete guides.
