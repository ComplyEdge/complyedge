# ComplyEdge — EU AI Act Article 6 + Annex III §5: Access to Essential Services
#
# Classifies AI systems used for creditworthiness, credit scoring, insurance
# pricing/risk, eligibility for public welfare/benefits, and emergency
# services dispatch/triage as high-risk under Annex III §5.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(5)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: agent review — pending Leo sign-off (RULE_STANDARD §5, card 197)
# Approved by: (TBD)

package complyedge.article6.essential_services

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:credit\\s+scor|creditworthiness|loan\\s+approv|loan\\s+decision)",
		"ai.*(?:insurance\\s+pricing|insurance\\s+risk\\s+assess|underwrit)",
		"ai.*(?:welfare|social\\s+benefit|benefits?\\s+eligibility)",
		"ai.*(?:emergency\\s+(?:response|dispatch|services?)\\s+(?:routing|triage))",
		"automated\\s+(?:credit|loan|insurance)\\s+(?:decision|approv|underwrit)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-5-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(5): AI for creditworthiness, insurance pricing, public welfare eligibility, or emergency dispatch is high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Essential-services AI requires bias and fairness testing, human oversight (Art 14), explainability to affected persons, and post-market monitoring."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
