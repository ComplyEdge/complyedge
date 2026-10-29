# ComplyEdge Rule Quality Standard

**Version:** 1.5
**Status:** Active
**Effective:** This standard governs every Rego rule in the ComplyEdge corpus. A rule is marked approved in a release only when it conforms to it.
**Reference structure:** ETSI TS 104 008 CABCA operationalization (Rule > Requirement > Quality Dimension > Article > Paragraph > Sub-paragraph).

**v1.1 changes (2026-05-16):** §5: added commit-message approval channel for direct-to-main commits; added agent-delegated review attribution for retroactive sign-offs; clarified that aggregator files are out of scope.

**v1.5 changes (2026-10-22):** §5.5 records the approver's authorization of 2026-10-22: agent-delegated review covers every rule, including the categories §5.5 otherwise reserves for personal reading. Each such approval line still says "via agent review", so the record shows who read what.

**v1.4 changes (2026-10-22):** §2.2 and §3.1 add the `Layer 1 detects:` paragraph: a deterministic rule states exactly what its patterns match and what they do not read, and §5.2 item 3 is checked against that statement; §3.3 and §6 follow. §1 states that a published ID is kept even when it names the wrong provision, and names the two that do.

**v1.3 changes (2026-10-21):** §1 adds the GDPR form without a point; §2.2 separates the header lines the API reads from context lines, and names the `Provision URL:` line as the API reads it; §2.4 describes how Rego and YAML rules are linked; §4 every rule now meets the §4.1 minimum, checked by execution; §6.3 maps the quality dimension to the rule packages.

**v1.2 changes (2026-10-14):** §1 documents every rule ID form in the live corpus; §2.3 states the citation shape the corpus actually uses, including GDPR and SOX; §5 states when approval is required and that the status of every rule is published per rule; the worked example reflects the current file.

**Related methodology:** the prompt-security / Indirect Prompt Injection (IPI) rules under `rules/regulations/universal/prompt_security/` are authored and tested per [`docs/security-compliance/ipi-conformity-assessment.md`](../docs/security-compliance/ipi-conformity-assessment.md), the Article 15(5) robustness methodology for these rules.

---

## 1. Rule ID Format

Every Rego rule file must declare a `rule_id` constant that is traceable from the ID alone back to the legal provision, without opening the file. The ID is stable: once a rule ships under an ID, that ID keeps pointing at the same provision.

**Base form (EU AI Act, article with paragraph):** `rego-art{article}-{paragraph}{sub}-{seq}`

| Segment | Meaning | Example |
|---------|---------|---------|
| `rego` | Identifies this as a Rego-based rule (not YAML, not policy) | `rego` |
| `art{article}` | EU AI Act article number | `art5`, `art50`, `art53` |
| `{paragraph}` | Paragraph number within the article | `1`, `2`, `3` |
| `{sub}` | Point letter (lowercase), when the paragraph has points | `a`, `b`, `c` |
| `{seq}` | Three-digit sequence for rules on the same provision | `001`, `002` |

**Other forms in the live corpus.** Not every provision has a paragraph and point, and not every rule cites the AI Act. These forms are all valid:

| Form | When it is used | Live example | Maps to |
|------|-----------------|--------------|---------|
| `rego-art{N}-{P}{s}-{seq}` | AI Act article, paragraph and point | `rego-art5-1c-001` | Article 5(1)(c), social scoring |
| `rego-art{N}-{P}-{seq}` | AI Act article and paragraph, no point | `rego-art50-1-001` | Article 50(1), chatbot disclosure |
| `rego-art{N}-{seq}` | The rule reads the article as a whole (no single paragraph decides it) | `rego-art12-001` | Article 12, record-keeping |
| `rego-art6-annex3-{point}{s}-{seq}` | Article 6(2) high-risk classification through an Annex III point | `rego-art6-annex3-5b-001` | Annex III point 5(b), creditworthiness |
| `rego-art15-ipi-{seq}` | Article 15(5) resilience against prompt injection, one rule per technique | `rego-art15-ipi-001` | Article 15(5), role hijack |
| `rego-gpai-{N}{s}-{seq}` / `rego-gpai-{N}-{P}-{seq}` | General-purpose AI model obligations (Chapter V) | `rego-gpai-53a-001`, `rego-gpai-53-2-001` | Article 53(1)(a); Article 53(2) |
| `rego-gdpr{N}-{P}{s}-{seq}` / `rego-gdpr{N}-{P}-{seq}` | GDPR, Regulation (EU) 2016/679 | `rego-gdpr5-1c-001`, `rego-gdpr32-1-001` | GDPR Article 5(1)(c), data minimisation; Article 32(1), security of processing |
| `rego-sox-{section}-{seq}` | US securities disclosure rules, first shipped under the Sarbanes-Oxley section | `rego-sox-302-001` | Regulation FD, 17 CFR 243.100(a) (ID kept from its first version) |

