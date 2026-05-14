# ComplyEdge — EU AI Act Article 52: GPAI Technical Documentation
#
# Providers of general-purpose AI models shall draw up and keep
# up-to-date technical documentation of the model, including training
# and testing processes and evaluation results.
#
# Legal citation: Regulation (EU) 2024/1689, Article 52
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

package complyedge.gpai.technical_documentation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	technical_documentation_pattern_match
}

technical_documentation_pattern_match if {
	patterns := [
		"(?:gpai|general[\\- ]?purpose.*model).*(?:no|without|lack).*(?:technical[\\- ]?doc|model[\\- ]?card)",
		"(?:no|without|lack).*technical[\\- ]?documentation.*(?:gpai|foundation|general[\\- ]?purpose)",
		"(?:undocumented|no.*documentation).*(?:training|evaluation).*(?:process|result)",
		"deploy.*model.*(?:no|without).*(?:model[\\- ]?card|technical[\\- ]?doc)",
		"(?:skip|omit|bypass).*(?:technical[\\- ]?doc|model[\\- ]?documentation)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-52-001"

citation := "Regulation (EU) 2024/1689, Article 52: Providers of GPAI models shall draw up and maintain up-to-date technical documentation including training and testing processes and evaluation results."

severity := "high"

remediation := "Create and maintain comprehensive technical documentation for the GPAI model, including training methodology, testing processes, evaluation results, and a model card. Keep documentation up-to-date."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
