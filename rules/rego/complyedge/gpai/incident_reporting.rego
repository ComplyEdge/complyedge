# ComplyEdge — EU AI Act Article 55(1)(c): GPAI Serious Incident Reporting
#
# Providers of general-purpose AI models with systemic risk shall keep
# track of, document, and report, without undue delay, to the AI Office
# and, as appropriate, to national competent authorities, relevant
# information about serious incidents and possible corrective measures
# to address them.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(c)
# Recital: 114 — systemic-risk GPAI providers must track, document, and report serious incidents to the AI Office without undue delay, including corrective measures
# Effective: 2026-08-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Card item labeled Art 55(1)(b); adopted Act places serious
# incident reporting at Art 55(1)(c). Actual (b) is Union-level systemic
# risk assessment/mitigation. rule_id suffix 55-1b-001 follows card checklist.

package complyedge.gpai.incident_reporting

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	incident_reporting_pattern_match
}

incident_reporting_pattern_match if {
	patterns := [
		"(?:no|without|fail(?:ed|ing|s)?|never).*(?:report|notif).*(?:serious[\\- ]?incident|ai office|incident).*(?:ai office|authorit|commission)",
		"(?:serious[\\- ]?incident).*(?:not[\\- ]?report|unreport|undocument|undisclosed|withheld|conceal)",
		"(?:no|without|skip|omit).*(?:incident[\\- ]?track|incident[\\- ]?report|serious[\\- ]?incident).*(?:process|system|procedure|log)",
		"(?:delay|withhold|conceal|hide).*(?:serious[\\- ]?incident).*(?:from|to).*(?:ai office|authorit|commission|national)",
		"(?:systemic[\\- ]?risk|frontier|gpai).*(?:without|no).*(?:incident[\\- ]?report|track.*incident|document.*incident)",
		"(?:undocumented|unreported).*(?:serious[\\- ]?incident).*(?:corrective[\\- ]?measure|gpai|systemic[\\- ]?risk)",
		"(?:skip|bypass).*(?:reporting|notification).*(?:serious[\\- ]?incident|ai office)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-55-1b-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(c): Providers of general-purpose AI models with systemic risk shall keep track of, document, and report, without undue delay, to the AI Office and, as appropriate, to national competent authorities, relevant information about serious incidents and possible corrective measures to address them."

severity := "critical"

remediation := "Establish incident tracking and documentation processes. Report serious incidents and proposed corrective measures to the AI Office without undue delay, and to national competent authorities where appropriate."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
