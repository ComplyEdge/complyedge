# ComplyEdge — EU AI Act Annex III(5)(b): Creditworthiness / Credit Scoring
#
# AI systems intended to be used to evaluate the creditworthiness of natural
# persons or establish their credit score are high-risk (except AI systems used
# for the purpose of detecting financial fraud).
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(5)(b)
# Recital: 58 — access to essential private and public services; credit scoring
#   can determine access to financial resources
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-11 (via agent review per RULE_STANDARD §5.1; card M3.3-T3)

package complyedge.article6.annex3_5b_creditworthiness

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:creditworthiness|credit\\s+scor\\w*|credit\\s+rating)",
		"(?:automat\\w*|ai[\\- ]?(?:based|driven)).*(?:loan\\s+approv|loan\\s+decision|credit\\s+decision)",
		"(?:evaluate|assess|establish).*credit(?:worthiness|\\s+score).*natural\\s+person",
		"credit\\s+scoring\\s+(?:model|system|engine).*without\\s+(?:high[\\- ]?risk|conformity|fria)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-5b-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(5)(b): AI used to evaluate creditworthiness or establish a credit score of natural persons is high-risk (fraud-detection carve-out excepted)."

severity := "high"

remediation := "Treat creditworthiness / credit-scoring AI as high-risk under Annex III(5)(b). Complete conformity assessment, bias testing, human oversight (Art 14), and deployer transparency before deployment."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