**More examples:**

| Rule ID | Maps to |
|---------|---------|
| `rego-art5-1a-001` | Article 5(1)(a), subliminal manipulation, first rule |
| `rego-art50-2-002` | Article 50(2), machine-readable marking, second rule |
| `rego-art53-1d-001` | Article 53(1)(d), public summary of training content |
| `rego-art55-1a-001` | Article 55(1)(a), model evaluation for GPAI models with systemic risk |
| `rego-art52-001` | Article 52, the procedure for designating a GPAI model with systemic risk |

Two indirect prompt-injection leaves reuse the ID of the direct technique they extend (`rego-art15-ipi-003`, `rego-art15-ipi-008`), so the corpus has 75 leaf files and 73 distinct IDs. A new rule takes the next free sequence number; an ID is never reassigned to a different provision. Stability outranks the form: audit records key on the ID, so an ID minted against the wrong provision is kept, and the header names the provision the rule implements on its `Provision:` line and says why the ID differs. Two IDs are in that position: `rego-art15-1-001` implements Article 15(3), and `rego-sox-302-001` implements Regulation FD (17 CFR 243.100(a)), not SOX §302.

**Why this matters:** a reviewer reading a directory listing can see which provisions are covered, which have several rules, and which are missing. If the IDs were opaque (for example `rule_047`), that assessment would need every file opened.

---

## 2. Mandatory Fields Per Rule

Every `.rego` rule file must export the following constants. OPA evaluates the `result` object; the other fields are metadata for human review, testing and audit.

### 2.1 Rego Exports (required in every rule file)

| Field | Type | Description |
|-------|------|-------------|
| `rule_id` | `string` | Formatted per Section 1 above |
| `citation` | `string` | Full legal citation (see format below) |
| `severity` | `string` | One of: `critical`, `high`, `medium`, `low` |
| `remediation` | `string` | Plain-language remediation guidance for the API consumer |
| `violation` | `boolean` | `true` if the input violates this rule; `false` otherwise |
| `result` | `object` | Aggregated output: `{violation, rule_id, citation, severity, remediation}` |

### 2.2 Rule Metadata (required in file header comment)

Every `.rego` file begins with a comment block: a title line naming the instrument, the provision and the subject, then a paragraph describing what the rule prohibits or requires, written in the language of the legal text, not as a keyword summary. A deterministic rule follows it with a `Layer 1 detects:` paragraph (§3.1). The block ends with the lines below.

**Required on every rule.** The API reads these lines into each audit record and the published rule set:

```rego
# ELI: {European Legislation Identifier of the provision, when it has one}
# Provision URL: {official text of the provision, when it has no ELI}
# Provision: {Instrument, Article {N}({P})({S})}
# Status: {draft | review | approved}
# Approved by: {name} on {YYYY-MM-DD} (required before the status is approved)
```

**Context lines.** They help a reviewer and are not read by the API. Rules carry those that apply to them:

```rego
# Legal citation: Regulation (EU) 2024/1689, Article {N}({P})({S})
# Recital: {Recital number}: {one-line summary of legislative intent}
# Effective: {YYYY-MM-DD the provision applies from, or the scope where no date applies}
# Penalty: {penalty range from the instrument}
# Condition type: {deterministic | semantic | hybrid}
# Enforcement layer: {layer1 | layer2 | both}
```

Most prompt-injection rules and the SOX rule give their basis on a `Legal basis:` line in place of `Legal citation:`. Every rule names its provision on the required `Provision:` line.

**ELI and Provision.** Each audit record names the provision a fired rule implements, read from these lines. For an EU act published in the Official Journal, `ELI` is the provision-level identifier, for example `http://data.europa.eu/eli/reg/2024/1689/art_5/par_1/pnt_c/oj`. A provision without an ELI (a standard, a guideline, national law) omits the `ELI` line and gives a `Provision:` label plus a `Provision URL:` line pointing at the official text. A rule with neither is published with no provision and says so.

**Published rule set.** Every audit record links to `https://complyedge.io/rule-set/<digest>/`, where `<digest>` is a SHA-256 over the rule files under `rules/` (test files excluded). Any change to a rule produces a new digest and a new set of pages; the pages for an earlier digest are never changed, so a record keeps pointing at the rules that decided it.

