# GPAI Compliance Benchmark: methodology

Current version: **1.1** (2026-09-24). The version is written into every result
file as `methodology_version`.

This benchmark grades the **public documentation** of general-purpose AI (GPAI)
model providers against six obligation categories from the EU AI Act,
Regulation (EU) 2024/1689. It measures documentation readiness. It is not a
runtime test of model outputs and it is not a legal verdict.

## 1. Scope

Twelve providers with material EU GPAI exposure that could be verified from
public sources. One evidence file per provider lives in `providers/<id>.yaml`
and must validate against `scripts/benchmark/provider_schema.yaml`.

## 2. The six categories

| Article | Category | Question |
|---|---|---|
| 50(2) | Content disclosure | Are synthetic outputs marked in a machine-readable format? |
| 51 + 52 | Systemic-risk classification | Is there public evidence of threshold assessment (Art 51) and Commission notification where required (Art 52)? |
| 53(1)(a) | Technical documentation | Does public material meet Annex XI completeness? |
| 53(1)(c) | Copyright transparency | Is there a published copyright policy and a workable rights-reservation / opt-out path? |
| 53(1)(b) | Downstream information | Is integrator documentation sufficient under Annex XII? |
| 55 | Systemic risk | Evaluations, adversarial testing, incident reporting, cybersecurity, for models at or above the 10^25 FLOPs presumption in Art 51(2). |

The JSON keys keep their original names (for example
`art_52_53_1_a_b_technical_documentation`). Public labels follow the
Regulation's current article numbering.

## 3. Scoring rubric

Each category is scored as an integer from 0 to 3:

| Score | Label | Standard |
|---|---|---|
| 0 | No evidence | Provider does not address the obligation publicly. |
| 1 | Partial | Mentioned without verifiable detail. |
| 2 | Adequate | Specific, sourced documentation exists. |
| 3 | Exceeds | Machine-readable, regularly updated, audited. |

How the rubric is applied to Art 50(2) content disclosure:

- **1:** disclosure appears only as a usage-policy duty placed on deployers,
  or as a visible mark that machines cannot read.
- **2:** the provider documents machine-readable marking (for example C2PA
  Content Credentials, an invisible watermark or embedded metadata) that it
  applies itself on at least one output modality or hosted surface. Surfaces
  it does not mark (open-weight releases, text) keep it from a 3.
- **3:** marking covers the provider's output modalities and is independently
  audited.

Article 55 is marked N/A for providers below the systemic-risk threshold
(`systemic_risk_threshold: false`). Those providers are scored out of 15; the
rest out of 18.

## 4. Evidence rules

- Public URLs only. No paywalled, leaked or private material.
- Every evidence item carries `url`, `verified_date` and a `summary` (a quote or
  a tight paraphrase). Optional `sha256` (hash of the page body on the day it
  was read) and `wayback_url` / `archived_date` give tamper-evident provenance.
- Evidence older than 180 days is flagged in the result file as
  `stale_evidence`.
- Files with `verification_status: pending` are excluded from the ranking and
  listed separately. `needs_review` files are ranked, with the flag visible.
- When a score changes, the rationale says from what, to what, and why.
  Earlier evidence items stay in the file, so its history is visible.

## 5. Aggregation and ranking

- Aggregate = the sum of applicable category scores.
- `compliance_pct` = aggregate / maximum (15 or 18), to one decimal.
- **Ranking is by `compliance_pct`, highest first.** Ties break on aggregate
  points, then on `provider_id` alphabetically.
- The industry average is the mean of the providers' `compliance_pct`.

## 6. Reproduce

Scoring is offline and deterministic: the same provider files and schema give
the same result, with no network access and no API key.

```bash
python scripts/benchmark/benchmark_runner.py \
  --providers providers/ \
  --schema scripts/benchmark/provider_schema.yaml \
  --output /tmp/gpai_out.json
python scripts/benchmark/leaderboard_renderer.py \
  --input /tmp/gpai_out.json \
  --markdown /tmp/leaderboard.md
```

## 7. Dispute a score

Open a pull request that changes the provider's YAML and cites a public URL we
missed. Scores move only on public evidence.

## 8. Revision history

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-05-09 | Initial methodology: six categories, 0 to 3 rubric, public-evidence rule, Art 55 N/A below threshold. |
| 1.1 | 2026-09-24 | Ranking changed from aggregate points to `compliance_pct`, because providers scored out of 15 were ranked below providers with a lower percentage scored out of 18. Scores themselves unchanged by this version. Same day: Art 50(2) evidence re-checked for all twelve providers after the transparency obligations began to apply, and the Art 50(2) application rule in section 3 written down so hosted-surface marking is scored the same way for every provider (data refresh, not a method change). |
