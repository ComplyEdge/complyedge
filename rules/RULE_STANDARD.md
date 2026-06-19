# ComplyEdge Rule Quality Standard

**Version:** 1.1
**Status:** Active
**Effective:** This standard governs every Rego rule in the ComplyEdge corpus. No rule may be merged to `main` without conforming to it.
**Reference structure:** ETSI TS 104 008 CABCA operationalization (Rule > Requirement > Quality Dimension > Article > Paragraph > Sub-paragraph).

**v1.1 changes (2026-05-16):** §5 — added commit-message approval channel for direct-to-main commits; added agent-delegated review attribution for retroactive sign-offs; clarified that aggregator files are out of scope.

---

## 1. Rule ID Format

Every Rego rule file must declare a `rule_id` constant that is traceable from the ID alone back to the exact legal provision — without opening the file.

**Format:** `rego-{article}-{paragraph}{sub}-{seq}`

| Segment | Meaning | Example |
|---------|---------|---------|
| `rego` | Identifies this as a Rego-based rule (not YAML, not policy) | `rego` |
| `{article}` | EU AI Act article number, prefixed with `art` | `art5`, `art50`, `art52` |
| `{paragraph}` | Paragraph number within the article | `1`, `2`, `3` |
| `{sub}` | Sub-paragraph letter (lowercase) | `a`, `b`, `c` |
| `{seq}` | Three-digit sequence within the sub-paragraph | `001`, `002` |

**Examples:**

| Rule ID | Maps to |
|---------|---------|
| `rego-art5-1a-001` | Article 5(1)(a) — subliminal manipulation, first rule |
| `rego-art5-1c-001` | Article 5(1)(c) — social scoring, first rule |
| `rego-art50-1-001` | Article 50(1) — transparency for AI-generated content, first rule |
| `rego-art52-1a-001` | Article 52(1)(a) — high-risk system requirements, first rule |
| `rego-gpai-51-1-001` | Article 51(1) — GPAI model obligations, first rule |

**Why this matters:** A compliance reviewer skimming a directory listing of 50 rule files can immediately see which articles are covered, which have multiple sub-rules, and which are missing. If the IDs are opaque (e.g., `rule_047`), that assessment is impossible without opening every file.

---

## 2. Mandatory Fields Per Rule

Every `.rego` rule file must export the following constants. OPA evaluates the `result` object; the other fields are metadata for human review, testing, and due diligence.

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

Every `.rego` file must begin with a structured comment block:

```rego
# ComplyEdge — EU AI Act {Article}({Paragraph})({Sub}): {Title}
#
# {One-paragraph description of what this rule prohibits or requires,
#  written in the language of the legal text, not as a keyword summary.}
#
# Legal citation: Regulation (EU) 2024/1689, Article {N}({P})({S})
# Recital: {Recital number} — {one-line summary of legislative intent}
# Effective: {YYYY-MM-DD}
# Penalty: {penalty range from the Act}
# Condition type: {deterministic | semantic | hybrid}
# Enforcement layer: {layer1 | layer2 | both}
# Status: {draft | review | approved}
# Approved by: {name} on {YYYY-MM-DD} (required before merge)
```

### 2.3 Citation Format

Citations must be precise enough for a lawyer to locate the exact sentence:

**Format:** `Regulation (EU) 2024/1689, Article {N}, paragraph {P}, sub-paragraph ({S})[, sentence {N}]`

**Good:** `Regulation (EU) 2024/1689, Article 5, paragraph 1, sub-paragraph (c): The placing on the market... of AI systems to evaluate or classify natural persons... based on their social behaviour...`

**Bad:** `EU AI Act Article 5` (too vague — which paragraph? which prohibition?)

### 2.4 Companion YAML Rule (when applicable)

If the rule has both a Rego implementation (Layer 1, deterministic) and a YAML hybrid_detection rule (Layer 1+2, regex + LLM), both must share the same `rule_id` root and cross-reference each other. The YAML rule lives in `rules/regulations/eu/` and follows the existing `rule-schema.json`.

---

## 3. Condition Quality (Non-Negotiable)

The `condition` — what the rule actually checks — is the most important field. A vague condition produces either false positives (blocking legitimate content) or false negatives (missing real violations). Both are fatal during DD.

### 3.1 The Rule

**The condition must reference the actual legal standard from the regulation text, not a keyword proxy.**

### 3.2 BAD vs GOOD Examples

