# Rego corpus: what each rule actually establishes

**Machine-readable source of truth:** [`corpus-evidence-classification.yaml`](corpus-evidence-classification.yaml). This page restates that file for a human reader; the YAML is authoritative and `tests/unit/test_corpus_evidence_classification.py` fails if the two disagree on any headline number.

## Why this document exists

Every leaf policy in the corpus **detects** by matching a regular expression against `input.text` (plus `input.jurisdiction`). **All 64 of 64.** One rule, `article5/biometric_categorisation.rego`, additionally reads inputs that can only ever *suppress* a match, the Article 5(1)(g) carve-outs, and never uses them to detect one. That follows from the architecture: no LLM runs on the hot path, so the deterministic layer can only reason about the text in front of it, and it is a hard limit on what a decision proves.

For some obligations that limit costs nothing: a request to socially score citizens *is* the prohibited practice, so blocking the text prevents the act. For others it is decisive: no text matcher can establish whether a quality management system, an Annex IV technical file, a human-oversight assignment or a FRIA exists. Stating which rule is which, in public, is cheaper than letting a reviewer discover it by opening one file.

## Totals

| | Leaves |
|---|---:|
| **content_inspecting**: the text is, or asks for, the regulated act | **21** |
| **assertion_matching**: the text describes a state the engine cannot verify | **43** |
| Total leaf policies | 64 |
| Package aggregators (no legal condition of their own) | 7 |

Broken down by why each rule lands where it does:

| Basis | Leaves |
|---|---:|
| `regulated_act_in_text`: the evaluated text is, or asks for, the regulated act | 21 |
| `absent_control_asserted`: fires on a phrase asserting a control is missing | 32 |
| `domain_of_use_described`: labels a described use case against an Annex III domain | 11 |

## By group

### `article5`: 8 leaves, all `content_inspecting`

The prohibited practice is the content. A request to score citizens socially, to scrape faces untargeted, or to exploit a protected vulnerability is the thing Article 5 forbids, so blocking the text prevents the act and the citation on the decision is load-bearing.

| Rule | Rule ID | Basis |
|---|---|---|
| `biometric_categorisation.rego` | `rego-art5-1g-001` | `regulated_act_in_text` |
| `emotion_recognition.rego` | `rego-art5-1f-001` | `regulated_act_in_text` |
| `facial_scraping.rego` | `rego-art5-1e-001` | `regulated_act_in_text` |
| `predictive_policing.rego` | `rego-art5-1d-001` | `regulated_act_in_text` |
| `realtime_biometric.rego` | `rego-art5-1h-001` | `regulated_act_in_text` |
| `social_scoring.rego` | `rego-art5-1c-001` | `regulated_act_in_text` |
| `subliminal_manipulation.rego` | `rego-art5-1a-001` | `regulated_act_in_text` |
| `vulnerability_exploitation.rego` | `rego-art5-1b-001` | `regulated_act_in_text` |

### `prompt_security`: 12 leaves, all `content_inspecting`

The attack is the text. "Ignore all previous instructions", a jailbreak persona, an exfiltration payload: the string itself is the conduct, so matching it is inspecting the act.

| Rule | Rule ID | Basis |
|---|---|---|
| `ai_addressed.rego` | `rego-art15-ipi-004` | `regulated_act_in_text` |
| `embedded_instruction.rego` | `rego-art15-ipi-003` | `regulated_act_in_text` |
| `indirect_embedded.rego` | `rego-art15-ipi-003` | `regulated_act_in_text` |
| `indirect_injection.rego` | `rego-art15-ipi-008` | `regulated_act_in_text` |
| `instruction_override.rego` | `rego-art15-ipi-009` | `regulated_act_in_text` |
| `markdown_exfil.rego` | `rego-art15-ipi-007` | `regulated_act_in_text` |
| `role_hijack.rego` | `rego-art15-ipi-001` | `regulated_act_in_text` |
| `safety_disable.rego` | `rego-art15-ipi-002` | `regulated_act_in_text` |
| `separator_hijack.rego` | `rego-art15-ipi-008` | `regulated_act_in_text` |
| `sysprompt_leak.rego` | `rego-art15-ipi-005` | `regulated_act_in_text` |
| `tool_hijack.rego` | `rego-art15-ipi-010` | `regulated_act_in_text` |
| `training_extract.rego` | `rego-art15-ipi-006` | `regulated_act_in_text` |

### `us_corpus`: 1 leaves, all `content_inspecting`

Forward-looking guidance and material non-public information are the disclosure. The text is the regulated act.

| Rule | Rule ID | Basis |
|---|---|---|
| `sox_material_disclosure.rego` | `rego-sox-302-001` | `regulated_act_in_text` |

### `article50`: 7 leaves, all `assertion_matching`

Every rule keys on a phrase asserting a disclosure is absent ("chatbot ... without disclosure"). It detects text DESCRIBING an undisclosed chatbot, not an undisclosed chatbot. Two rules also carry impersonation and synthetic-media patterns that ARE the act; they are classified by their weakest patterns and flagged mixed.

| Rule | Rule ID | Basis |
|---|---|---|
| `chatbot_disclosure.rego` **(mixed)** | `rego-art50-1-001` | `absent_control_asserted` |
| `deepfake_disclosure.rego` **(mixed)** | `rego-art50-4-001` | `absent_control_asserted` |
| `emotion_notification.rego` | `rego-art50-3-001` | `absent_control_asserted` |
| `emotion_permitted_context_notice.rego` | `rego-art50-3-002` | `absent_control_asserted` |
| `gpai_content_disclosure.rego` | `rego-art50-2-001` | `absent_control_asserted` |
| `public_interest_text.rego` | `rego-art50-4-002` | `absent_control_asserted` |
| `synthetic_media_watermark.rego` | `rego-art50-2-002` | `absent_control_asserted` |

