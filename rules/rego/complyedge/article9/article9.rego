# ComplyEdge — EU AI Act Article 9: Aggregated High-Risk Provider Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article9.risk_management_system (Art 9) — approved Leo Celis 2026-06-27

package complyedge.article9

import rego.v1

import data.complyedge.article9.risk_management_system

default violation := false

violation if risk_management_system.violation

violations contains v if {
	risk_management_system.violation
	v := risk_management_system.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [risk_management_system.rule_id],
}
