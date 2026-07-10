# ComplyEdge — EU AI Act Article 55(1)(c): Incident Reporting
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(c)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.gpai.incident_reporting

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:no|without|disable\\w*|skip)\\s+(?:serious\\s+incident|incident)\\s+(?:tracking|reporting|report)\\s+(?:for|to)\\s+(?:gpai|ai\\s+office|model)",
		"(?:fail|neglect|omit)\\w*\\s+to\\s+(?:track|report|document)\\s+serious\\s+incident",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1c-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(c): Providers must keep track of, document, and report serious incidents and possible corrective measures to the AI Office and relevant national authorities without undue delay."

severity := "high"

remediation := "Track, document, and report serious incidents to the AI Office without undue delay."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
