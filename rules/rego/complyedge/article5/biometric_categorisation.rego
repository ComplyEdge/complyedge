# ComplyEdge — EU AI Act Article 5(1)(g): Biometric Categorisation
#
# Prohibits AI systems that use biometric categorisation to infer race,
# political opinions, trade union membership, religious or philosophical
# beliefs, sex life, or sexual orientation.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(g)
# Recital: 30 — biometric categorisation inferring race, political opinions, trade union membership, religion, sex life or sexual orientation breaches fundamental rights and the EU Charter
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-10

package complyedge.article5.biometric_categorisation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	biometric_pattern_match
}

biometric_pattern_match if {
	patterns := [
		"biometric[\\- ]?categori[sz]",
		"facial[\\- ]?classif.*race",
		"biometric.*infer.*(race|religion|politic|sexual|belief|union)",
		"emotion[\\- ]?recognition.*categori",
		"biometric.*profiling.*(race|religion|politic|sexual)",
		"facial.*recognition.*categoriz",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1g-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(g): Prohibits biometric categorisation systems that categorise natural persons based on their biometric data to deduce or infer their race, political opinions, trade union membership, religious or philosophical beliefs, sex life or sexual orientation."

severity := "critical"

remediation := "Remove any biometric categorisation that infers protected characteristics. If biometric processing is required, ensure it does not deduce race, religion, political views, sex life, or other prohibited categories."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
