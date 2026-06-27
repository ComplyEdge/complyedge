# ComplyEdge — EU AI Act Article 4: AI Literacy
#
# Providers and deployers of AI systems shall take measures to ensure a
# sufficient level of AI literacy of their staff and other persons dealing
# with the operation and use of AI systems on their behalf.
#
# Legal citation: Regulation (EU) 2024/1689, Article 4, paragraph 1
# Recital: 4 — providers and deployers must ensure staff and operators have sufficient AI literacy for the context of use
# Effective: 2025-02-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article4.ai_literacy

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	ai_literacy_pattern_match
}

ai_literacy_pattern_match if {
	patterns := [
		"(?:no|without|skip|omit|bypass).*(?:ai[\\- ]?literacy|ai[\\- ]?training|ai[\\- ]?competence).*(?:program|requirement|measure|staff|operator)?",
		"(?:deploy|roll[\\- ]?out|provide|use).*(?:ai|artificial[\\- ]?intelligence).*(?:without|lacking).*(?:staff|operator|employee).*(?:training|literacy|competence|education)",
		"(?:untrained|unqualified|inexperienced).*(?:staff|operators|employees|users).*(?:operat|using|deploy).*(?:ai|artificial[\\- ]?intelligence)",
		"(?:ai[\\- ]?literacy|article[\\- ]?4).*(?:not[\\- ]?met|ignored|skipped|omitted)",
		"(?:no|without).*(?:ai|artificial[\\- ]?intelligence).*(?:training|education|literacy).*(?:program|provided|required)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art4-1-001"

citation := "Regulation (EU) 2024/1689, Article 4, paragraph 1: Providers and deployers of AI systems shall take measures to ensure a sufficient level of AI literacy of their staff and other persons dealing with the operation and use of AI systems on their behalf."

severity := "medium"

remediation := "Implement an AI literacy programme proportionate to staff roles, context of use, and affected persons. Document training records and refresh as systems evolve."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
