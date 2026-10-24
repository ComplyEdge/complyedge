# `prompt_security/`: prompt-injection rules under Article 15(5)

This directory holds the YAML rules for detecting prompt injection, direct and indirect. They sit under `rules/regulations/universal/` because they run in every jurisdiction: whether text tries to instruct an AI system does not depend on where the user is. We map them to Article 15(5) of the EU AI Act, which requires high-risk AI systems to be resilient against attempts by unauthorised third parties to alter their use, outputs or performance. That mapping is our reading, not a regulator's: the methodology below says why, and what it does not establish.

The same techniques run on the hosted `/v1/check` path as 12 Rego leaves in [`rules/rego/complyedge/prompt_security/`](../../../rego/complyedge/prompt_security/), with IDs `rego-art15-ipi-001` to `rego-art15-ipi-010`.

## Methodology

What each rule checks, how a decision is recorded, how the rules are tested and what they do not establish: **[`docs/security-compliance/ipi-conformity-assessment.md`](../../../../docs/security-compliance/ipi-conformity-assessment.md)**. Read it before authoring a rule here.

## Rules in this directory (10)

| File | Sub-category (methodology §2) |
|---|---|
| `direct_injection_instruction_override.yaml` | 2.1 Direct: "ignore the previous instructions" and variants |
| `direct_injection_role_hijack.yaml` | 2.1 Direct: persona replacement |
| `direct_injection_safety_disable.yaml` | 2.1 Direct: switching off safety instructions |
| `indirect_injection_embedded_instruction.yaml` | 2.2 Indirect: an instruction hidden in content the AI processes |
| `indirect_injection_ai_addressed_directive.yaml` | 2.2 Indirect: text addressed to "the assistant" inside data |
| `indirect_injection_separator_hijack.yaml` | 2.2 Indirect: fake delimiters that start a fake instruction region |
| `exfil_system_prompt_leak.yaml` | 2.3 Exfiltration: repeat the system prompt |
| `exfil_training_data_extraction.yaml` | 2.3 Exfiltration: training-data extraction |
| `exfil_markdown_image_channel.yaml` | 2.3 Exfiltration: data carried out in a Markdown image URL |
| `tool_call_hijack.yaml` | 2.4 Tool and function-call hijacking |

## Naming convention

```
{subcategory}_{specific_shape}.yaml
```

with `{subcategory}` one of `direct_injection`, `indirect_injection`, `exfil`, `tool_call`.

## Authoring guidance

- **Conservative patterns first.** The classic false positive here is text *about* prompt injection: security guides, tutorials, tickets, papers. Use `\b` boundaries and multi-token phrases, and add a false-positive battery item for every shape you tighten against.
- **Every new pattern gets a must-block item** in `scripts/benchmark/true_positive_battery/prompt_security.yaml`, so a later change cannot quietly stop catching it.
- **Cite the source of the attack shape.** When a pattern comes from OWASP LLM01 or another public write-up, name it in the rule's `source` fields.

## Out of scope for this directory

Rules on legal prohibitions and duties (Article 5, Article 50, high-risk obligations, GPAI) live in `rules/regulations/eu/`.
