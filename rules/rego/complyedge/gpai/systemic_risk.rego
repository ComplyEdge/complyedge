# ComplyEdge — EU AI Act Article 55: GPAI Systemic Risk
#
# Providers of general-purpose AI models with systemic risk shall
# perform model evaluations, assess and mitigate systemic risks,
# track and report serious incidents, and ensure adequate cybersecurity.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55
# Effective: 2026-08-02
# Penalty: up to €35M or 7% of global revenue

package complyedge.gpai.systemic_risk

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	systemic_risk_pattern_match
}

systemic_risk_pattern_match if {
	patterns := [
		"systemic[\\- ]?risk.*(?:no|without|lack).*(?:assess|evaluat|mitigat)",
		"(?:no|without|lack).*systemic[\\- ]?risk.*(?:assess|evaluat)",
		"(?:gpai|foundation[\\- ]?model).*systemic.*(?:no|without).*(?:mitigat|report)",
		"(?:skip|bypass|omit|ignor).*systemic[\\- ]?risk",
		"(?:high[\\- ]?capability|frontier).*model.*(?:no|without).*(?:risk.*assess|red[\\- ]?team)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-55-001"

citation := "Regulation (EU) 2024/1689, Article 55: Providers of GPAI models with systemic risk shall perform model evaluations, assess and mitigate systemic risks, track and report serious incidents, and ensure adequate cybersecurity protection."

severity := "critical"

remediation := "Conduct adversarial testing and red-teaming for systemic risks. Implement risk mitigation measures, establish incident tracking and reporting processes, and ensure cybersecurity protections are in place."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
