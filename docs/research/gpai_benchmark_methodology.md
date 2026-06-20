# GPAI Compliance Benchmark — Methodology

**Status:** Active (v1.0 — May 2026)
**Maintained by:** ComplyEdge core team
**Update cadence:** Quarterly, or within 14 days of any Article 51–55 enforcement action.

---

## 1. Purpose

The GPAI Compliance Benchmark grades general-purpose AI model providers on
their compliance with the disclosure, documentation, and risk-management
obligations of the EU AI Act (Articles 50(2), 51, 52, 53, and 55).

It is a **documentation audit**, not a runtime test. We score what
providers publish — model cards, API docs, terms of service, transparency
reports — against the requirements of the Act. Output behavior is not
in scope; that is what the ComplyEdge runtime engine measures.

GPAI obligations begin enforcement on **August 2, 2026**. The benchmark
is designed to surface, before that date, which providers have
documentation gaps that will translate into compliance liability for
their downstream deployers.

---

## 2. Scope

**In scope (12 providers):**

| Provider | Model class | Systemic risk |
|---|---|---|
| OpenAI | closed_api | yes (GPT-4 class) |
| Anthropic | closed_api | yes (Claude 3 Opus class) |
| Google | closed_api | yes (Gemini Ultra class) |
| Meta | open_weights | yes (Llama 3 405B) |
| Mistral | hybrid | unclear |
| xAI | closed_api | yes (Grok 4 class) |
| Cohere | hybrid | no |
| AI21 Labs | closed_api | no |
| Stability AI | open_weights | no |
| Inflection | closed_api | no (deprecated) |
| Amazon (Titan/Nova) | closed_api | no |
| Hugging Face / Aleph Alpha | open_weights | no |

**Out of scope:** narrow-purpose AI systems, image-only or audio-only
models below the GPAI threshold, internal-only enterprise models.

---

## 3. Obligation categories

Each provider is scored on six obligations. The scope of each is the
text of the Act itself — not regulator commentary, not industry custom.

### 3.1 Article 50(2) — Content disclosure

> "Providers of AI systems […] generating synthetic audio, image, video
> or text content, shall ensure that the outputs of the AI system are
> marked in a machine-readable format and detectable as artificially
> generated or manipulated."

**Verification criteria:**
- Is generated content marked machine-readable (C2PA, watermark, metadata)?
- Is there a documented disclosure mechanism in the API surface?
- Are the marking techniques resistant to standard adversarial removal?

### 3.2 Article 51 — Model classification

> "A general-purpose AI model shall be classified as a general-purpose
> AI model with systemic risk if […] the cumulative amount of computation
> used for its training measured in FLOPs is greater than 10^25."

**Verification criteria:**
- Has the provider self-classified the model under Article 51?
- Has the provider notified the AI Office (Article 52)?
- Is a systemic-risk assessment published?

### 3.3 Articles 52 + 53(1)(a)(b) — Technical documentation

> "Providers of general-purpose AI models shall draw up and keep
> up-to-date the technical documentation of the model, including its
> training and testing process and the results of its evaluation."

**Verification criteria:**
- Is a model card published with training data scope, methodology, and
  evaluation results?
- Does the documentation cover Annex XI items (architecture, parameter
  count, modalities, license, intended use, computational resources)?
- Is it kept up to date across model versions?

### 3.4 Article 53(1)(c) — Copyright transparency

> "Providers […] shall put in place a policy to comply with Union law
> on copyright and related rights, and in particular to identify and
> comply with […] a reservation of rights expressed pursuant to
> Article 4(3) of Directive (EU) 2019/790."

**Verification criteria:**
- Is a copyright compliance policy published?
- Is there an opt-out mechanism for rightsholders (robots.txt, TDM
  reservation, registry)?
- Is the policy operationally verifiable?

### 3.5 Article 53(1)(d-e) — Downstream obligations

> "Providers […] shall draw up and make publicly available a sufficiently
> detailed summary about the content used for training of the
> general-purpose AI model […] and shall make information and
> documentation available to providers of AI systems who intend to
> integrate the general-purpose AI model into their AI systems."

**Verification criteria:**
- Is a training-data summary published (per the AI Office template once finalised)?
- Is integration documentation available for downstream deployers?
- Does it cover Annex XII items (capabilities, limitations, intended
  uses, safety measures)?

### 3.6 Article 55 — Systemic risk obligations

