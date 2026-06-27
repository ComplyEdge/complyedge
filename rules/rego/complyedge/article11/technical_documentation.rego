# ComplyEdge — EU AI Act Article 11: High-Risk Technical Documentation
#
# Before a high-risk AI system is placed on the market or put into service,
# the provider shall draw up the technical documentation of the system in
# accordance with Annex IV, demonstrating compliance with Chapter III
# Section 2 requirements and providing authorities with necessary information.
#
# Legal citation: Regulation (EU) 2024/1689, Article 11, paragraph 1
# Recital: 67 — high-risk AI providers must prepare Annex IV technical documentation before market placement to demonstrate conformity
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Distinct from gpai/technical_documentation.rego (Art 53(1)(a)
# GPAI model documentation per Annex XI). This rule covers high-risk AI
# systems under Art 11 / Annex IV.

package complyedge.article11.technical_documentation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	technical_documentation_pattern_match
}

technical_documentation_pattern_match if {
	patterns := [
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|missing).*(?:technical[\\- ]?doc|annex[\\- ]?iv|conformity[\\- ]?doc)",
		"(?:place|put|deploy|release|launch|market).*(?:high[\\- ]?risk).*(?:without|before|no).*(?:technical[\\- ]?doc|annex[\\- ]?iv)",
		"(?:without|no|skip|omit|bypass).*(?:technical[\\- ]?documentation|annex[\\- ]?iv).*(?:high[\\- ]?risk|before[\\- ]?market|market[\\- ]?placement)",
		"(?:technical[\\- ]?documentation).*(?:not[\\- ]?(?:drawn|prepared|completed|available|maintained))",
		"(?:undocumented|no[\\- ]?doc).*(?:high[\\- ]?risk).*(?:ai|system|deployment|market)",
		"(?:annex[\\- ]?iv).*(?:not[\\- ]?(?:prepared|completed|drawn|available))",
		"(?:skip|omit).*(?:technical[\\- ]?doc|conformity[\\- ]?documentation).*(?:high[\\- ]?risk|market)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art11-1-001"

citation := "Regulation (EU) 2024/1689, Article 11, paragraph 1: Before a high-risk AI system is placed on the market or put into service, the provider shall draw up the technical documentation of the system in accordance with Annex IV."

severity := "high"

remediation := "Prepare complete Annex IV technical documentation before placing the high-risk AI system on the market or putting it into service. Documentation must demonstrate compliance with Chapter III Section 2 and enable authorities to assess conformity."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
