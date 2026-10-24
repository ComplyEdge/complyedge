# Contributing to ComplyEdge

ComplyEdge checks AI decisions against open rules tied to the law, and edits ADCR, the open rulebook for AI decision records. Every AI decision it checks is recorded, and when a rule fires the record names that rule and the law behind it; the rules in `rules/` are what those records cite, and they only get better if people outside the core team review and add to them. Each rule you contribute is a legal artifact, traceable to an exact article, paragraph and point, that can appear in an audit record an auditor or a data protection officer reads. This guide explains how.

> **The strict format spec lives in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md).** This file is the front door: process, expectations, and the 5-step rule-writing workflow. RULE_STANDARD.md is the law.

---

## Who should contribute

You are a good contributor if you are:

- A **compliance lawyer** or **legal engineer** who has read the EU AI Act and wants to formalize a rule you already enforce manually.
- An engineer working on AI systems who has hit a clause that you can describe precisely and test.

You do **not** need to be a Rego expert. You need to understand the legal standard you are encoding. Rego is a small language; we will help you with syntax. We cannot help you with the law: that is your contribution.

---

## What we accept

- New rules for uncovered Article 5, Article 50, or GPAI (Articles 51–55) clauses.
- Improvements to existing rule conditions: more precise, fewer false positives.
- New test cases for existing rules: both passing and blocking examples, using realistic AI output text.
- Citation corrections: wrong paragraph or point reference, missing recital.
- Changes to ADCR, the rulebook (what a decision record must contain and prove, a field, a mapping to a provision or a standard): see "Proposing a rulebook change" below.

## Installing from source

Most users should `pip install complyedge` from PyPI. To work from a clone:

```bash
git clone https://github.com/ComplyEdge/complyedge.git
cd complyedge
pip install -e ./sdks/python
```

The Python SDK lives at `sdks/python/`; there is no top-level `setup.py`. Running `pip install -e .` at the repo root will fail.

## What we reject (automatically)

- Rules based on keyword matching only, with no legal standard cited.
- Rules without at least four test cases: two true positives (inputs that must trigger a violation), one true negative (legitimate input that must not trigger), and one jurisdiction guard (same violating input with a non-EU jurisdiction: must not trigger).
- Rules that expand scope beyond the EU AI Act. **External contributions are scoped to EU AI Act Articles 5, 50, and GPAI (Articles 51–55) only.** The repo contains rules for other regulations (GDPR, HIPAA, SOX) built by the core team: those are not open for community contributions in 2026. Scope discipline is what makes the EU AI Act corpus defensible to a regulator.
- Rules that do not conform to [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md) (mandatory ID format, citation format, header fields, test requirements).
- PRs without the contributor's signed checklist comment (see step 5 below).

> **Bar:** 20 deep rules > 100 shallow checks. Every rule must cite the exact legal clause it enforces.

---

## How to write a rule (5 steps)

### Step 1, Find the clause

Read the exact Article, paragraph, and sub-paragraph in the official EU AI Act text:
<https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32024R1689>

Read the corresponding **Recital** for legislative intent. The recital tells you what the article was meant to do, which constrains how you write the condition.

### Step 2, Write the condition

Rules you write here run through OPA, CE's deterministic Layer 1 enforcement path. When CE evaluates an AI request, your rule fires as a binary pass/block decision with your citation attached. Write the condition as if a lawyer will read it and a machine will execute it.

What exact behavior does this clause prohibit or require? The condition must be **verifiable**, not inferred.

- Bad: "checks for manipulative language."
- Good: "detects whether AI output deploys subliminal techniques that distort a person's behaviour in a way that impairs their ability to make an informed decision", Article 5(1)(a).

Community contributions are Layer 1 (Rego) only: deterministic conditions expressible as logic checks. If a clause cannot be reduced to a structural check, it is out of scope for this guide. Mark your rule `Condition type: deterministic`. If a clause has both a detectable structural component and an interpretive component, write the Rego for the structural part and mark it `Condition type: hybrid`: the core team handles the interpretive layer. When in doubt, open a GitHub Issue titled `Scope question: Article X(Y)(Z)` before writing code.

### Step 3, Write the rule per RULE_STANDARD.md

Look at an existing rule in the same article as a template. Good reference rules:

- [`rules/rego/complyedge/article5/social_scoring.rego`](rules/rego/complyedge/article5/social_scoring.rego), Article 5(1)(c); good example of condition precision, test coverage and a complete header (see the worked example in RULE_STANDARD.md).
- [`rules/rego/complyedge/article50/deepfake_disclosure.rego`](rules/rego/complyedge/article50/deepfake_disclosure.rego), Article 50 transparency.
- [`rules/rego/complyedge/gpai/model_classification.rego`](rules/rego/complyedge/gpai/model_classification.rego), Article 51 GPAI.

Naming convention is mandatory. The base form is `rego-art{N}-{paragraph}{sub}-{seq}` (e.g. `rego-art5-1c-001`). The live rule set also uses these forms, each documented in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md) §1:

- `rego-art{N}-{paragraph}-{seq}` when the paragraph has no points (`rego-art50-1-001`)
- `rego-art{N}-{seq}` when the rule reads the article as a whole (`rego-art12-001`)
- `rego-art6-annex3-{point}{sub}-{seq}` for Annex III high-risk areas (`rego-art6-annex3-5b-001`)
- `rego-art15-ipi-{seq}` for the Article 15(5) prompt-injection family (`rego-art15-ipi-001`)
- `rego-gpai-{N}{sub}-{seq}` for general-purpose AI model obligations (`rego-gpai-53a-001`)
- `rego-gdpr{N}-{paragraph}{sub}-{seq}` for core-team GDPR rules, and `rego-sox-{section}-{seq}` for core-team US securities disclosure rules (the one rule of that form, `rego-sox-302-001`, covers SEC Regulation FD, 17 CFR 243.100(a); its ID is kept from when it was filed under SOX §302)

Use the next free sequence number; never reuse an ID for a different provision. The header comment block and metadata fields are listed in RULE_STANDARD.md §2. **All fields are required. None are optional.**

### Step 4, Write test cases

Minimum: four test cases per rule.

- **Two true positives**: inputs that must trigger a violation (use realistic AI output text, not toy strings).
- **One true negative**: a legitimate input that must not trigger.
- **One jurisdiction guard**: the same violating input but with `jurisdiction: "US"` (or any non-EU jurisdiction). It must not trigger. This prevents over-broad rules that fire outside their legal scope.

Reference: [`rules/rego/complyedge/test/article5_test.rego`](rules/rego/complyedge/test/article5_test.rego).

Install OPA locally if you haven't already:

```bash
# macOS
brew install opa

# Linux / other
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa && sudo mv opa /usr/local/bin/opa
```

Run the full suite before opening the PR:

```bash
opa test rules/rego/ -v
```

### Step 5, Open a PR

PR title format:

```
feat(rule): Article X(Y)(Z): one-line description
```

PR description must include:

1. The legal citation, in the shape the rule set uses: `Regulation (EU) 2024/1689, Article X(Y)(Z): <text of the provision>`.
2. A one-paragraph explanation of what the condition checks and why.
3. Confirmation that `opa test rules/rego/ -v` passes locally.

**Add a comment on your own PR** with this exact format:

```
CHECKED: <your name> <YYYY-MM-DD>: confirmed Article X(Y)(Z) condition and test cases

Checklist:
- [x] Legal text read in full (Regulation (EU) 2024/1689, Article X)
- [x] Recital <N> reviewed for legislative intent
- [x] Condition maps to a verifiable behavior (not inferred)
- [x] Test cases cover pass AND fail scenarios
- [x] Jurisdiction guard test present
- [x] No false positives introduced in existing test suite (opa test rules/rego/ -v)
- [x] rule_id follows naming convention
- [x] Citation is precise (paragraph + sub-paragraph level)
```

This is your sign-off as the author. It is not the approval: a rule is approved only by a maintainer named in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md) §5.1, who posts the `APPROVED:` block from §5.2 after reviewing it. Without both comments, the PR will not be merged. The reason is that compliance rules carry legal weight: we will not infer your intent from a thumbs-up emoji.

---

## Review process

All rules are reviewed by the maintainers before merging.

Review criteria:

1. Is the legal citation correct? (Article, paragraph, sub-paragraph, recital.)
2. Is the condition verifiable, not just plausible?
3. Do test cases cover both outcomes? Do they use realistic text?
4. Does the rule conform to RULE_STANDARD.md (ID format, header fields, citation format)?

If your rule is rejected, you will receive a comment explaining exactly why and what to change. Rejections are not personal: they come from the legal rigor that makes the rule set useful to the auditors and reviewers who read the records it produces.

---

## Proposing a rulebook change

ADCR, the AI Decision Check Record ([complyedge.io/rulebook](https://complyedge.io/rulebook/)), says what an AI decision record must contain and prove under EU law, and how a third party checks it. It is separate from the rules in `rules/`: those are the rule set ComplyEdge runs, and a record names them by digest. Auditors, certifiers, data protection officers and standards-committee members are the people most likely to spot what the rulebook gets wrong. To propose a change:

1. Open a GitHub Issue titled `Rulebook change: <rule>`, for example `Rulebook change: REC-12`.
2. Name the clause of law or the audit criterion the change rests on, exactly (instrument, article, paragraph, point), and quote the text you rely on.
3. Say what the rulebook says today, what it should say, why, and which test vector the change adds or changes. If the change touches a standard (for example ISO/IEC 24970 or prEN 18229-1), name the clause; do not paste text from a paywalled standard.

ADCR is at version 0.1.0, in development, and follows semantic versioning. The decision process is in the rulebook's [governance document](https://complyedge.io/rulebook/0.1.0/GOVERNANCE.md).

---

## Recognition

Contributors are listed in `CONTRIBUTORS.md` (created on first external merge).

Your name stays on the rules you author through the PR and the commit history. The `Approved by` field in the rule header names the maintainer who approved the rule (RULE_STANDARD.md §5.4).

---

## Questions

- **Bug in the engine, the SDK, or the test harness?** Open a GitHub Issue.
- **Question about rule scope, legal interpretation, or whether your idea fits the rule set?** Open a GitHub Issue titled `Scope question: <article or idea>`. We answer scope and interpretation questions in public so the next contributor can read the thread.

Keep one question per issue, and keep scope questions apart from bug reports.

---

## Code of Conduct

Be respectful. Focus on improving compliance coverage. Regulatory accuracy matters more than rule quantity.
