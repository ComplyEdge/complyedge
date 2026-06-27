# ComplyEdge — EU AI Act Article 26: Aggregated Deployer Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article26.deployer_obligations (Art 26) — approved Leo Celis 2026-06-27

package complyedge.article26

import rego.v1

import data.complyedge.article26.deployer_obligations

default violation := false

violation if deployer_obligations.violation

violations contains v if {
	deployer_obligations.violation
	v := deployer_obligations.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [deployer_obligations.rule_id],
}
