# ComplyEdge — EU AI Act GPAI (Articles 51-55): Aggregated Check
#
# Aggregates all sub-rules in this package and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/gpai
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports and combines other
# rules' violation results — no legal condition of its own. Correctness derives
# from the imported sub-rules, each individually subject to §5 sign-off.

package complyedge.gpai

import rego.v1

import data.complyedge.gpai.copyright_transparency
import data.complyedge.gpai.cybersecurity_gpai
import data.complyedge.gpai.downstream_obligations
import data.complyedge.gpai.incident_reporting
import data.complyedge.gpai.model_classification
import data.complyedge.gpai.model_evaluation
import data.complyedge.gpai.risk_mitigation
import data.complyedge.gpai.sr_designation
import data.complyedge.gpai.systemic_risk
import data.complyedge.gpai.technical_documentation
import data.complyedge.gpai.training_summary

default violation := false

violation if copyright_transparency.violation
violation if cybersecurity_gpai.violation
violation if downstream_obligations.violation
violation if incident_reporting.violation
violation if model_classification.violation
violation if model_evaluation.violation
violation if risk_mitigation.violation
violation if sr_designation.violation
violation if systemic_risk.violation
violation if technical_documentation.violation
violation if training_summary.violation

violations contains v if {
	copyright_transparency.violation
	v := copyright_transparency.result
}

violations contains v if {
	cybersecurity_gpai.violation
	v := cybersecurity_gpai.result
}

violations contains v if {
	downstream_obligations.violation
	v := downstream_obligations.result
}

violations contains v if {
	incident_reporting.violation
	v := incident_reporting.result
}

violations contains v if {
	model_classification.violation
	v := model_classification.result
}

violations contains v if {
	model_evaluation.violation
	v := model_evaluation.result
}

violations contains v if {
	risk_mitigation.violation
	v := risk_mitigation.result
}

violations contains v if {
	sr_designation.violation
	v := sr_designation.result
}

violations contains v if {
	systemic_risk.violation
	v := systemic_risk.result
}

violations contains v if {
	technical_documentation.violation
	v := technical_documentation.result
}

violations contains v if {
	training_summary.violation
	v := training_summary.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		copyright_transparency.rule_id,
		cybersecurity_gpai.rule_id,
		downstream_obligations.rule_id,
		incident_reporting.rule_id,
		model_classification.rule_id,
		model_evaluation.rule_id,
		risk_mitigation.rule_id,
		sr_designation.rule_id,
		systemic_risk.rule_id,
		technical_documentation.rule_id,
		training_summary.rule_id,
	],
}
