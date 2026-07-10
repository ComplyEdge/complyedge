# ComplyEdge — EU AI Act Article 11: Technical Documentation
#
# Legal citation: Regulation (EU) 2024/1689, Article 11
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.highrisk.art11_technical_documentation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?(?:without|no|lacking)\\s+technical\\s+documentation",
		"(?:no|without|skip\\w*|missing)\\s+(?:annex\\s+iv\\s+)?technical\\s+documentation\\s+(?:for\\s+)?(?:high[\\-\\s]?risk|ai\\s+system)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art11-001"

citation := "Regulation (EU) 2024/1689, Article 11: Technical documentation for a high-risk AI system must be drawn up before it is placed on the market and kept up to date, containing the elements set out in Annex IV."

severity := "high"

remediation := "Draw up and maintain Annex IV technical documentation before placing the system on the market."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
