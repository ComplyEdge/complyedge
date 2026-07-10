# ComplyEdge — EU AI Act Article 52: Sr Designation
#
# Legal citation: Regulation (EU) 2024/1689, Article 52
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.gpai.sr_designation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:gpai|general[\\-\\s]purpose\\s+ai|foundation)\\s+model\\s+(?:with\\s+)?systemic\\s+risk\\s+(?:without|no)\\s+(?:notif|inform)\\w*\\s+(?:the\\s+)?(?:ai\\s+office|commission)",
		"(?:fail|omit|neglect)\\w*\\s+to\\s+notify\\s+(?:the\\s+)?(?:ai\\s+office|commission)\\s+(?:of\\s+)?systemic\\s+risk",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art52-001"

citation := "Regulation (EU) 2024/1689, Article 52: Providers must notify the Commission without delay when a general-purpose AI model meets the systemic-risk condition (Article 51), and may present arguments against designation."

severity := "high"

remediation := "Notify the AI Office/Commission when a GPAI model meets the systemic-risk threshold."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
