# ComplyEdge: EU AI Act Annex III(5)(b): Creditworthiness / Credit Scoring
#
# AI systems intended to be used to evaluate the creditworthiness of natural
# persons or establish their credit score are high-risk (except AI systems used
# for the purpose of detecting financial fraud).
#
# Layer 1 detects: within one line and in this order, the word "ai", then
# creditworthiness, "credit score" or "credit scoring", or "credit rating";
# automat (any ending), AI-based or AI-driven, then "loan approv", "loan
# decision" or "credit decision"; evaluate, assess or establish, then
# creditworthiness or "credit score", then "natural person"; and "credit
# scoring" model, system or engine, then "without" high-risk, conformity or
# FRIA. It matches wording, not meaning: it misses the use described in other
# words, it fires on text that only names it, and it fires even where the
# system is used to detect financial fraud, which point 5(b) excludes ("Use AI
# to detect financial fraud in card transactions before the credit scoring
# step runs."). Whether a system evaluates the creditworthiness of natural
# persons is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 5(b)
# Recital: 58: access to essential private and public services; credit scoring
#   can determine access to financial resources
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: up to EUR 15M or 3% of total worldwide annual turnover, whichever is higher, for breach of the high-risk provider obligations (Article 99(4), point (a), Article 16)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 5(b)

package complyedge.article6.annex3_5b_creditworthiness

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:creditworthiness|credit\\s+scor\\w*|credit\\s+rating)",
		"(?:automat\\w*|\\bai[\\-\\s]?(?:based|driven)).*(?:loan\\s+approv|loan\\s+decision|credit\\s+decision)",
		"(?:evaluate|assess|establish).*credit(?:worthiness|\\s+score).*natural\\s+person",
		"credit\\s+scoring\\s+(?:model|system|engine).*without\\s+(?:high[\\-\\s]?risk|conformity|fria)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-5b-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 5(b): AI systems intended to be used to evaluate the creditworthiness of natural persons or establish their credit score, with the exception of AI systems used for the purpose of detecting financial fraud."
severity := "high"

remediation := "Treat creditworthiness / credit-scoring AI as high-risk under Annex III(5)(b). Complete conformity assessment, bias testing, human oversight (Art 14), and deployer transparency before deployment. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