### 2.3 Citation Format

Citations must be precise enough for a lawyer to locate the exact provision. The `citation` constant names the instrument, the provision at paragraph and point level, and then quotes or closely paraphrases the text of that provision.

**Format (EU AI Act):** `Regulation (EU) 2024/1689, Article {N}({P})({S}): {text of the provision}`

**Format (other EU instruments):** the same shape with that instrument's number and short name, for example `Regulation (EU) 2016/679 (GDPR), Article {N}({P})({S}): {text}`.

**Format (US law):** the code section first, then the common name: `15 U.S.C. § 7241 (SOX §302): {text}`.

**Good:** `Regulation (EU) 2024/1689, Article 5(1)(c): the placing on the market, the putting into service or the use of AI systems for the evaluation or classification of natural persons or groups of persons...`

**Good:** `Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be adequate, relevant and limited to what is necessary...`

**Bad:** `EU AI Act Article 5` (too vague: which paragraph, which prohibition?)

When a rule reads an article as a whole (the `rego-art{N}-{seq}` form), the citation names the article and quotes the paragraphs the rule relies on.

### 2.4 Rego and YAML rules

YAML rules live under `rules/regulations/{eu,global,universal,us}/`, use their own ID scheme (for example `EU_AI_ACT_ART10_DATA_GOVERNANCE_001`) and are validated against `rules/schemas/rule-schema.json`. When a Rego rule was ported from a YAML rule, its header names the YAML rule on a `Source rule:` line. The link runs in that direction only: the YAML rule does not name the Rego rule.

---

## 3. Condition Quality (Non-Negotiable)

The `condition`, what the rule actually checks, is the most important field. A vague condition produces either false positives (blocking legitimate content) or false negatives (missing real violations). Both make the rule useless as evidence.

### 3.1 The Rule

**The condition must reference the actual legal standard from the regulation text, not a keyword proxy.**

**Deterministic rules state what they match.** A semantic condition (Layer 2, a model judging the text) is held to the rule above as written. A deterministic condition (Layer 1: regex in Rego or YAML, a format check, a checksum) cannot judge meaning. It matches wording and formats, so it can only screen for the provision, and it must say so. It meets this section when:

1. the first paragraph of the header (the YAML `description`) states the legal standard in the language of the provision, as above; and
2. a separate paragraph that begins `Layer 1 detects:` states exactly what the patterns match (the explicit phrasings, the formats, the checksums) and what they do not read: the practice described in other words, the provision's exceptions, and text that only mentions the practice, whichever apply.

In a Rego header the `Layer 1 detects:` paragraph follows the first paragraph after a blank comment line, so the first paragraph alone remains the scope a model is asked about. In YAML it is the last paragraph of `description`.

Item 3 of the §5.2 checklist ("Condition maps to a verifiable behavior (not inferred)") is checked against that paragraph. Every phrasing and format it names must match, shown by a test; text it says it does not read is not a miss. A lawful text that the paragraph's own terms cover and the rule still blocks (a refusal, a mention, an exception) is a known false positive: the paragraph names the kind, and item 6 ("No false positives introduced") holds as long as the change adds none to the test suite and the false-positive battery, whose baseline may only shrink. A phrase rule matches wording. It does not read meaning. On a paid plan, after a clean pass, an injection check can block text the rules missed when the month's model budget covers it. If that budget is used up, the phrase rules decide. The wider review runs only when it is turned on. It can look at a hit the rules already made, and it can lift that block only when every hit is cleared. A format hit such as an IBAN or a private key stays blocked. Where the wider review is off, a rule block stands. The offline engine has no model check.

Rules approved under an earlier version of this standard carry the paragraph from their next review.

### 3.2 BAD vs GOOD Examples

| | Condition | Problem |
|-|-----------|---------|
| **BAD** | "Checks if text contains social scoring language" | What is "social scoring language"? This is a keyword heuristic, not a legal standard. A compliance reviewer would ask: "language according to whom?" |
| **GOOD** | "Detects whether AI system output derives a score from behavioral, social, or personal characteristics of a natural person that causes detrimental treatment in a social context unrelated to the context in which the data was generated" | Maps directly to Article 5(1)(c). Every clause has a legal source. A lawyer reading this knows exactly what the code checks. |

