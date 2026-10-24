# ComplyEdge: EU AI Act Annex III(5)(c): Life & Health Insurance Risk / Pricing
#
# AI systems intended to be used for risk assessment and pricing in relation to
# natural persons in the case of life and health insurance are high-risk.
#
# Layer 1 detects: within one line and in this order, the word "ai", then
# "life insurance" or "health insurance", then "risk assess", pricing or
# underwriting; automat (any ending), AI-based or AI-driven, then life or
# health insurance, then premium, pricing or risk; "insurance risk assess" or
# "insurance pricing", then "natural person", then life or health; and life or
# health insurance underwriting or pricing directly followed by model or
# system, then "without" high-risk, conformity or FRIA. The order is fixed:
# the same words in another order do not match. It matches wording, not
# meaning: it misses the use described in other words or order ("AI model
# performs risk assessment for life insurance applicants from their wearable
# data."), and it fires on text that only names it. Whether a system is used
# for risk assessment and pricing of natural persons in life or health
# insurance is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 5(c)
# Recital: 58: essential private services; insurance risk/pricing can determine
#   access to life and health cover
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: up to EUR 15M or 3% of total worldwide annual turnover, whichever is higher, for breach of the high-risk provider obligations (Article 99(4), point (a), Article 16)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 5(c)

package complyedge.article6.annex3_5c_insurance

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:life|health)\\s+insurance.*(?:risk\\s+assess|pricing|underwrit)",
		"(?:automat\\w*|\\bai[\\-\\s]?(?:based|driven)).*(?:life|health)\\s+insurance.*(?:premium|pricing|risk)",
		"(?:insurance\\s+risk\\s+assess|insurance\\s+pricing).*natural\\s+person.*(?:life|health)",
		"(?:life|health)\\s+insurance\\s+(?:underwrit|pricing)\\s+(?:model|system).*without\\s+(?:high[\\-\\s]?risk|conformity|fria)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-5c-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 5(c): AI systems intended to be used for risk assessment and pricing in relation to natural persons in the case of life and health insurance."
severity := "high"

remediation := "Treat life/health insurance risk-assessment and pricing AI as high-risk under Annex III(5)(c). Complete conformity assessment, fairness testing, human oversight (Art 14), and post-market monitoring before deployment. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
