# ComplyEdge — EU AI Act Article 15(5): Cybersecurity
#
# Legal citation: Regulation (EU) 2024/1689, Article 15(5)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.highrisk.art15_cybersecurity

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no|inadequate)\\s+cybersecurity\\s+(?:for\\s+)?(?:high[\\-\\s]?risk\\s+ai|the\\s+ai\\s+system)",
		"vulnerable\\s+to\\s+(?:adversarial|data\\s+poisoning|model\\s+poisoning|evasion)\\s+(?:attack|manipulation)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-5-001"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems must be resilient against attempts by unauthorised third parties to alter their use, outputs, or performance, including data and model poisoning."

severity := "high"

remediation := "Implement cybersecurity measures resilient to adversarial attacks, data and model poisoning."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
