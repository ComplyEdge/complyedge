# ComplyEdge — EU AI Act Article 13: Aggregated Deployer Transparency Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article13.transparency_deployers (Art 13) — approved Leo Celis 2026-06-27

package complyedge.article13

import rego.v1

import data.complyedge.article13.transparency_deployers

default violation := false

violation if transparency_deployers.violation

violations contains v if {
	transparency_deployers.violation
	v := transparency_deployers.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [transparency_deployers.rule_id],
}
