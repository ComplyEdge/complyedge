# ComplyEdge — EU AI Act Article 4: Ai Literacy
#
# Legal citation: Regulation (EU) 2024/1689, Article 4
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art4_ai_literacy

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:no|without|skip\\w*|neglect\\w*)\\s+ai\\s+literacy\\s+(?:training|program|measure)",
		"staff\\s+(?:operating|using|deploying)\\s+ai\\s+(?:without|lacking)\\s+(?:ai\\s+)?literacy\\s+(?:training|competence)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art4-001"

citation := "Regulation (EU) 2024/1689, Article 4: Providers and deployers must ensure a sufficient level of AI literacy among staff and others operating AI systems on their behalf."

severity := "medium"

remediation := "Provide sufficient AI literacy training to staff operating AI systems."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
