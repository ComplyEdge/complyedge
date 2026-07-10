# ComplyEdge — EU AI Act High-Risk Requirements (Articles 4, 9-16, 26, 27): Aggregated Check
#
# Aggregates all sub-rules in this package and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/highrisk
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports and combines other
# rules' violation results — no legal condition of its own. Correctness derives
# from the imported sub-rules, each individually subject to §5 sign-off.

package complyedge.highrisk

import rego.v1

import data.complyedge.highrisk.art10_data_governance
import data.complyedge.highrisk.art11_technical_documentation
import data.complyedge.highrisk.art12_record_keeping
import data.complyedge.highrisk.art13_transparency
import data.complyedge.highrisk.art14_human_oversight
import data.complyedge.highrisk.art15_accuracy
import data.complyedge.highrisk.art15_cybersecurity
import data.complyedge.highrisk.art15_robustness
import data.complyedge.highrisk.art16_provider_obligations
import data.complyedge.highrisk.art26_deployer_obligations
import data.complyedge.highrisk.art27_fria
import data.complyedge.highrisk.art4_ai_literacy
import data.complyedge.highrisk.art9_risk_management

default violation := false

violation if art10_data_governance.violation
violation if art11_technical_documentation.violation
violation if art12_record_keeping.violation
violation if art13_transparency.violation
violation if art14_human_oversight.violation
violation if art15_accuracy.violation
violation if art15_cybersecurity.violation
violation if art15_robustness.violation
violation if art16_provider_obligations.violation
violation if art26_deployer_obligations.violation
violation if art27_fria.violation
violation if art4_ai_literacy.violation
violation if art9_risk_management.violation

violations contains v if {
	art10_data_governance.violation
	v := art10_data_governance.result
}

violations contains v if {
	art11_technical_documentation.violation
	v := art11_technical_documentation.result
}

violations contains v if {
	art12_record_keeping.violation
	v := art12_record_keeping.result
}

violations contains v if {
	art13_transparency.violation
	v := art13_transparency.result
}

violations contains v if {
	art14_human_oversight.violation
	v := art14_human_oversight.result
}

violations contains v if {
	art15_accuracy.violation
	v := art15_accuracy.result
}

violations contains v if {
	art15_cybersecurity.violation
	v := art15_cybersecurity.result
}

violations contains v if {
	art15_robustness.violation
	v := art15_robustness.result
}

violations contains v if {
	art16_provider_obligations.violation
	v := art16_provider_obligations.result
}

violations contains v if {
	art26_deployer_obligations.violation
	v := art26_deployer_obligations.result
}

violations contains v if {
	art27_fria.violation
	v := art27_fria.result
}

violations contains v if {
	art4_ai_literacy.violation
	v := art4_ai_literacy.result
}

violations contains v if {
	art9_risk_management.violation
	v := art9_risk_management.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		art10_data_governance.rule_id,
		art11_technical_documentation.rule_id,
		art12_record_keeping.rule_id,
		art13_transparency.rule_id,
		art14_human_oversight.rule_id,
		art15_accuracy.rule_id,
		art15_cybersecurity.rule_id,
		art15_robustness.rule_id,
		art16_provider_obligations.rule_id,
		art26_deployer_obligations.rule_id,
		art27_fria.rule_id,
		art4_ai_literacy.rule_id,
		art9_risk_management.rule_id,
	],
}