| | Condition | Problem |
|-|-----------|---------|
| **BAD** | "Checks if text contains social scoring language" | What is "social scoring language"? This is a keyword heuristic, not a legal standard. A compliance reviewer would ask: "language according to whom?" |
| **GOOD** | "Detects whether AI system output derives a score from behavioral, social, or personal characteristics of a natural person that causes detrimental treatment in a social context unrelated to the context in which the data was generated" | Maps directly to Article 5(1)(c). Every clause has a legal source. A lawyer reading this knows exactly what the code checks. |

| | Condition | Problem |
|-|-----------|---------|
| **BAD** | "Detects subliminal manipulation" | Circular — restates the title without defining what constitutes subliminal manipulation. |
| **GOOD** | "Detects AI techniques that deploy subliminal components beyond a person's consciousness, or purposefully manipulative or deceptive techniques, with the objective or effect of materially distorting behaviour in a manner that causes or is reasonably likely to cause significant harm" | Mirrors Article 5(1)(a) language. The key legal elements — "beyond consciousness", "materially distorting", "significant harm" — are all present. |

### 3.3 Condition Checklist

Before writing a condition, verify:

- [ ] Does it reference specific legal text (article, paragraph, sub-paragraph)?
- [ ] Does it include the **key legal elements** that distinguish this prohibition from adjacent ones?
- [ ] Could a lawyer map each clause of the condition back to a sentence in the regulation?
- [ ] Does it avoid keyword-only matching (e.g., "contains the word X")?
- [ ] Is it testable — can you write an input that should pass and an input that should fail?

---

## 4. Test Case Requirements

Every rule must include tests in `rules/rego/complyedge/test/`. Tests are not optional — they are the proof layer that makes the rule auditable.

### 4.1 Minimum Test Coverage

Each rule must have **at least 4 test cases:**

| Test type | Purpose | Example |
|-----------|---------|---------|
| **True positive** (at least 2) | Inputs that SHOULD trigger a violation | Text containing social scoring behavior in EU jurisdiction |
| **True negative** (at least 1) | Input that is safe and SHOULD NOT trigger | Normal business text in EU jurisdiction |
| **Jurisdiction guard** (at least 1) | Same violating text but in a non-applicable jurisdiction | Social scoring text but with `jurisdiction: "US"` — must NOT trigger |

### 4.2 Test Naming Convention

```
test_{rule_short_name}_{blocks|allows}_{scenario_description}
```

Examples:
- `test_social_scoring_blocks_social_credit`
- `test_social_scoring_allows_normal_text`
- `test_social_scoring_allows_non_eu`

### 4.3 Test Quality

Every test input must include a brief inline comment or the test name must make it obvious **why** the input passes or fails. During DD, a reviewer reading tests should understand the legal reasoning without reading the rule code.

### 4.4 Running Tests

```bash
# Run all Rego tests
opa test rules/rego/ -v

# Run tests for a specific article
opa test rules/rego/ -v --run "article5"
```

---

## 5. Human Approval Requirement

**No individual rule file may be on `main` without a named human approval recorded in git history.** Aggregator files (see §5.6) are out of scope.

### 5.1 Who Can Approve

- **Martin Castro** (rule author and technical reviewer)
- **Leo Celis** (product owner and legal alignment reviewer)

Both names must be associated with their GitHub accounts for traceability. The approver carries personal accountability for the conditions in §5.3.

### 5.2 Approval Format

The approver must record the approval in **one of two equivalent channels** (both produce immutable, signed audit trails):

**Channel A — PR comment** (preferred for new rules going through a PR):

Post a PR comment in this exact format:

```
APPROVED: {name} {YYYY-MM-DD} — confirmed Article {N}({P})({S}) condition and test cases

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

**Channel B — Commit message** (required for direct-to-main commits and retroactive sign-offs):

Include the identical block above in the commit message body. Git commit history is an equivalent audit substrate to PR comments — both are signed, immutable, and timestamped. The named approver in the `APPROVED:` line must match the commit author (or be explicitly attributed via §5.5 if agent-delegated).

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
3. The approver reviews the agent's analysis before the approval is recorded. The approver remains personally accountable for the conditions in §5.3 — delegation transfers the labor of reading and verifying, not the accountability.
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

This format is honest for DD: an acquirer's lawyer asking "did you personally read the legal text?" gets the truthful answer "the agent read it, quoted it verbatim in the commit, and I verified the quotes match the OJ; I accept accountability for the result." The audit trail records exactly who did what.

**Agent-delegated review is appropriate for:** retroactive sign-offs on pre-standard rules; bulk reviews where mechanical thoroughness exceeds human bandwidth.

**Agent-delegated review is NOT appropriate for:** rules that establish new legal interpretations; first-of-kind rules in a new article category; any rule the approver intends to defend personally in a regulator conversation. For those, the approver must conduct §5.3 reading personally.

### 5.6 Aggregator File Carve-Out (added v1.1)

Aggregator files (`article5.rego`, `article50.rego`, `gpai.rego`) import and combine other rules' `violation` results into a single package-level result. They contain no legal condition of their own — every condition they check is defined in another file that is itself subject to §5.

Aggregators are **exempt from §5 approval headers** because:
1. They have no legal citation to read in full.
2. Their correctness derives from the correctness of the imported rules.
3. Their pattern is mechanical: `aggregated_violation := any rule's violation`.