| | Condition | Problem |
|-|-----------|---------|
| **BAD** | "Detects subliminal manipulation" | Circular: restates the title without defining what constitutes subliminal manipulation. |
| **GOOD** | "Detects AI techniques that deploy subliminal components beyond a person's consciousness, or purposefully manipulative or deceptive techniques, with the objective or effect of materially distorting behaviour in a manner that causes or is reasonably likely to cause significant harm" | Mirrors Article 5(1)(a) language. The key legal elements ("beyond consciousness", "materially distorting", "significant harm") are all present. |

### 3.3 Condition Checklist

Before writing a condition, verify:

- [ ] Does it reference specific legal text (article, paragraph, sub-paragraph)?
- [ ] Does it include the **key legal elements** that distinguish this prohibition from adjacent ones?
- [ ] Could a lawyer map each clause of the condition back to a sentence in the regulation?
- [ ] For a semantic condition: does it avoid keyword-only matching (e.g., "contains the word X")?
- [ ] For a deterministic condition: does the `Layer 1 detects:` paragraph name every phrasing and format the patterns match, and state what they do not read?
- [ ] Is it testable: can you write an input that should pass and an input that should fail?

---

## 4. Test Case Requirements

Every rule must include tests in `rules/rego/complyedge/test/`. Tests are not optional: they are the proof layer that makes the rule auditable.

### 4.1 Minimum Test Coverage

Each rule must have **at least 4 test cases:**

| Test type | Purpose | Example |
|-----------|---------|---------|
| **True positive** (at least 2) | Inputs that SHOULD trigger a violation | Text containing social scoring behavior in EU jurisdiction |
| **True negative** (at least 1) | Input that is safe and SHOULD NOT trigger | Normal business text in EU jurisdiction |
| **Jurisdiction guard** (at least 1) | Same violating text but in a non-applicable jurisdiction | Social scoring text but with `jurisdiction: "US"`: must NOT trigger |

### 4.2 Test Naming Convention

```
test_{rule_short_name}_{blocks|allows}_{scenario_description}
```

Examples:
- `test_social_scoring_blocks_social_credit`
- `test_social_scoring_allows_normal_text`
- `test_social_scoring_allows_non_eu`

### 4.3 Test Quality

Every test input must include a brief inline comment or the test name must make it obvious **why** the input passes or fails. A reviewer reading the tests should understand the legal reasoning without reading the rule code.

### 4.4 Checking the Minimum

The minimum is counted per rule by execution, not by test name, because many tests reach a rule through its package aggregator. `tests/unit/test_rules_standard_minimum.py` makes each rule never fire, then always fire, then removes its jurisdiction condition, and counts the tests that fail each time: those are its true positives, its negatives and its jurisdiction guards. Every rule in the corpus meets the minimum.

### 4.5 Running Tests

```bash
# Run all Rego tests
opa test rules/rego/ -v

# Run tests for a specific article
opa test rules/rego/ -v --run "article5"
```

---

## 5. Human Approval Requirement

**A rule is marked `Status: approved` in a release only after a named human approval is recorded in git history.** Until then its header says `draft` or `review`, and it is shown that way. Aggregator files (see §5.6) are out of scope.

The approval status of every rule is published per rule, from the `Status:` and `Approved by:` lines in its header. A rule in review or without a status line is listed as such, never as approved. The current counts are in [`rules/README.md`](README.md).

### 5.1 Who Can Approve

- **Martin Castro** (rule author and technical reviewer)
- **Leo Celis** (product owner and legal alignment reviewer)

Both names must be associated with their GitHub accounts for traceability. The approver carries personal accountability for the conditions in §5.3.

### 5.2 Approval Format

The approver must record the approval in **one of two equivalent channels** (both are timestamped and attributable to a named person):

**Channel A: PR comment** (preferred for new rules going through a PR):

Post a PR comment in this exact format:

```
APPROVED: {name} {YYYY-MM-DD}: confirmed Article {N}({P})({S}) condition and test cases

Checklist:
- [x] Legal text read in full (Regulation (EU) 2024/1689, Article {N})
- [x] Recital {N} reviewed for legislative intent
- [x] Condition maps to a verifiable behavior (not inferred)
- [x] Test cases cover pass AND fail scenarios
- [x] Jurisdiction guard test present
- [x] No false positives introduced in existing test suite (opa test rules/rego/ -v)
- [x] rule_id follows naming convention
- [x] Citation is precise (paragraph + sub-paragraph level)
```

**Channel B: Commit message** (required for direct-to-main commits and retroactive sign-offs):

