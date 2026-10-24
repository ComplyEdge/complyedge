# The rule corpus

This directory holds the rules ComplyEdge checks AI inputs and outputs against. It is the machine-readable side of the open rulebook: every rule has a stable ID, and every ID resolves to the legal provision it implements and the citation that goes into the record.

The rulebook itself (the versioned document, its schema, the rule index and its changelog) is published at [complyedge.io/rulebook](https://complyedge.io/rulebook/). Each rule also has its own page at `https://complyedge.io/rulebook/rules/<rule_id>`, for example [`/rulebook/rules/rego-art5-1c-001`](https://complyedge.io/rulebook/rules/rego-art5-1c-001). How the IDs and citations are written is set out in [`RULE_STANDARD.md`](RULE_STANDARD.md).

## Directory map

```
rules/
  rego/complyedge/        75 leaf OPA/Rego policies + 8 package aggregators (the runtime rules)
    article5/             8 leaves   Article 5 prohibited practices
    article50/            7 leaves   Article 50 transparency
    article6/             11 leaves  Article 6 and Annex III high-risk classification
    data_protection/      11 leaves  GDPR: personal data and secrets in the text
    gpai/                 12 leaves  General-purpose AI model obligations (Articles 51 to 55)
    highrisk/             13 leaves  Articles 4, 9 to 16, 26, 27
    prompt_security/      12 leaves  Article 15(5) resilience against prompt injection
    us_corpus/            1 leaf     Regulation FD disclosure
    test/                 Rego tests (opa test rules/rego/)
  regulations/            63 YAML rules (the offline TrustLint corpus)
    eu/                   36  EU AI Act and GDPR
    us/                   15  HIPAA, SOX, COPPA, TCPA, BIPA, CCPA, NYC LL144, ECPA, OFAC (3 in us/sanctions/)
    global/               1   PCI DSS
    universal/            11  PII detection (1) and prompt security (10)
  schemas/rule-schema.json  Schema every YAML rule is validated against
  scripts/validate_rules.py Schema validator
  RULE_STANDARD.md        How a rule is written, tested and approved
```

Each package directory has one aggregator file named after the directory (for example `article5/article5.rego`). It combines the leaves and carries no legal condition of its own.

The runtime API (`/v1/check`) evaluates the Rego leaves. The YAML corpus is what the offline linter TrustLint and the offline MCP server read. The two use different ID namespaces (`rego-art5-1c-001` and `EU_AI_ACT_ART5_SOCIAL_SCORING_001`) and cite the same provisions.

## How a rule ID resolves to the law

The ID alone names the provision. `rego-art5-1c-001` reads as: a Rego rule, AI Act Article 5, paragraph 1, point (c), first rule on that provision. The forms in use:

| Form | Example | Provision |
|------|---------|-----------|
| `rego-art{N}-{P}{s}-{seq}` | `rego-art5-1c-001` | AI Act Article 5(1)(c) |
| `rego-art{N}-{P}-{seq}` | `rego-art50-1-001` | AI Act Article 50(1) |
| `rego-art{N}-{seq}` | `rego-art12-001` | AI Act Article 12, read as a whole |
| `rego-art6-annex3-{point}{s}-{seq}` | `rego-art6-annex3-5b-001` | AI Act Article 6(2), Annex III point 5(b) |
| `rego-art15-ipi-{seq}` | `rego-art15-ipi-001` | AI Act Article 15(5), one prompt-injection technique per rule |
| `rego-gpai-{N}{s}-{seq}` | `rego-gpai-53a-001` | AI Act Article 53(1)(a) |
| `rego-gdpr{N}-{P}{s}-{seq}` | `rego-gdpr5-1c-001` | GDPR Article 5(1)(c) |
| `rego-sox-{section}-{seq}` | `rego-sox-302-001` | Regulation FD, 17 CFR 243.100(a) (ID kept from its first version) |

The 75 leaves carry 73 distinct IDs: two indirect prompt-injection leaves reuse the ID of the direct technique they extend. An ID is never reassigned to a different provision.

## How to read `citation :=`

Every leaf declares a `citation` constant. It is the text that goes into the decision record when the rule fires, next to the `rule_id`. Its shape is the instrument, the provision, then the text of that provision:

```rego
citation := "Regulation (EU) 2024/1689, Article 5(1)(c): the placing on the market, ..."
```

- `Regulation (EU) 2024/1689` is the AI Act. `Regulation (EU) 2016/679 (GDPR)` is the GDPR. US rules start with the code section, for example `15 U.S.C. § 7241 (SOX §302)`.
- After the colon comes the wording of the provision, quoted or closely paraphrased, so a reader can check it against the Official Journal without leaving the record.
- The file header repeats the citation in a `Legal citation:` comment and adds the recital, the date the provision applies (`Effective:`), the penalty tier, the condition type and the approval status.

A citation says which provision the rule implements. It does not say that the provision applies to your system: that depends on your role and use case, and some rules fire on text describing a control rather than on the regulated act itself. The per-rule split is in [`docs/rules-management/corpus-evidence-classification.md`](../docs/rules-management/corpus-evidence-classification.md).

## Approval states

Every leaf header carries a `Status:` line. The states, and what each means:

| Status | Meaning | Leaves today |
|--------|---------|--------------|
| `approved` | A named approver read the provision in full and signed off the condition, citation and tests, recorded in git history (RULE_STANDARD §5) | 75 |
| `review` | Written and tested, approval requested and not yet recorded | 0 |
| `pending re-approval` | Was approved; the condition changed afterwards, so the approval no longer covers the current text | 0 |
| no `Status:` line | Predates the header requirement; not approved under §5 | 0 |

Counts are for the Rego corpus as of 2026-10-22 (75 leaves). Only `approved` means approved. The rulebook publishes the status of every rule per rule, from these header lines (Rego) or the YAML `approval` object, and never shows a rule as approved that is not. All 75 Rego leaves carry `Status: approved` with an approval recorded under §5; 61 of them were approved on 2026-10-22 under §5.5 (agent-delegated review, RULE_STANDARD v1.5) after the §5.2 checklist was run and recorded in the approval commits. All 63 YAML rules carry `approval.status: approved`, approved the same way on 2026-10-22. The published rule set therefore lists all 136 rule IDs as approved.

## Running the checks

```bash
opa test rules/rego/ -v                       # Rego tests
cd rules && python scripts/validate_rules.py  # YAML schema validation
```

To propose a change to a rule, or a new rule, see [CONTRIBUTING.md](../CONTRIBUTING.md): cite the provision at paragraph and point level and include the tests.