Aggregators must still include a header comment that lists which rules they aggregate, but no `Status:` or `Approved by:` field is required.

---

## 6. Quality Bar for Due Diligence

### 6.1 The 30-Minute Test

The target: **a compliance lawyer at Check Point, Proofpoint, or CrowdStrike reads this document and 3 sample rules, and in 30 minutes concludes: "this corpus would take 18 months to replicate, not 3."**

That assessment is driven by:

1. **Traceability:** Every rule maps to a specific legal provision, not a vague topic area.
2. **Precision:** Conditions use the language of the law, not keyword proxies.
3. **Coverage structure:** The rule ID scheme reveals which articles are covered and which are not — no hiding behind an opaque numbering system.
4. **Test rigor:** Every rule has pass/fail/jurisdiction tests. The tests themselves are readable.
5. **Approval trail:** Git history shows named human review on every rule merge.
6. **Separation of concerns:** Deterministic rules (Rego/OPA) vs. semantic rules (LLM) are explicitly labeled. Reviewers know which rules are reproducible and which depend on an LLM.

### 6.2 What Fails the Quality Bar

A rule fails this standard if any of the following are true:

- The `rule_id` does not follow the naming convention
- The `citation` references only the article number (e.g., "Article 5") without paragraph and sub-paragraph
- The condition is a keyword check rather than a legal-standard check
- Fewer than 4 test cases exist
- No jurisdiction guard test exists
- No human approval comment exists on the merge PR
- The `status` field in the header is `draft` (drafts must not be on `main`)

### 6.3 ETSI TS 104 008 Alignment

The ComplyEdge rule structure follows the operationalization hierarchy from ETSI TS 104 008 (Conformity Assessment Body — Common Assessment, CABCA):

| ETSI Concept | ComplyEdge Mapping |
|---|---|
| **Requirement** | Article + Paragraph + Sub-paragraph (e.g., Art 5(1)(c)) |
| **Quality Dimension** | Category: `prohibited_practice`, `transparency`, `high_risk_obligation` |
| **Assessment Criterion** | The `condition` field — the verifiable behavior being checked |
| **Evidence** | Test cases + OPA evaluation output |
| **Conformity Statement** | The `result` object returned by OPA |

This alignment is intentional. Buyers familiar with EU conformity assessment standards will recognize the structure immediately.

---

## Worked Example: Evaluating an Existing Rule

**Rule:** `rules/rego/complyedge/article5/social_scoring.rego`

| Field | Current Value | Meets Standard? |
|-------|---------------|-----------------|
| `rule_id` | `rego-art5-1c-001` | **Yes** — follows `rego-{article}-{paragraph}{sub}-{seq}` format |
| `citation` | Full Article 5(1)(c) text included | **Yes** — paragraph-level precision with legal text |
| `severity` | `critical` | **Yes** — Article 5 violations carry up to 7% global revenue penalty |
| `remediation` | Clear plain-language guidance | **Yes** |
| Header comment | Article, effective date, penalty present | **Partial** — missing: recital, condition_type, enforcement_layer, status, approved_by |
| Test cases | 5 tests (2 true positive, 1 true negative, 1 jurisdiction guard, 1 aggregated) | **Yes** — exceeds minimum |
| Human approval | Not yet (rule pre-dates this standard) | **No** — needs retroactive approval before next release |

**Action items for this rule:**
1. Add missing header fields (recital, condition_type, enforcement_layer, status, approved_by)
2. Obtain human approval via PR with the checklist format above

---

## Revision History

| Version | Date | Change | Author |
|---------|------|--------|--------|
| 1.0 | 2026-04-09 | Initial standard — all 5 required sections plus worked example | Martin Castro |
| 1.1 | 2026-05-16 | §5.2 commit-message channel (Channel B); §5.5 agent-delegated review; §5.6 aggregator carve-out | Leo Celis (drafted via agent under §5.5 delegation) |
