# ComplyEdge — EU AI Act Article 27: Aggregated FRIA Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article27.fria (Art 27) — approved Leo Celis 2026-06-27

package complyedge.article27

import rego.v1

import data.complyedge.article27.fria

default violation := false

violation if fria.violation

violations contains v if {
	fria.violation
	v := fria.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [fria.rule_id],
}
