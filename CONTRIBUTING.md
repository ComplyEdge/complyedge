# Contributing to ComplyEdge

We welcome contributions — especially new compliance rules.

## Writing a Rule

Rules are YAML files in `rules/regulations/`, organized by jurisdiction (`eu/`, `us/`, `global/`, `universal/`).

### Required Fields

Every rule **must** include:

1. **Legal citation** — article + paragraph + sub-paragraph (e.g., `Article 5(1)(c)`)
2. **Verifiable detection condition** — regex, semantic prompt, or input sensitivity pattern
3. **Source URL** — link to the official regulation text
4. **Remediation message** — what the user sees when the rule fires

### Rule Format

```yaml
id: EU_AI_ACT_ART5_EXAMPLE_001
jurisdiction: EU
effective_date: '2025-02-02'
description: One-line description of what this rule enforces
detection_scope: all          # user_input | ai_output | all
conditions:
- type: regex                 # regex | semantic | input_sensitivity | metadata | multi_pattern_risk
  value: (pattern_to_match)
  flags: i
severity: critical            # critical | high | medium | low
category: prohibited_practice
source:
  regulation: EU AI Act
  article: Article 5(1)(x)
  url: https://eur-lex.europa.eu/eli/reg/2024/1689/oj
  citation: Full text of the relevant clause
remediation:
  action: block
  timing: proactive
  message: What the user sees when this rule fires
  suggestion: How to fix the violation
version: 1.0.0
tags:
- eu-ai-act
- article-5
```

See `rules/schemas/rule-schema.json` for the full schema.

### Quality Standard

- **20 deep rules > 100 shallow checks.** Every rule must cite the exact legal clause it enforces.
- Regex patterns must have a clear false-positive strategy.
- Semantic prompts must be specific enough to avoid over-triggering.
- Every rule must be testable — if you can't write a test case, rethink the condition.

## Running Tests

```bash
# Validate all rules against the schema
pip install pyyaml jsonschema pytest
pytest tests/unit/ -v
```

## Submitting a Pull Request

1. Fork the repository
2. Create your rule in the appropriate `rules/regulations/<jurisdiction>/` directory
3. Run `pytest tests/unit/ -v` to validate your rule against the schema
4. Submit a PR with:
   - The rule YAML file
   - A brief description of the regulation it enforces
   - The legal citation source

## Code of Conduct

Be respectful. Focus on improving compliance coverage. Regulatory accuracy matters more than rule quantity.
