# ComplyEdge — EU AI Act Article 4: Aggregated AI Literacy Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.

package complyedge.article4

import rego.v1

import data.complyedge.article4.ai_literacy

default violation := false

violation if ai_literacy.violation

violations contains v if {
	ai_literacy.violation
	v := ai_literacy.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [ai_literacy.rule_id],
}
