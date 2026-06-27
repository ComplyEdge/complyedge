# ComplyEdge — EU AI Act Article 55(1)(b): GPAI Union-Level Systemic Risk Mitigation
#
# Providers of general-purpose AI models with systemic risk shall assess
# and mitigate possible systemic risks at Union level, including their
# sources, that may stem from the development, placing on the market, or
# use of such models.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(b)
# Recital: 114 — systemic-risk GPAI providers must assess and mitigate Union-level systemic risks from development, market placement, and use
# Effective: 2026-08-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Fills gap left when incident_reporting.rego (rego-gpai-55-1b-001)
# was assigned to Art 55(1)(c) per card checklist. This is the actual (b)
# obligation; seq 002 used because 001 is taken.

package complyedge.gpai.systemic_risk_mitigation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	systemic_risk_mitigation_pattern_match
}

systemic_risk_mitigation_pattern_match if {
	patterns := [
		"(?:no|without|skip|omit|bypass).*(?:systemic[\\- ]?risk).*(?:mitigat|assess|address).*(?:union|gpai|frontier|model|market)?",
		"(?:systemic[\\- ]?risk|frontier|gpai).*(?:without|no|unmitigated|unassessed).*(?:union[\\- ]?level|mitigat|assessment|systemic[\\- ]?risk[\\- ]?plan)",
		"(?:launch|release|deploy|place).*(?:systemic[\\- ]?risk|frontier).*(?:without|before).*(?:systemic[\\- ]?risk).*(?:mitigat|assess|evaluation)",
		"(?:unmitigated|unassessed).*(?:systemic[\\- ]?risk).*(?:union|gpai|frontier|model)",
		"(?:systemic[\\- ]?risk).*(?:not[\\- ]?(?:mitigated|assessed|addressed|evaluated)).*(?:union|gpai|frontier|market)?",
		"(?:skip|omit).*(?:union[\\- ]?level).*(?:systemic[\\- ]?risk).*(?:mitigat|assessment|analysis)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-55-1b-002"

citation := "Regulation (EU) 2024/1689, Article 55(1)(b): Providers of general-purpose AI models with systemic risk shall assess and mitigate possible systemic risks at Union level, including their sources, that may stem from the development, the placing on the market, or the use of general-purpose AI models with systemic risk."

severity := "critical"

remediation := "Assess Union-level systemic risks from development, market placement, and use of the GPAI model. Document sources of systemic risk and implement mitigation measures proportionate to identified Union-level impacts."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
