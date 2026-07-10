# ComplyEdge — EU AI Act Article 55(1)(b): Risk Mitigation
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(b)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.gpai.risk_mitigation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"systemic[\\-\\s]?risk\\s+(?:gpai|model)\\s+(?:without|no)\\s+(?:risk\\s+(?:assessment|mitigation)|mitigation\\s+measure)",
		"(?:fail|neglect|omit)\\w*\\s+to\\s+(?:assess|mitigate)\\s+systemic\\s+risk",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1b-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(b): Providers must assess and mitigate possible systemic risks at Union level, including their sources, that may stem from the GPAI model."

severity := "high"

remediation := "Assess and mitigate systemic risks stemming from the GPAI model at Union level."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
