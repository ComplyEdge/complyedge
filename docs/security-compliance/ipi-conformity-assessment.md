# Prompt injection under Article 15(5): robustness methodology

**Audience:** auditors and assessors reading ComplyEdge records; deployers who use them as part of their Article 15 evidence; rule authors.

**Status:** Methodology v2.0 (2026-10-14). Replaces v1.1 (2026-07-05), which described a roadmap that has since shipped.

**What this document is.** How the ComplyEdge prompt-injection rules are built, what each one checks, how they are tested, and what a record from them shows. **What it is not.** It is not a conformity assessment and does not produce one. ComplyEdge is not a notified body or a certification body; it does not certify systems or issue conformity statements. A record from these rules is one input to a deployer's or provider's own Article 15 evidence, not a finding that a system is robust.

---

## 1. Legal basis

Article 15(5) of Regulation (EU) 2024/1689 requires high-risk AI systems to be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. The technical solutions it lists include measures to prevent, detect, respond to, resolve and control for inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion) and confidentiality attacks.

**Our position, stated as ours:** prompt injection, direct or indirect, is an instance of those inputs and attacks for an LLM-based system, so detecting it at the point where text enters or leaves the system is a measure Article 15(5) contemplates. No regulator, standards body or assessor has endorsed this reading or these rules; OWASP lists prompt injection as the first risk in its LLM Top 10 (LLM01), which is where most of the attack shapes below come from.

**When it applies.** Article 15 binds high-risk AI systems. For Annex III systems that is from 2 December 2027, under Regulation (EU) 2026/1744. The rules below run on every check in every jurisdiction anyway, because prompt injection does not depend on where the user is.

---

## 2. The four sub-categories and the rules that cover them

The rules live in two places with the same content: the YAML corpus (`rules/regulations/universal/prompt_security/`, 10 rules, read offline by TrustLint and the MCP server) and the Rego leaves (`rules/rego/complyedge/prompt_security/`, 12 leaves, evaluated on every `/v1/check`). Every Rego leaf has an ID of the form `rego-art15-ipi-NNN`. Ten of the 12 leaves cite Article 15(5); the two indirect-injection leaves cite Article 15 without the paragraph and are being aligned.

### 2.1 Direct prompt injection

The input itself tries to override the system prompt or the assistant's role.

| Rule ID | Rego leaf | What it matches |
|---|---|---|
| `rego-art15-ipi-009` | `instruction_override.rego` | "Ignore the previous instructions" and its variants |
| `rego-art15-ipi-001` | `role_hijack.rego` | "You are now ..." persona replacement |
| `rego-art15-ipi-002` | `safety_disable.rego` | Requests to switch off the system's safety instructions |

### 2.2 Indirect prompt injection

Instructions placed in content the model reads (a document, an email, a web page, a tool result) that the model then follows as if the user had asked.

| Rule ID | Rego leaf | What it matches |
|---|---|---|
| `rego-art15-ipi-003` | `embedded_instruction.rego`, `indirect_embedded.rego` | An instruction to the AI hidden inside content it processes |
| `rego-art15-ipi-004` | `ai_addressed.rego` | Text addressed directly to "the assistant" or "the AI" inside data |
| `rego-art15-ipi-008` | `indirect_injection.rego`, `separator_hijack.rego` | Injected text labelled as new instructions, and fake delimiters that end the "user input" region and start a fake instruction region |

Two of these IDs cover two leaves each: the second leaf extends the same technique to another shape, and both cite the same provision.

### 2.3 Data exfiltration through injection

The payload asks the model to leak something protected rather than to do something forbidden.

| Rule ID | Rego leaf | What it matches |
|---|---|---|
| `rego-art15-ipi-005` | `sysprompt_leak.rego` | Requests to repeat the system prompt or initial instructions |
| `rego-art15-ipi-006` | `training_extract.rego` | Training-data extraction phrasings |
| `rego-art15-ipi-007` | `markdown_exfil.rego` | Markdown image links that carry data out in the URL |

