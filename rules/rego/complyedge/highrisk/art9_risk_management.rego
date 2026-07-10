# ComplyEdge — EU AI Act Article 9: Risk Management
#
# Legal citation: Regulation (EU) 2024/1689, Article 9
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art9_risk_management

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no|skip\\w*|bypass\\w*)\\s+risk\\s+management\\s+(?:system|process|plan)?",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?(?:without|lacking|no)\\s+(?:risk\\s+management|lifecycle\\s+risk)",
		"risk\\s+management\\s+(?:not\\s+)?(?:required|needed|implemented|established)\\s*(?:false|no)?",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art9-001"

citation := "Regulation (EU) 2024/1689, Article 9: A risk management system must be established, implemented, documented, and maintained throughout the entire lifecycle of a high-risk AI system."

severity := "high"

remediation := "Establish and maintain a lifecycle risk-management system for the high-risk AI system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
