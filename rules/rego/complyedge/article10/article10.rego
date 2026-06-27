# ComplyEdge — EU AI Act Article 10: Aggregated Data Governance Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article10.data_governance (Art 10) — approved Leo Celis 2026-06-27

package complyedge.article10

import rego.v1

import data.complyedge.article10.data_governance

default violation := false

violation if data_governance.violation

violations contains v if {
	data_governance.violation
	v := data_governance.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [data_governance.rule_id],
}
