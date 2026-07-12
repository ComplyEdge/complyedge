# `prompt_security/` — Indirect Prompt Injection (IPI) detection rules

This directory holds the YAML rule corpus for **prompt-security / IPI detection**, under `rules/regulations/universal/` because the rules are jurisdiction-independent: prompt injection is an Article-15 (robustness) concern under the EU AI Act AND falls under generic adversarial-input security obligations in every other jurisdiction CE serves.

## Methodology

The conformity-assessment methodology, the four IPI sub-categories CE tests, and the Layer-1-vs-Layer-2 division of responsibility are documented in **[`docs/security-compliance/ipi-conformity-assessment.md`](../../../../docs/security-compliance/ipi-conformity-assessment.md)**. Read that before authoring a new rule in this directory.

## Naming convention

Rule files in this directory follow the pattern:

```
{subcategory}_{specific_attack_shape}.yaml
```

Where `{subcategory}` is one of:

| Slug | Sub-category (per methodology §2) |
|---|---|
| `direct_injection` | 2.1 Direct prompt injection (instruction override, role hijack, system-prompt impersonation) |
| `indirect_injection` | 2.2 Indirect prompt injection (separator hijack, hidden instructions in retrieved content, tool-output poisoning) |
| `exfiltration` | 2.3 Data exfiltration via injection (system-prompt leak, training-data extraction) |
| `tool_hijacking` | 2.4 Tool / function-call hijacking |

## Rules currently in this directory

| File | Sub-category | Coverage | Tier |
|---|---|---|---|
| `direct_injection_instruction_override.yaml` | 2.1 | Explicit "ignore previous instructions" / "disregard the above" phrasing | community |
| `indirect_injection_separator_hijack.yaml` | 2.2 | Separator-hijack patterns: `===END_USER_INPUT===\nNEW INSTRUCTIONS:` and variants | community |

## Coverage roadmap

The methodology's definition of done calls for ≥10 deterministic IPI rules. The two rules above are the **starter set** that exercises the category structure end-to-end. The remaining 8+ rules are tracked for a follow-up release; the prioritised sequence is in §5 of the methodology doc.

## Authoring guidance

- **Conservative regex first.** A false positive in this category fires on legitimate user content that mentions injection concepts (security researchers, prompt-engineering tutorials, internal red-team communications). Tighten regex with `\b` boundaries, require multi-token phrases, prefer semantic LLM confirmation for borderline cases.
- **Confidence-weighted severity.** A high-confidence direct injection (`severity: critical`, `action: block`) is reasonable; a probabilistic indirect-injection signal should fall back to `severity: medium`, `action: warn`, `allow_override: true` so legitimate retrieved content that happens to contain the pattern isn't auto-blocked.
- **Pair Layer 1 regex with Layer 2 LLM check.** Every IPI rule should declare BOTH a `regex` condition (deterministic catch) AND a `semantic` condition (LLM-confirmation prompt). The Layer 1 regex is the fast-path filter; the Layer 2 LLM is the false-positive guard.
- **Cite the source corpus.** When a rule's pattern is derived from OWASP LLM01, the Google IPI Benchmark, or a public AI-lab disclosure, name the source in the `source.url` / `source.citation` field. This is the diligence trail.

## Out-of-scope for this directory

Rules covering *legal* prohibitions on AI use (Article 5 prohibited practices, transparency obligations) live elsewhere — see `rules/regulations/eu/` for those. This directory is for **adversarial-input detection** specifically; the EU AI Act compliance evidence lives in the methodology doc, not in the rule corpus tags.
