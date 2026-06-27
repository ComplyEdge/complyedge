# ComplyEdge — EU AI Act Article 14: Aggregated Human Oversight Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article14.human_oversight (Art 14) — approved Leo Celis 2026-06-27

package complyedge.article14

import rego.v1

import data.complyedge.article14.human_oversight

default violation := false

violation if human_oversight.violation

violations contains v if {
	human_oversight.violation
	v := human_oversight.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [human_oversight.rule_id],
}
