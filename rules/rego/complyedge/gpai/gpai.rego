# ComplyEdge — EU AI Act GPAI: Aggregated General-Purpose AI Check
#
# This policy aggregates all GPAI sub-checks and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/gpai
#
# Aggregator carve-out (RULE_STANDARD.md §5.6, added v1.1):
# This file imports and combines other rules' violation results — it has no
# legal condition of its own. Exempt from §5 approval headers. Correctness
# derives from the correctness of the imported sub-rules, each of which is
# individually subject to §5 sign-off.
#
# Imported rules covered by individual §5 approvals:
#   - gpai.model_classification (Art 51) — approved by Leo Celis 2026-05-16 (agent review)
#   - gpai.copyright_transparency (Art 53(1)(c)) — approved by Leo Celis 2026-05-16 (agent review)
#   - gpai.technical_documentation (Art 53(1)(a)) — approved by Leo Celis 2026-05-16 (agent review)
#   - gpai.systemic_risk (Art 55) — approved by Leo Celis 2026-05-16 (agent review)
#   - gpai.downstream_obligations (Art 53(1)(b)) — approved by Leo Celis 2026-05-16 (agent review)
#   - gpai.training_data_disclosure (Art 53(1)(d)) — approved by Leo Celis 2026-06-27 (agent review)
#   - gpai.energy_reporting (Annex XI 2(d)-(e) / Art 53(1)(a)) — approved by Leo Celis 2026-06-27 (agent review)
#   - gpai.transparency_summary (Art 52 notification procedure) — approved by Leo Celis 2026-06-27 (agent review)
#   - gpai.systemic_risk_assessment (Art 55(1)(a)) — approved by Leo Celis 2026-06-27 (agent review)
#   - gpai.incident_reporting (Art 55(1)(c)) — approved by Leo Celis 2026-06-27 (agent review)
#   - gpai.cybersecurity_measures (Art 55(1)(d)) — approved by Leo Celis 2026-06-27 (agent review)
#   - gpai.provider_cooperation (Art 53(3)) — approved Leo Celis 2026-06-27
#   - gpai.systemic_risk_mitigation (Art 55(1)(b)) — approved Leo Celis 2026-06-27

package complyedge.gpai

import rego.v1

import data.complyedge.gpai.model_classification
import data.complyedge.gpai.copyright_transparency
import data.complyedge.gpai.technical_documentation
import data.complyedge.gpai.systemic_risk
import data.complyedge.gpai.downstream_obligations
import data.complyedge.gpai.training_data_disclosure
import data.complyedge.gpai.energy_reporting
import data.complyedge.gpai.transparency_summary
import data.complyedge.gpai.systemic_risk_assessment
import data.complyedge.gpai.incident_reporting
import data.complyedge.gpai.cybersecurity_measures
import data.complyedge.gpai.provider_cooperation
import data.complyedge.gpai.systemic_risk_mitigation

# True if ANY GPAI sub-rule is violated
default violation := false

violation if model_classification.violation
violation if copyright_transparency.violation
violation if technical_documentation.violation
violation if systemic_risk.violation
violation if downstream_obligations.violation
violation if training_data_disclosure.violation
violation if energy_reporting.violation
violation if transparency_summary.violation
violation if systemic_risk_assessment.violation
violation if incident_reporting.violation
violation if cybersecurity_measures.violation
violation if provider_cooperation.violation
violation if systemic_risk_mitigation.violation

# Collect all triggered violations into an array
violations contains v if {
	model_classification.violation
	v := model_classification.result
}

violations contains v if {
	copyright_transparency.violation
	v := copyright_transparency.result
}

violations contains v if {
	technical_documentation.violation
	v := technical_documentation.result
}

violations contains v if {
	systemic_risk.violation
	v := systemic_risk.result
}

violations contains v if {
	downstream_obligations.violation
	v := downstream_obligations.result
}

violations contains v if {
	training_data_disclosure.violation
	v := training_data_disclosure.result
}

violations contains v if {
	energy_reporting.violation
	v := energy_reporting.result
}

violations contains v if {
	transparency_summary.violation
	v := transparency_summary.result
}

violations contains v if {
	systemic_risk_assessment.violation
	v := systemic_risk_assessment.result
}

violations contains v if {
	incident_reporting.violation
	v := incident_reporting.result
}

violations contains v if {
	cybersecurity_measures.violation
	v := cybersecurity_measures.result
}

violations contains v if {
	provider_cooperation.violation
	v := provider_cooperation.result
}

violations contains v if {
	systemic_risk_mitigation.violation
	v := systemic_risk_mitigation.result
}

# Summary result for the OPA client
result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		model_classification.rule_id,
		copyright_transparency.rule_id,
		technical_documentation.rule_id,
		systemic_risk.rule_id,
		downstream_obligations.rule_id,
		training_data_disclosure.rule_id,
		energy_reporting.rule_id,
		transparency_summary.rule_id,
		systemic_risk_assessment.rule_id,
		incident_reporting.rule_id,
		cybersecurity_measures.rule_id,
		provider_cooperation.rule_id,
		systemic_risk_mitigation.rule_id,
	],
}
