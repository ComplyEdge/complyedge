# ComplyEdge — EU AI Act Article 55(1)(d): GPAI Cybersecurity Protection
#
# Providers of general-purpose AI models with systemic risk shall ensure
# an adequate level of cybersecurity protection for the general-purpose
# AI model with systemic risk and the physical infrastructure of the model.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(d)
# Recital: 114 — systemic-risk GPAI providers must ensure adequate cybersecurity for the model and its physical infrastructure, including protection of model weights and compute infrastructure
# Effective: 2026-08-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Card item labeled Art 55(1)(c); adopted Act places cybersecurity
# at Art 55(1)(d). rule_id suffix 55-1c-001 follows card checklist.

package complyedge.gpai.cybersecurity_measures

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	cybersecurity_measures_pattern_match
}

cybersecurity_measures_pattern_match if {
	patterns := [
		"(?:no|without|inadequate|insufficient|lack).*(?:cybersecurity|cyber[\\- ]?security).*(?:protect|measure|control|safeguard).*(?:gpai|systemic[\\- ]?risk|model|infrastructure)",
		"(?:systemic[\\- ]?risk|frontier|gpai|foundation[\\- ]?model).*(?:without|no|inadequate).*(?:cybersecurity|cyber[\\- ]?security|security[\\- ]?protect)",
		"(?:skip|omit|bypass).*(?:cybersecurity|security[\\- ]?protect|model[\\- ]?weight[\\- ]?protect).*(?:gpai|systemic[\\- ]?risk|frontier)",
		"(?:unprotected|unsecured).*(?:model[\\- ]?weight|physical[\\- ]?infrastructure|training[\\- ]?infrastructure).*(?:gpai|systemic[\\- ]?risk|frontier)",
		"(?:deploy|release|operate).*(?:systemic[\\- ]?risk|frontier).*(?:without|before).*(?:cybersecurity|security[\\- ]?harden|infrastructure[\\- ]?protect)",
		"(?:no|without).*(?:protection|hardening).*(?:physical[\\- ]?infrastructure|compute[\\- ]?cluster|model[\\- ]?weight).*(?:gpai|systemic[\\- ]?risk)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-55-1c-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(d): Providers of general-purpose AI models with systemic risk shall ensure an adequate level of cybersecurity protection for the general-purpose AI model with systemic risk and the physical infrastructure of the model."

severity := "critical"

remediation := "Implement adequate cybersecurity protections for the systemic-risk GPAI model and its physical infrastructure, including safeguards for model weights, compute clusters, and related deployment infrastructure."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
