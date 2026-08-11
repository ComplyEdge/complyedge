# ComplyEdge — EU AI Act Article 13: Transparency
#
# Legal citation: Regulation (EU) 2024/1689, Article 13
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.highrisk.art13_transparency

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no)\\s+(?:instructions?\\s+for\\s+use|deployer\\s+(?:information|documentation)|transparency\\s+(?:information|documentation))",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?(?:without|no)\\s+(?:instructions\\s+for\\s+use|transparency)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art13-001"

citation := "Regulation (EU) 2024/1689, Article 13: High-risk AI systems shall be designed and developed in such a way as to ensure that their operation is sufficiently transparent to enable deployers to interpret a system's output and use it appropriately. Instructions for use shall include concise, complete, correct and clear information that is relevant, accessible and comprehensible to deployers."
severity := "high"

remediation := "Provide instructions for use enabling deployers to interpret and use the system's output appropriately."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
