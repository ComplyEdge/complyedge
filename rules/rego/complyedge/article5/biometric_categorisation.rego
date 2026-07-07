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
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5; carve-outs + `/v1/check` plumbing)

package complyedge.article5.biometric_categorisation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	biometric_pattern_match
	not law_enforcement_exception
	not dataset_operation_exception
}

# Article 5(1)(g) OJ carve-out: the prohibition does NOT cover
# categorizing of biometric data in the area of law enforcement when the
# caller asserts a lawful basis. Both `use_case` and `lawful_basis` must
# be present in the input for the exception to fire.
law_enforcement_exception if {
	input.use_case == "law_enforcement"
	input.lawful_basis == true
}

# Article 5(1)(g) OJ carve-out: dataset *labelling* and
# *filtering* of lawfully acquired biometric datasets is excluded — that
# is data preparation, not categorisation of natural persons.
dataset_operation_exception if {
	input.dataset_operation in {"labelling", "filtering"}
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

citation := "Regulation (EU) 2024/1689, Article 5(1)(g): Prohibits biometric categorisation systems that categorise natural persons based on their biometric data to deduce or infer their race, political opinions, trade union membership, religious or philosophical beliefs, sex life or sexual orientation. Exception per OJ text: this prohibition does not cover labelling or filtering of lawfully acquired biometric datasets, or categorizing of biometric data in the area of law enforcement (subject to a lawful basis)."

severity := "critical"

remediation := "Remove any biometric categorisation that infers protected characteristics. If biometric processing is required, ensure it does not deduce race, religion, political views, sex life, or other prohibited categories."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
