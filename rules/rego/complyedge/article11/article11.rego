# ComplyEdge — EU AI Act Article 11: Aggregated Technical Documentation Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article11.technical_documentation (Art 11) — approved Leo Celis 2026-06-27

package complyedge.article11

import rego.v1

import data.complyedge.article11.technical_documentation

default violation := false

violation if technical_documentation.violation

violations contains v if {
	technical_documentation.violation
	v := technical_documentation.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [technical_documentation.rule_id],
}