Applies only when `systemic_risk_threshold: true`.

> "Providers of general-purpose AI models with systemic risk shall […]
> perform model evaluation in accordance with standardised protocols and
> tools […] assess and mitigate possible systemic risks at Union level
> […] keep track of, document, and report […] serious incidents."

**Verification criteria:**
- Is red-teaming or model-evaluation methodology published?
- Is there a documented incident-reporting channel?
- Are cybersecurity protections documented (model weights, training
  pipeline)?

---

## 4. Scoring rubric

Each obligation receives an integer score 0–3.

| Score | Label | Standard |
|---|---|---|
| 0 | No evidence | The provider does not address this obligation in any public documentation. |
| 1 | Partial | The obligation is mentioned but lacks verifiable detail (e.g. "we comply with copyright law" without a policy). |
| 2 | Adequate | Specific, sourced documentation exists. The obligation can be substantively assessed against it. |
| 3 | Exceeds | Documentation is machine-readable, regularly updated, and where applicable independently audited. |

**Aggregate score** per provider = sum of obligation scores. Maximum is
18 (6 × 3) for systemic-risk providers; 15 (5 × 3) otherwise — the
Article 55 column is reported as N/A and excluded from the aggregate
when `systemic_risk_threshold: false`.

---

## 5. Evidence standard

**Public documentation only.** Internal communications, leaked memos,
or paywalled content are not eligible evidence.

Each evidence item in `providers/*.yaml` must include:
- `url` — direct link to the published document (not a homepage).
- `verified_date` — the date the URL was fetched and the quoted text confirmed.
- `summary` — short quote or paraphrase of the evidence.
- `doc_type` — one of: model_card, terms_of_service, api_doc, paper,
  blog, transparency_report, other.

**Stale evidence (older than 180 days)** is automatically flagged for
re-verification by the runner.

---

## 6. Verification workflow

Each provider file carries a `verification_status` field:

- `verified` — every URL has been fetched and the quoted text
  confirmed by a human reviewer in the last 180 days.
- `needs_review` — URLs cited but at least one has not been re-confirmed
  within the last 180 days.
- `pending` — stub file. Excluded from published scores.

Only `verified` and `needs_review` files are included in the published
leaderboard. `pending` files are listed at the bottom with a note
indicating they are awaiting research.

---

## 7. Caveats

1. **Documentation ≠ behavior.** A provider can have perfect
   documentation and a non-compliant runtime, or vice versa. The
   benchmark is one of two compliance signals; the other is what the
   ComplyEdge runtime engine measures on actual model output.

2. **Self-classification dependency.** Article 51(2) systemic-risk
   classification is based on training compute, which is rarely
   disclosed. We rely on AI Office notifications and provider
   self-declarations. Where neither exists, we use third-party
   estimates and mark the obligation as `score: 1, needs_review`.

3. **Pre-enforcement window.** Until August 2, 2026, providers may
   correctly point out that obligations are not yet enforceable. We
   score readiness, not non-compliance with a not-yet-binding rule.
   The benchmark is forward-looking.

4. **Living document.** This methodology will be revised when the AI
   Office publishes implementing acts, especially the training-data
   summary template (Article 53(1)(d)) and the systemic-risk
   evaluation protocol (Article 55(1)(a)).

---

## 8. Limitations and integrity controls

This benchmark is published with full disclosure of its weaknesses. A
reader who wants to challenge any specific score should be able to do
so with the artifacts in this repository.

### 8.1 Single-rater scoring

