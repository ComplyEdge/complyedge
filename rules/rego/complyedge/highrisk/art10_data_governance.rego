# ComplyEdge — EU AI Act Article 10: Data Governance
#
# Legal citation: Regulation (EU) 2024/1689, Article 10
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art10_data_governance

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"training\\s+data\\s+(?:not\\s+)?(?:representative|biased|incomplete|unvetted)",
		"(?:no|without|inadequate)\\s+data\\s+governance\\s+(?:for|on)\\s+(?:high[\\-\\s]?risk|training\\s+data)",
		"(?:unrepresentative|biased)\\s+(?:training\\s+)?(?:data|dataset|sample)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art10-001"

citation := "Regulation (EU) 2024/1689, Article 10: High-risk AI systems using data-training techniques must be developed on training, validation, and testing datasets that meet quality, representativeness, and governance criteria."

severity := "high"

remediation := "Apply data governance ensuring training data is relevant, representative, and appropriately vetted."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
