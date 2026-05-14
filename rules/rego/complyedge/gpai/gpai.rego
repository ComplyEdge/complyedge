# ComplyEdge — EU AI Act GPAI: Aggregated General-Purpose AI Check
#
# This policy aggregates all GPAI sub-checks and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/gpai

package complyedge.gpai

import rego.v1

import data.complyedge.gpai.model_classification
import data.complyedge.gpai.copyright_transparency
import data.complyedge.gpai.technical_documentation
import data.complyedge.gpai.systemic_risk
import data.complyedge.gpai.downstream_obligations

# True if ANY GPAI sub-rule is violated
default violation := false

violation if model_classification.violation
violation if copyright_transparency.violation
violation if technical_documentation.violation
violation if systemic_risk.violation
violation if downstream_obligations.violation

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
	],
}
