# ComplyEdge — EU AI Act Article 21: Aggregated Authority Cooperation

package complyedge.article21

import rego.v1

import data.complyedge.article21.authority_cooperation

default violation := false

violation if authority_cooperation.violation

violations contains v if {
	authority_cooperation.violation
	v := authority_cooperation.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [authority_cooperation.rule_id],
}
