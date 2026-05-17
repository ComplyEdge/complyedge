# ComplyEdge — EU AI Act Article 53(1)(a): GPAI Technical Documentation
#
# Providers of general-purpose AI models shall draw up and keep up-to-date
# the technical documentation of the model, including its training and
# testing process and the results of its evaluation, which shall contain,
# at a minimum, the information set out in Annex XI for the purpose of
# providing it, upon request, to the AI Office and the national competent
# authorities.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(a)
# Recital: 101 — GPAI providers must document model details (training process, testing, evaluation results, Annex XI minimum content) to support enforcement by the AI Office and national authorities
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
#
# Citation fix: this rule was previously cited as Art 52. In the final adopted
# text of Regulation (EU) 2024/1689, Art 52 is the notification procedure for
# GPAI models with systemic risk; the technical documentation obligation is
# Art 53(1)(a). Corrected 2026-05-16.

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

rule_id := "rego-gpai-53a-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(a): Providers of general-purpose AI models shall draw up and keep up-to-date the technical documentation of the model, including its training and testing process and the results of its evaluation, which shall contain, at a minimum, the information set out in Annex XI."

severity := "high"

remediation := "Create and maintain comprehensive technical documentation for the GPAI model, including training methodology, testing processes, evaluation results, and a model card. Keep documentation up-to-date."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
