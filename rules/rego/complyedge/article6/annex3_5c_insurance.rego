# ComplyEdge — EU AI Act Annex III(5)(c): Life & Health Insurance Risk / Pricing
#
# AI systems intended to be used for risk assessment and pricing in relation to
# natural persons in the case of life and health insurance are high-risk.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(5)(c)
# Recital: 58 — essential private services; insurance risk/pricing can determine
#   access to life and health cover
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-11 (via agent review per RULE_STANDARD §5.1)

package complyedge.article6.annex3_5c_insurance

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:life|health)\\s+insurance.*(?:risk\\s+assess|pricing|underwrit)",
		"(?:automat\\w*|ai[\\- ]?(?:based|driven)).*(?:life|health)\\s+insurance.*(?:premium|pricing|risk)",
		"(?:insurance\\s+risk\\s+assess|insurance\\s+pricing).*natural\\s+person.*(?:life|health)",
		"(?:life|health)\\s+insurance\\s+(?:underwrit|pricing)\\s+(?:model|system).*without\\s+(?:high[\\- ]?risk|conformity|fria)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-5c-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(5)(c): AI used for risk assessment and pricing in life and health insurance for natural persons is high-risk."

severity := "high"

remediation := "Treat life/health insurance risk-assessment and pricing AI as high-risk under Annex III(5)(c). Complete conformity assessment, fairness testing, human oversight (Art 14), and post-market monitoring before deployment."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
