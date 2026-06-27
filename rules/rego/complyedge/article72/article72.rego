# ComplyEdge — EU AI Act Article 72: Aggregated Post-Market Monitoring

package complyedge.article72

import rego.v1

import data.complyedge.article72.post_market_monitoring

default violation := false

violation if post_market_monitoring.violation

violations contains v if {
	post_market_monitoring.violation
	v := post_market_monitoring.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [post_market_monitoring.rule_id],
}
