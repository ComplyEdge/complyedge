# Contributing to ComplyEdge

ComplyEdge is a runtime compliance enforcement engine for AI systems, specialized in the EU AI Act. The corpus only compounds if people outside the core team add rules. This guide explains how.

> **The strict format spec lives in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md).** This file is the front door — process, expectations, and the 5-step rule-writing workflow. RULE_STANDARD.md is the law.

---

## Who should contribute

You are a good contributor if you are:

- A **compliance lawyer** or **legal engineer** who has read the EU AI Act and wants to formalize a rule you already enforce manually.
- An engineer working on AI systems who has hit a clause that you can describe precisely and test.

You do **not** need to be a Rego expert. You need to understand the legal standard you are encoding. Rego is a small language; we will help you with syntax. We cannot help you with the law — that is your contribution.

---

## What we accept

- New rules for uncovered Article 5, Article 50, or GPAI (Articles 51–55) clauses.
- Improvements to existing rule conditions — more precise, fewer false positives.
- New test cases for existing rules — both passing and blocking examples, using realistic AI output text.
- Citation corrections — wrong sub-paragraph reference, missing recital.

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
- Rules without at least two test cases (one passing, one blocking).
- Rules that expand scope beyond the EU AI Act. **No GDPR, no HIPAA, no NIST, no SOX.** Scope discipline is the product. See `rules/rule_standard_intent.yaml` for why.
- Rules that do not conform to [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md) (mandatory ID format, citation format, header fields, test requirements).
- PRs without an explicit human approval comment from the contributor (see step 5 below).

> **Bar:** 20 deep rules > 100 shallow checks. Every rule must cite the exact legal clause it enforces.

---

## How to write a rule (5 steps)

### Step 1 — Find the clause

Read the exact Article, paragraph, and sub-paragraph in the official EU AI Act text:
<https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32024R1689>

Read the corresponding **Recital** for legislative intent. The recital tells you what the article was meant to do, which constrains how you write the condition.

### Step 2 — Write the condition

What exact behavior does this clause prohibit or require? The condition must be **verifiable**, not inferred.

- Bad: "checks for manipulative language."
- Good: "detects whether AI output deploys subliminal techniques that distort a person's behaviour in a way that impairs their ability to make an informed decision" — Article 5(1)(a).

If the condition is deterministic (regex, structural check), it goes in Layer 1 (Rego). If it requires interpretation, it goes in Layer 2 (LLM-backed). RULE_STANDARD.md has the decision matrix.

### Step 3 — Write the rule per RULE_STANDARD.md

Look at an existing rule in the same article as a template. Good reference rules:

- [`rules/rego/complyedge/article5/social_scoring.rego`](rules/rego/complyedge/article5/social_scoring.rego) — Article 5(1)(c), passes 5/7 quality fields.
- [`rules/rego/complyedge/article50/deepfake_disclosure.rego`](rules/rego/complyedge/article50/deepfake_disclosure.rego) — Article 50 transparency.
- [`rules/rego/complyedge/gpai/model_classification.rego`](rules/rego/complyedge/gpai/model_classification.rego) — Article 51 GPAI.

Naming convention is mandatory: `rego-art{N}-{paragraph}{sub}-{seq}` (e.g. `rego-art5-1c-001`). The header comment block and metadata fields are listed in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md) §2. **All fields are required. None are optional.**

### Step 4 — Write test cases

Minimum: two test cases per rule.

- One that **passes** (the rule does not fire on legitimate AI use).
- One that **blocks** (the rule fires on a clear violation).

Test cases must use realistic AI output text, not toy strings. Reference: [`rules/rego/complyedge/test/article5_test.rego`](rules/rego/complyedge/test/article5_test.rego).

Run the suite locally before opening the PR:

```bash
opa test rules/rego/ -v
```

### Step 5 — Open a PR

PR title format:

```
feat(rule): Article X(Y)(Z) — one-line description
```

PR description must include:

1. The legal citation: `Regulation (EU) 2024/1689, Article X, paragraph Y, sub-paragraph (Z)`.
2. A one-paragraph explanation of what the condition checks and why.
3. Confirmation that `opa test rules/rego/ -v` passes locally.

**Add a comment on your own PR** with this exact format:

```
APPROVED: <your name> <YYYY-MM-DD> — confirmed Article X(Y)(Z) condition matches the legal standard.
```

This is the human approval step. Without it, the PR will not be merged. The reason is that compliance rules carry legal weight — we will not infer your intent from a thumbs-up emoji.

---

## Review process

All rules are reviewed by Leo or Martin before merging.

Review criteria:

1. Is the legal citation correct? (Article, paragraph, sub-paragraph, recital.)
2. Is the condition verifiable, not just plausible?
3. Do test cases cover both outcomes? Do they use realistic text?
4. Does the rule conform to RULE_STANDARD.md (ID format, header fields, citation format)?

Target review time: **5 business days.** If your rule is rejected, you will receive a comment explaining exactly why and what to change. Rejections are not personal — they are an artifact of the legal rigor that makes the corpus useful to a buyer's diligence team.

---

## Recognition

Contributors are listed in `CONTRIBUTORS.md` (created on first external merge).

Rules you author carry your name in the `Approved by` field of the rule header. If a rule you contributed is cited in a buyer diligence review or a customer compliance report, you will be acknowledged.

---

## Questions

- **Bug in the engine, the SDK, or the test harness?** Open a GitHub Issue.
- **Question about rule scope, legal interpretation, or whether your idea fits the corpus?** Open a GitHub Discussion. We answer scope and interpretation questions in public so the next contributor can read the thread.

Issues are for bugs. Discussions are for legal and scope questions. Please do not mix them.

---

## Code of Conduct

Be respectful. Focus on improving compliance coverage. Regulatory accuracy matters more than rule quantity.
