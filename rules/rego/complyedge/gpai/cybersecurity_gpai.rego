# ComplyEdge — EU AI Act Article 55(1)(d): Cybersecurity Gpai
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(d)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.gpai.cybersecurity_gpai

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"systemic[\\-\\s]?risk\\s+(?:gpai|model)\\s+(?:without|no)\\s+(?:cybersecurity|adequate\\s+security)\\s+(?:protection|measure|control)?",
		"(?:no|without|inadequate)\\s+cybersecurity\\s+(?:protection|measure)\\s+(?:for\\s+)?(?:the\\s+)?(?:model|gpai|physical\\s+infrastructure)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1d-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(d): Providers of GPAI models with systemic risk must ensure an adequate level of cybersecurity protection for the model and its physical infrastructure."

severity := "high"

remediation := "Ensure an adequate level of cybersecurity protection for the model and its physical infrastructure."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
