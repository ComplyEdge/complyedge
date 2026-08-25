# ComplyEdge — US corpus aggregator (SOX / HIPAA / TCPA)
#
# OPA queries this package at: POST /v1/data/complyedge/us_corpus/result
# Aggregator carve-out (RULE_STANDARD.md §5.6): no legal condition of its own.

package complyedge.us_corpus

import rego.v1

import data.complyedge.us_corpus.sox_material_disclosure

default violation := false

violation if sox_material_disclosure.violation

violations contains v if {
	sox_material_disclosure.violation
	v := sox_material_disclosure.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [sox_material_disclosure.rule_id],
}