### 2.4 Tool and function-call hijacking

The target is the model's tool use: making it call a tool with arguments chosen by whoever wrote the content.

| Rule ID | Rego leaf | What it matches |
|---|---|---|
| `rego-art15-ipi-010` | `tool_hijack.rego` | Instructions in content that name a tool or function to call |

---

## 3. How a decision is made and recorded

**Layer 1, phrase rules.** The Rego leaves match the text of the request or the answer. The leaf does not call a model. When a leaf fires, the request or answer is blocked and the record carries the rule ID, the Article 15(5) citation, the time, a keyed hash of the text and an `event_id`. The text itself is not stored.

**Injection check, by meaning (paid plans).** After the phrase rules pass, on a Developer or Enterprise plan, when the month's model budget covers it, the injection meaning check judges whether the text tries to instruct an AI system, against the same Article 15(5) categories. It runs even when the wider review is off. If that budget is used up, the phrase rules decide. A block from it has an ID of the form `llm-art15-ipi-NNN`, so the record says a model decided, not a rule, and the block must quote the injected instruction from the text. An answer whose quote is not in the text is rejected. If that check cannot answer, the request is denied.

**What the record lets a reviewer check.** Which rule or classifier decided, under which provision, when, and, using the `event_id` and the deployer's own copy of the text, which text it was about (`POST /v1/audit/verify`; see [complyedge.io/docs/audit-reconciliation.html](https://complyedge.io/docs/audit-reconciliation.html)).

---

## 4. How the rules are tested

- **Rego unit tests** for every leaf, run with `opa test rules/rego/ -v`.
- **Must-block battery.** `scripts/benchmark/true_positive_battery/prompt_security.yaml`: inputs that must block, each on its named rule. A narrowed pattern that stops catching one fails CI.
- **False-positive battery.** `scripts/benchmark/false_positive_battery/`: texts that must pass, including security writing *about* prompt injection (guides, tickets, papers), which is the classic false positive for these rules. The latest full run and its per-rule counts are in `scripts/benchmark/results/false_positive_measure_opa_latest.json`. The battery runs in CI against a baseline that may only shrink.

---

## 5. Limits a reviewer should know

- **Layer 1 matches English phrasings.** Paraphrases and other languages can pass the rules. On a paid plan, after a clean pass, the injection meaning check judges those by meaning and can block when the month's model budget covers it. If that budget is used up, the phrase rules decide. The wider legal review stays off unless turned on. A deterministic block is reproducible; a pass is not proof the text was clean.
- **Only routed text is checked.** ComplyEdge sees what the integration sends to `/v1/check`. It does not see calls that bypass it, and with the SDK's default `fail_mode="open"` an outage lets traffic through unchecked and unrecorded.
- **No tool-trajectory analysis.** ComplyEdge sees text at the API boundary, not the sequence of tool calls an agent makes.
- **A rule match is about one text, not the system.** It does not establish that the system as a whole meets Article 15(5). That needs the provider's own testing (red-teaming, model evaluation) as well.

---

## 6. Sources

- Regulation (EU) 2024/1689, Article 15: <https://eur-lex.europa.eu/eli/reg/2024/1689>
- OWASP Top 10 for LLM Applications, LLM01 Prompt Injection: <https://owasp.org/www-project-top-10-for-large-language-model-applications/>

---

## 7. Cross-references

- [`rules/README.md`](../../rules/README.md): directory map, rule ID forms and approval states.
- [`rules/RULE_STANDARD.md`](../../rules/RULE_STANDARD.md): how a Rego rule is written, tested and approved.
- [`rules/schemas/rule-schema.json`](../../rules/schemas/rule-schema.json): the schema every YAML rule under `rules/regulations/` is validated against.
- [`rules/regulations/universal/prompt_security/README.md`](../../rules/regulations/universal/prompt_security/README.md): the YAML rules in this category.
