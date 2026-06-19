# Contributing to ComplyEdge

ComplyEdge enforces EU AI Act compliance at runtime — not a scanner, not a linter. It runs in production, on every AI request, and blocks violations before they reach users. The EU AI Act is already in force. The corpus is what makes enforcement possible — and it only compounds if people outside the core team add rules. Each rule you contribute is a legal artifact, traceable to an exact article, paragraph, and sub-paragraph, that could appear in a regulator's audit trail or an external compliance review. This guide explains how.

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
- Rules without at least four test cases: two true positives (inputs that must trigger a violation), one true negative (legitimate input that must not trigger), and one jurisdiction guard (same violating input with a non-EU jurisdiction — must not trigger).
- Rules that expand scope beyond the EU AI Act. **External contributions are scoped to EU AI Act Articles 5, 50, and GPAI (Articles 51–55) only.** The repo contains rules for other regulations (GDPR, HIPAA, SOX) built by the core team — those are not open for community contributions in 2026. Scope discipline is what makes the EU AI Act corpus defensible to a regulator.
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

Rules you write here run through OPA — CE's deterministic Layer 1 enforcement path. When CE evaluates an AI request, your rule fires as a binary pass/block decision with your citation attached. Write the condition as if a lawyer will read it and a machine will execute it.

What exact behavior does this clause prohibit or require? The condition must be **verifiable**, not inferred.

- Bad: "checks for manipulative language."
- Good: "detects whether AI output deploys subliminal techniques that distort a person's behaviour in a way that impairs their ability to make an informed decision" — Article 5(1)(a).

Community contributions are Layer 1 (Rego) only — deterministic conditions expressible as logic checks. If a clause cannot be reduced to a structural check, it is out of scope for this guide. Mark your rule `Condition type: deterministic`. If a clause has both a detectable structural component and an interpretive component, write the Rego for the structural part and mark it `Condition type: hybrid` — the core team handles the interpretive layer. When in doubt, open a GitHub Discussion before writing code.

### Step 3 — Write the rule per RULE_STANDARD.md

Look at an existing rule in the same article as a template. Good reference rules:

- [`rules/rego/complyedge/article5/social_scoring.rego`](rules/rego/complyedge/article5/social_scoring.rego) — Article 5(1)(c); good example of condition precision and test coverage. Note: missing some header fields (recital, status, approved_by) per RULE_STANDARD.md worked example — your rule should have all fields populated.
- [`rules/rego/complyedge/article50/deepfake_disclosure.rego`](rules/rego/complyedge/article50/deepfake_disclosure.rego) — Article 50 transparency.
- [`rules/rego/complyedge/gpai/model_classification.rego`](rules/rego/complyedge/gpai/model_classification.rego) — Article 51 GPAI.

Naming convention is mandatory: `rego-art{N}-{paragraph}{sub}-{seq}` (e.g. `rego-art5-1c-001`). The header comment block and metadata fields are listed in [`rules/RULE_STANDARD.md`](rules/RULE_STANDARD.md) §2. **All fields are required. None are optional.**

### Step 4 — Write test cases

Minimum: four test cases per rule.

- **Two true positives** — inputs that must trigger a violation (use realistic AI output text, not toy strings).
- **One true negative** — a legitimate input that must not trigger.
- **One jurisdiction guard** — the same violating input but with `jurisdiction: "US"` (or any non-EU jurisdiction). It must not trigger. This prevents over-broad rules that fire outside their legal scope.

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
APPROVED: <your name> <YYYY-MM-DD> — confirmed Article X(Y)(Z) condition and test cases

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

This is the human approval step. Without it, the PR will not be merged. The reason is that compliance rules carry legal weight — we will not infer your intent from a thumbs-up emoji.

---

## Review process

All rules are reviewed by Leo or Martin before merging.

Review criteria:

1. Is the legal citation correct? (Article, paragraph, sub-paragraph, recital.)
2. Is the condition verifiable, not just plausible?
3. Do test cases cover both outcomes? Do they use realistic text?
4. Does the rule conform to RULE_STANDARD.md (ID format, header fields, citation format)?

Target review time: **5 business days.** If your rule is rejected, you will receive a comment explaining exactly why and what to change. Rejections are not personal — they are an artifact of the legal rigor that makes the corpus useful to diligence reviewers.

---

## Recognition

Contributors are listed in `CONTRIBUTORS.md` (created on first external merge).

Rules you author carry your name in the `Approved by` field of the rule header. If a rule you contributed is cited in a compliance audit or customer compliance report, you will be acknowledged.

---

## Questions

- **Bug in the engine, the SDK, or the test harness?** Open a GitHub Issue.
- **Question about rule scope, legal interpretation, or whether your idea fits the corpus?** Open a GitHub Discussion. We answer scope and interpretation questions in public so the next contributor can read the thread.

Issues are for bugs. Discussions are for legal and scope questions. Please do not mix them.

---

## Code of Conduct

Be respectful. Focus on improving compliance coverage. Regulatory accuracy matters more than rule quantity.
