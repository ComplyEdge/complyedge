# ComplyEdge — EU AI Act Article 5(1)(e): Predictive Policing
#
# Prohibits AI systems that make risk assessments of natural persons
# to assess or predict the risk of a natural person committing a
# criminal offence, based solely on profiling or personality traits.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(e)
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue

package complyedge.article5.predictive_policing

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	predictive_policing_pattern_match
}

predictive_policing_pattern_match if {
	patterns := [
		"predictive[\\- ]?policing",
		"pre[\\- ]?crime",
		"crime[\\- ]?probability[\\- ]?predict",
		"individual[\\- ]?criminal[\\- ]?risk",
		"profiling[\\- ]?based[\\- ]?crime",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1e-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(e): Prohibits AI systems that make risk assessments of natural persons to predict the risk of committing a criminal offence, based solely on profiling or personality traits and characteristics."

severity := "critical"

remediation := "Remove any predictive policing or individual criminal risk assessment functionality that relies solely on profiling or personality traits. Risk assessments must be based on objective, verifiable facts directly linked to criminal activity."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
