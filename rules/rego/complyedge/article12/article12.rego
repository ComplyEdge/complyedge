# ComplyEdge — EU AI Act Article 12: Aggregated Record-Keeping Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article12.record_keeping (Art 12) — approved Leo Celis 2026-06-27

package complyedge.article12

import rego.v1

import data.complyedge.article12.record_keeping

default violation := false

violation if record_keeping.violation

violations contains v if {
	record_keeping.violation
	v := record_keeping.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [record_keeping.rule_id],
}
