# ComplyEdge — EU AI Act Article 14: Human Oversight
#
# Legal citation: Regulation (EU) 2024/1689, Article 14
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art14_human_oversight

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no)\\s+human\\s+(?:oversight|supervision|review|intervention|control)",
		"fully\\s+autonomous\\s+high[\\-\\s]?risk\\s+ai\\s+(?:without|no)\\s+human\\s+(?:oversight|in\\s+the\\s+loop)",
		"human\\s+oversight\\s+(?:not\\s+)?(?:implemented|possible|provided)\\s*(?:false|no)?",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art14-001"

citation := "Regulation (EU) 2024/1689, Article 14: High-risk AI systems must be designed to be effectively overseen by natural persons during the period in which they are in use."

severity := "high"

remediation := "Design effective human oversight measures for the high-risk AI system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
