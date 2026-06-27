# ComplyEdge — EU AI Act Annex XI 2(d)-(e): GPAI Energy & Compute Reporting
#
# Under Article 53(1)(a), GPAI technical documentation must include, at a
# minimum, Annex XI information — including computational resources used to
# train the model (point 2(d)) and known or estimated energy consumption
# (point 2(e)). Where energy consumption is unknown, it may be estimated from
# computational resources used.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(a), read with Annex XI, paragraph 2, points (d) and (e)
# Recital: 101 — GPAI providers must maintain technical documentation covering training process, evaluation results, and Annex XI minimum content including compute and energy metrics
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: There is no Article 53(1)(e) in the adopted Act — paragraph 1
# ends at (d). rule_id suffix 53e maps to Annex XI point 2(e) (energy
# consumption), not a separate Art 53 sub-paragraph. Art 53(5) delegates
# measurement methodology for Annex XI 2(d)-(e).

package complyedge.gpai.energy_reporting

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	energy_reporting_pattern_match
}

energy_reporting_pattern_match if {
	patterns := [
		"(?:gpai|general[\\- ]?purpose|foundation[\\- ]?model|llm).*(?:no|without|missing).*(?:energy[\\- ]?consumption|energy[\\- ]?use|computational[\\- ]?resources|training[\\- ]?compute)",
		"(?:no|without|missing).*(?:energy[\\- ]?consumption|known.*energy|estimated.*energy).*(?:document|report|disclos|record)",
		"(?:skip|omit|bypass).*(?:energy[\\- ]?consumption|computational[\\- ]?resources|training[\\- ]?compute|floating[\\- ]?point|flop)",
		"(?:undocumented|unreported).*(?:energy[\\- ]?consumption|computational[\\- ]?resources|training[\\- ]?time|training[\\- ]?compute)",
		"(?:technical[\\- ]?doc|model[\\- ]?card|annex[\\- ]?xi).*(?:no|without|missing).*(?:energy|computational[\\- ]?resources|training[\\- ]?compute|flop)",
		"(?:place|release|deploy).*(?:gpai|foundation[\\- ]?model).*(?:without|lacking).*(?:energy[\\- ]?consumption|computational[\\- ]?resources)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53e-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(a), read with Annex XI, paragraph 2, points (d) and (e): GPAI technical documentation must document computational resources used to train the model and known or estimated energy consumption (estimated from compute where actual energy use is unknown)."

severity := "high"

remediation := "Include computational resources used for training (e.g. floating-point operations, training time) and known or estimated energy consumption in Annex XI technical documentation. Where actual energy consumption is unknown, provide an estimate based on computational resources used."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
