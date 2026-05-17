# ComplyEdge — EU AI Act Article 53(1)(b): GPAI Downstream Provider Information
#
# Providers of general-purpose AI models shall draw up, keep up-to-date
# and make available information and documentation to providers of AI
# systems who intend to integrate the general-purpose AI model into
# their AI systems. The information shall enable downstream providers to
# understand the capabilities and limitations of the GPAI model and to
# comply with their obligations under this Regulation; it shall contain,
# at a minimum, the elements set out in Annex XII.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(b)
# Recital: 102 — downstream providers integrating a GPAI model need sufficient information to understand its capabilities, limitations, and integration requirements in order to meet their own AI Act obligations
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
#
# Citation fix: this rule was previously cited as Art 53(1)(d). In the final
# adopted text of Regulation (EU) 2024/1689, downstream provider documentation
# is Art 53(1)(b) (with details in Annex XII); Art 53(1)(d) is the public
# training-data summary. Corrected 2026-05-16.

package complyedge.gpai.downstream_obligations

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	downstream_obligations_pattern_match
}

downstream_obligations_pattern_match if {
	patterns := [
		"downstream.*(?:no|without|lack).*(?:documentation|information|support)",
		"(?:no|without|lack).*downstream.*(?:provider|integrator).*(?:doc|info|guid)",
		"(?:gpai|foundation[\\- ]?model).*(?:no|without).*downstream.*(?:obligat|support)",
		"(?:api|model).*(?:no|without).*(?:integration[\\- ]?guid|usage[\\- ]?doc).*downstream",
		"(?:provid|distribut).*model.*(?:no|without).*(?:downstream|integrator).*(?:doc|guid|info)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53b-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(b): Providers of general-purpose AI models shall draw up, keep up-to-date and make available information and documentation to providers of AI systems who intend to integrate the GPAI model into their AI systems, enabling them to understand the model's capabilities and limitations and to comply with their obligations under this Regulation, containing at a minimum the elements set out in Annex XII."

severity := "high"

remediation := "Provide comprehensive documentation and integration guidance to downstream providers. Include model capabilities, limitations, intended use cases, and compliance requirements to enable downstream regulatory compliance."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