All v1.0 scores were authored by **one human reviewer** working with
agent-assisted research. Inter-rater reliability has not been measured.
A second independent rater (Cohen's kappa target ≥ 0.7) is on the
roadmap for v1.1.

### 8.2 Intra-rater consistency

Two providers are re-scored cold each release as a calibration check.
The re-score is performed without consulting the prior rationale, only
the cited URLs. Discrepancies of more than one point on any obligation
trigger a full re-review of that provider. Calibration results are
recorded in `scripts/benchmark/results/calibration_<version>.json`.

### 8.3 Evidence integrity

Every evidence item is captured at three levels of fidelity:

| Field | Guarantee |
|---|---|
| `url` | Live link, verified HTTP 200 at `verified_date` with browser User-Agent |
| `sha256` | SHA-256 hex digest of the response body at `verified_date` — pins the exact bytes the rater saw |
| `wayback_url` | Internet Archive Wayback Machine snapshot URL, captured by `scripts/benchmark/archive_evidence.py` |

The archiving script (`scripts/benchmark/archive_evidence.py`) is
idempotent and supports a `--sha-only` fast path. **v1.0 coverage:
sha256 = 114/114 (100%); wayback = partial (Wayback Save Page Now was
returning Cloudflare 5xx during capture; remaining snapshots are
deferred to v1.1).** SHA-256 is the primary integrity control: it pins
the exact response body bytes the rater scored. Wayback is a secondary
defense-in-depth control; when SPN fails, the script falls back to the
Wayback Availability API to attach the most recent existing snapshot.
Items without a `wayback_url` are flagged in the leaderboard renderer
as `archive_pending`.

Four URLs were replaced before publication after returning HTTP 404 or
auth-redirect during capture (link rot). Replacements were verified
HTTP 200 with the same regulatory artifact:

| Original | Replacement |
|---|---|
| `openai.com/index/c2pa-in-dall-e-3/` (404) | `help.openai.com/.../c2pa-in-chatgpt-images` |
| `cdn.openai.com/gpt-4-system-card.pdf` (404) | `cdn.openai.com/papers/gpt-4-system-card.pdf` |
| `openai.com/index/disrupting-deceptive-uses-of-ai/` (404) | `openai.com/global-affairs/disrupting-malicious-uses-of-ai/` |
| `ai.google.dev/gemini-api/docs/models` (auth-gated 302) | `cloud.google.com/vertex-ai/generative-ai/docs/learn/models` |

Two anthropic URLs were similarly replaced. No score changed as a
result of any URL substitution — the regulatory artifact (RSP, system
card, etc.) was the same in each case.

### 8.4 Coverage vs absence

A `score: 0` on any obligation means **"no evidence found in publicly
indexed documentation as of `verified_date`"**, not "verified absence."
For closed-API providers with limited public surfaces (Inflection,
Amazon Titan/Nova) this distinction is material. Providers can submit
additional evidence via the `evidence-submission` issue template; the
benchmark will be re-scored within 14 days.

### 8.5 Scope-judgment disclosures

Two providers required scoring scope decisions documented in their
YAML `_scoring_note` fields:

- **Hugging Face** is scored as a first-party model publisher
  (SmolLM3, IDEFICS, Zephyr) — not as a hosting hub. Hub-hosted
  third-party models would be scored under their own provider IDs.
- **Mistral** is scored on its open-weights releases (Mistral 7B,
  Mixtral) plus its closed La Plateforme API as a single provider, on
  the basis that they share the same parent organization, ToS, and
  publication channel.

### 8.6 Pre-enforcement window

Until August 2, 2026, GPAI obligations are not yet enforceable. Scores
in v1.0 measure **readiness**, not non-compliance. A provider may
legitimately be at score 0 on Article 50(2) today and at score 3 on
August 3rd without any change in operational practice — only in
documentation. Re-publication of the benchmark is scheduled for the
week of August 4, 2026.

### 8.7 Methodology-change protocol

Any change to the rubric, scope, or obligation definitions in this
document is a breaking change and triggers a major version bump
(v1.0 → v2.0). Scores from v1.0 are not comparable to v2.0 scores.
The revision history (§ 11) records every such change.

---

## 9. Reproducing the trust controls

Re-verify any single evidence item:

```bash
# 1. Fetch the live URL and compare SHA-256
python -c "
import hashlib, urllib.request
url = '<paste evidence URL>'
ua = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36'}
req = urllib.request.Request(url, headers=ua)
print(hashlib.sha256(urllib.request.urlopen(req, timeout=30).read()).hexdigest())
"

# 2. Compare against the YAML's recorded sha256
grep -A1 '<paste evidence URL>' providers/*.yaml

# 3. View the Wayback snapshot (independent of the live URL)
# Open the wayback_url field in any browser
```

Re-archive everything from scratch:

```bash
python scripts/benchmark/archive_evidence.py
```

Run the full benchmark and regenerate outputs:

```bash
python scripts/benchmark/benchmark_runner.py
python scripts/benchmark/leaderboard_renderer.py
```

---

## 10. Revision history

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-05-09 | Initial publication. 12-provider scope. Six obligation categories. 0–3 rubric. SHA-256 evidence integrity at 100% (114/114 URLs); Wayback snapshots at partial coverage (deferred to v1.1). Limitations section. |