### `article6`: 11 leaves, all `assertion_matching`

These label a described system against an Annex III domain: credit scoring, employment screening, migration. Useful for routing and triage. They do not establish that a deployed system is high-risk, and firing is not a finding of non-compliance.

| Rule | Rule ID | Basis |
|---|---|---|
| `annex3_5b_creditworthiness.rego` | `rego-art6-annex3-5b-001` | `domain_of_use_described` |
| `annex3_5c_insurance.rego` | `rego-art6-annex3-5c-001` | `domain_of_use_described` |
| `art6_3_procedural_derogation.rego` | `rego-art6-3-001` | `domain_of_use_described` |
| `biometric_identification.rego` | `rego-art6-annex3-1-001` | `domain_of_use_described` |
| `critical_infrastructure.rego` | `rego-art6-annex3-2-001` | `domain_of_use_described` |
| `education_vocational.rego` | `rego-art6-annex3-3-001` | `domain_of_use_described` |
| `employment_workers.rego` | `rego-art6-annex3-4-001` | `domain_of_use_described` |
| `essential_services.rego` | `rego-art6-annex3-5-001` | `domain_of_use_described` |
| `justice_democracy.rego` | `rego-art6-annex3-8-001` | `domain_of_use_described` |
| `law_enforcement.rego` | `rego-art6-annex3-6-001` | `domain_of_use_described` |
| `migration_asylum.rego` | `rego-art6-annex3-7-001` | `domain_of_use_described` |

### `gpai`: 12 leaves, all `assertion_matching`

Chapter V duties are organisational: a training-data summary, a copyright policy, incident reporting, model evaluation. The rules key on assertions that these are absent, which no text matcher can verify.

| Rule | Rule ID | Basis |
|---|---|---|
| `copyright_transparency.rego` | `rego-gpai-53c-001` | `absent_control_asserted` |
| `cybersecurity_gpai.rego` | `rego-art55-1d-001` | `absent_control_asserted` |
| `downstream_obligations.rego` | `rego-gpai-53b-001` | `absent_control_asserted` |
| `incident_reporting.rego` | `rego-art55-1c-001` | `absent_control_asserted` |
| `model_classification.rego` | `rego-gpai-51-001` | `absent_control_asserted` |
| `model_evaluation.rego` | `rego-art55-1a-001` | `absent_control_asserted` |
| `open_source_exemption.rego` | `rego-gpai-53-2-001` | `absent_control_asserted` |
| `risk_mitigation.rego` | `rego-art55-1b-001` | `absent_control_asserted` |
| `sr_designation.rego` | `rego-art52-001` | `absent_control_asserted` |
| `systemic_risk.rego` | `rego-gpai-55-001` | `absent_control_asserted` |
| `technical_documentation.rego` | `rego-gpai-53a-001` | `absent_control_asserted` |
| `training_summary.rego` | `rego-art53-1d-001` | `absent_control_asserted` |

### `highrisk`: 13 leaves, all `assertion_matching`

Articles 4, 9-16, 26 and 27 require documents, processes and assignments to EXIST. Every rule fires on a phrase admitting one does not. `art11_technical_documentation.rego` matches "high-risk AI system without technical documentation": it cannot check whether an Annex IV file exists.

| Rule | Rule ID | Basis |
|---|---|---|
| `art10_data_governance.rego` | `rego-art10-001` | `absent_control_asserted` |
| `art11_technical_documentation.rego` | `rego-art11-001` | `absent_control_asserted` |
| `art12_record_keeping.rego` | `rego-art12-001` | `absent_control_asserted` |
| `art13_transparency.rego` | `rego-art13-001` | `absent_control_asserted` |
| `art14_human_oversight.rego` | `rego-art14-001` | `absent_control_asserted` |
| `art15_accuracy.rego` | `rego-art15-1-001` | `absent_control_asserted` |
| `art15_cybersecurity.rego` | `rego-art15-5-001` | `absent_control_asserted` |
| `art15_robustness.rego` | `rego-art15-4-001` | `absent_control_asserted` |
| `art16_provider_obligations.rego` | `rego-art16-001` | `absent_control_asserted` |
| `art26_deployer_obligations.rego` | `rego-art26-001` | `absent_control_asserted` |
| `art27_fria.rego` | `rego-art27-001` | `absent_control_asserted` |
| `art4_ai_literacy.rego` | `rego-art4-001` | `absent_control_asserted` |
| `art9_risk_management.rego` | `rego-art9-001` | `absent_control_asserted` |

## What this means for a claim

Safe to say: the corpus deterministically inspects **Article 5 prohibited practices, Article 15 prompt-injection resilience, and one US disclosure control**: 21 policies where the evaluated text is the regulated conduct, each carrying the operative article text and emitting a cited, hash-chained record.

Not safe to say: that the corpus "covers the high-risk requirements", or that a rule count is evidence of coverage. The Article 4/9-16/26/27, Chapter V and Annex III policies fire on descriptions. They are useful for triage and for catching an operator who states an absent control in writing. They do not establish the underlying fact, and their silence is not a compliance finding.

## Reproduce
```bash
find rules/rego/complyedge -name '*.rego' ! -name '*_test.rego' \
  | xargs grep -L 'Aggregator carve-out' | wc -l     # -> 64 leaves
find rules/rego/complyedge -name '*.rego' ! -name '*_test.rego' \
  | xargs grep -l 'Aggregator carve-out' | wc -l     # ->  7 aggregators
```

Drift is enforced by `tests/unit/test_corpus_evidence_classification.py`.