Include the identical block above in the commit message body. Git commit history is an equivalent record to PR comments: both are timestamped and name the person who made them. Commits carry a cryptographic signature only when commit signing is enabled for that author, so the record of who approved what rests on the named `APPROVED:` line, not on a signature. The named approver in the `APPROVED:` line must match the commit author (or be explicitly attributed via §5.5 if agent-delegated).

### 5.3 What "Read in Full" Means

The approver must have read the **complete** article text, not just the sub-paragraph being coded. Adjacent sub-paragraphs often contain exceptions, scope limitations, or definitions that affect interpretation. A rule for Article 5(1)(c) requires reading all of Article 5(1), plus relevant recitals.

For agent-delegated reviews (§5.5), this means the agent reads the complete article text and quotes it verbatim in the review evidence; the approver verifies the quoted text matches the official source.

### 5.4 Approval in the Rego File

After approval, update the file header:

```rego
# Status: approved
# Approved by: Leo Celis on 2026-04-15
```

For agent-delegated reviews, use the §5.5 attribution suffix.

### 5.5 Agent-Delegated Review (added v1.1)

An approver may explicitly delegate the §5.2 review work to a coding agent (e.g., Claude) provided **all** of the following hold:

1. The approver explicitly authorizes the delegation in writing (commit message, PR, or persistent log) before the agent begins the review.
2. The agent produces a complete §5.2 checklist with **verbatim quotes** from the legal text as evidence for each item. The agent's analysis is included in the commit message or attached to the PR.
3. The approver reviews the agent's analysis before the approval is recorded. The approver remains personally accountable for the conditions in §5.3; delegation transfers the labor of reading and verifying, not the accountability.
4. The approval line in the file header and commit message uses this exact format:

```rego
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
```

5. The commit message includes a `Reviewed by:` trailer naming the agent:

```
Reviewed by: ComplyEdge Agent (Claude Sonnet 4.6)
Authorized by: Leo Celis on 2026-05-16
Approved by: Leo Celis on 2026-05-16 (via §5.5 agent-delegated review)
```

This format is honest for a reviewer: a compliance reviewer asking "did you personally read the legal text?" gets the truthful answer "the agent read it, quoted it verbatim in the commit, and I verified the quotes match the OJ; I accept accountability for the result." The audit trail records exactly who did what.

**Agent-delegated review is appropriate for:** retroactive sign-offs on pre-standard rules; bulk reviews where mechanical thoroughness exceeds human bandwidth.

**Agent-delegated review is NOT appropriate for:** rules that establish new legal interpretations; first-of-kind rules in a new article category; any rule the approver intends to defend personally in a regulator conversation. For those, the approver must conduct §5.3 reading personally.

**Authorization of 2026-10-22 (v1.5).** Leo Celis authorized agent-delegated review for every rule in the corpus, including the three categories above. The approvals of that date say "via agent review" in every file, so a reader can tell them from a personal reading. Before the approver defends a rule personally in a regulator conversation, the approver reads its provision personally, as the paragraph above requires. Rules whose source text an agent may not read in full are approved only at the level they cite and say so in their `compliance_notes` (PCI DSS: Requirement 3 title, standard text behind the PCI SSC licence not read).

### 5.6 Aggregator File Carve-Out (added v1.1)

Aggregator files (`article5.rego`, `article50.rego`, `article6.rego`, `data_protection.rego`, `gpai.rego`, `highrisk.rego`, `prompt_security.rego`, `us_corpus.rego`) import and combine other rules' `violation` results into a single package-level result. They contain no legal condition of their own: every condition they check is defined in another file that is itself subject to §5.

Aggregators are **exempt from §5 approval headers** because:
1. They have no legal citation to read in full.
2. Their correctness derives from the correctness of the imported rules.
3. Their pattern is mechanical: `aggregated_violation := any rule's violation`.

Aggregators must still include a header comment that lists which rules they aggregate, but no `Status:` or `Approved by:` field is required.

---

## 6. Quality Bar for a Reviewer

### 6.1 The 30-Minute Test

The target: **a compliance lawyer or auditor who reads this document and 3 sample rules can, within 30 minutes, trace each rule to the provision it implements, say what text it checks, see its tests, and see who approved it and when.**

That assessment is driven by:

