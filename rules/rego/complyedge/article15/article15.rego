# ComplyEdge — EU AI Act Article 15: Aggregated Accuracy and Robustness Obligations
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports sub-rule violation
# results only. Exempt from §5 approval headers.
#
# Imported rules:
#   - article15.accuracy_robustness (Art 15) — approved Leo Celis 2026-06-27

package complyedge.article15

import rego.v1

import data.complyedge.article15.accuracy_robustness

default violation := false

violation if accuracy_robustness.violation

violations contains v if {
	accuracy_robustness.violation
	v := accuracy_robustness.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [accuracy_robustness.rule_id],
}
