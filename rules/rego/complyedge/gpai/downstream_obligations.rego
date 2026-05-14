# ComplyEdge — EU AI Act Article 53(d): GPAI Downstream Obligations
#
# Providers of general-purpose AI models shall provide sufficient
# information and documentation to downstream providers to enable
# them to comply with their obligations under the regulation.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(d)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

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

rule_id := "rego-gpai-53d-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(d): Providers of GPAI models shall provide sufficient information and documentation to downstream providers to enable compliance with regulatory obligations."

severity := "high"

remediation := "Provide comprehensive documentation and integration guidance to downstream providers. Include model capabilities, limitations, intended use cases, and compliance requirements to enable downstream regulatory compliance."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
