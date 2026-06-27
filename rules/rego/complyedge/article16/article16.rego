# ComplyEdge — EU AI Act Article 16: Aggregated Provider Obligations

package complyedge.article16

import rego.v1

import data.complyedge.article16.provider_obligations

default violation := false

violation if provider_obligations.violation

violations contains v if {
	provider_obligations.violation
	v := provider_obligations.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [provider_obligations.rule_id],
}