1. **Traceability:** Every rule maps to a specific legal provision, not a vague topic area.
2. **Precision:** Conditions use the language of the law, not keyword proxies. A deterministic rule says in its `Layer 1 detects:` paragraph exactly which wording and formats it matches.
3. **Coverage structure:** The rule ID scheme shows which articles are covered and which are not, with no opaque numbering.
4. **Test rigor:** Every rule has pass, fail and jurisdiction tests. The tests themselves are readable.
5. **Approval trail:** Git history names the person who approved each rule; rules without a recorded approval are shown as not approved.
6. **Separation of concerns:** Deterministic rules (Rego/OPA) and semantic rules (LLM) are labelled. Reviewers know which rules are reproducible and which depend on an LLM.

### 6.2 What Fails the Quality Bar

A rule fails this standard if any of the following are true:

- The `rule_id` does not follow one of the forms in §1
- The `citation` references only the article number (e.g., "Article 5") without paragraph and point where the provision has them
- A semantic condition is a keyword check rather than a legal-standard check
- A deterministic rule has no `Layer 1 detects:` paragraph, or the paragraph claims a phrasing or format the patterns do not match
- Fewer than 4 test cases exist
- No jurisdiction guard test exists
- The header says `Status: approved` but no approval is recorded in git history
- The `status` field in the header is `draft` in a release

### 6.3 ETSI TS 104 008 Alignment

The ComplyEdge rule structure follows the operationalization hierarchy from ETSI TS 104 008 (Continuous Auditing Based Conformity Assessment, CABCA):

| ETSI Concept | ComplyEdge Mapping |
|---|---|
| **Requirement** | Article + Paragraph + Point (e.g., Art 5(1)(c)) |
| **Quality Dimension** | The rule's package: `article5` (prohibited practices), `article50` (transparency), `article6` and `highrisk` (high-risk obligations), `gpai`, `data_protection`, `prompt_security`, `us_corpus` |
| **Assessment Criterion** | The `condition` field: the verifiable behaviour being checked |
| **Evidence** | Test cases + OPA evaluation output |
| **Decision record** | The `result` object returned by OPA |

This alignment is intentional, so reviewers familiar with that hierarchy can find their way around. It is a mapping of structure, not a claim that any assessment body has reviewed or accepted the corpus.

---

## Worked Example: Evaluating an Existing Rule

**Rule:** `rules/rego/complyedge/article5/social_scoring.rego` (as of v1.2 of this standard)

| Field | Current Value | Meets Standard? |
|-------|---------------|-----------------|
| `rule_id` | `rego-art5-1c-001` | **Yes**: base form `rego-art{article}-{paragraph}{sub}-{seq}` |
| `citation` | `Regulation (EU) 2024/1689, Article 5(1)(c):` followed by the text of the provision | **Yes**: point-level precision with the legal text |
| `severity` | `critical` | **Yes**: Article 5 breaches carry the highest penalty tier (up to EUR 35M or 7% of worldwide turnover) |
| `remediation` | Plain-language guidance | **Yes** |
| Header comment | Citation, recital 31, effective date 2025-02-02, penalty, condition type, enforcement layer, status, approver | **Yes** |
| Test cases | 5 tests in `test/article5_test.rego` (3 true positive, 1 true negative, 1 jurisdiction guard) | **Yes**: exceeds the minimum |
| Human approval | `Status: approved`, `Approved by: Leo Celis on 2026-05-10`, recorded in the commit that signed off the Article 5 rules | **Yes** |

**Action items for this rule:** none. A change to its condition or citation returns it to `review` until it is approved again.

---

## Revision History

| Version | Date | Change | Author |
|---------|------|--------|--------|
| 1.0 | 2026-04-09 | Initial standard: all 5 required sections plus worked example | Martin Castro |
| 1.1 | 2026-05-16 | §5.2 commit-message channel (Channel B); §5.5 agent-delegated review; §5.6 aggregator carve-out | Leo Celis (drafted via agent under §5.5 delegation) |
| 1.2 | 2026-10-14 | §1 every live ID form; §2.3 citation shape incl. GDPR and SOX; §5 approval before a rule is marked approved in a release, status published per rule; §6 reviewer test; worked example updated | Leo Celis (drafted via agent) |
| 1.3 | 2026-10-21 | §1 GDPR form without a point; §2.2 required and context header lines, `Provision URL:`; §2.4 how Rego and YAML rules are linked; §4.4 minimum checked by execution; §6.3 quality dimension mapped to packages | Leo Celis (drafted via agent) |
| 1.4 | 2026-10-22 | §2.2 and §3.1 `Layer 1 detects:` paragraph for deterministic rules, item 3 checked against it; §3.3, §6.1 and §6.2 follow; §1 ID stability outranks the form | Leo Celis (drafted via agent) |
