# ComplyEdge — EU AI Act Article 13: Transparency and Instructions for Deployers
#
# High-risk AI systems shall be designed and developed to ensure sufficiently
# transparent operation, enabling deployers to interpret output and use the
# system appropriately. Instructions for use shall include concise, complete,
# correct and clear information on capabilities, limitations, accuracy levels,
# and human oversight measures.
#
# Legal citation: Regulation (EU) 2024/1689, Article 13, paragraph 1
# Recital: 69 — high-risk AI must be transparent to deployers with instructions covering capabilities, limitations, and oversight
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article13.transparency_deployers

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	transparency_deployers_pattern_match
}

transparency_deployers_pattern_match if {
	patterns := [
		"(?:without|no|missing|skip|omit).*(?:transparency|instructions?[\\- ]?for[\\- ]?use|deployer[\\- ]?(?:information|documentation|instructions))",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|missing).*(?:instructions?[\\- ]?for[\\- ]?use|deployer[\\- ]?(?:info|documentation|transparency))",
		"(?:deploy|supply|deliver|provide).*(?:high[\\- ]?risk).*(?:without|no).*(?:transparency|documentation|instructions?[\\- ]?for[\\- ]?use)",
		"(?:opaque|black[\\- ]?box).*(?:ai|system|model|decision|deployment).*(?:high[\\- ]?risk|deployer|without[\\- ]?transparency)",
		"(?:high[\\- ]?risk).*(?:opaque|black[\\- ]?box).*(?:ai|system|model|deployment)",
		"(?:undisclosed|hidden|concealed).*(?:limitation|capability|accuracy|performance|bias).*(?:high[\\- ]?risk|deployer|ai[\\- ]?system)",
		"(?:no|without).*(?:accuracy|robustness|performance).*(?:level|information|disclosure).*(?:deployer|high[\\- ]?risk|instructions?[\\- ]?for[\\- ]?use)",
		"(?:transparency|instructions?[\\- ]?for[\\- ]?use).*(?:not[\\- ]?(?:provided|documented|required|included|supplied))",
		"(?:article[\\- ]?13|art\\.?\\s*13).*(?:not[\\- ]?met|ignored|skipped|bypassed|omitted)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art13-1-001"

citation := "Regulation (EU) 2024/1689, Article 13, paragraph 1: High-risk AI systems shall be designed and developed in such a way as to ensure that their operation is sufficiently transparent to enable deployers to interpret a system's output and use it appropriately, with instructions for use covering capabilities, limitations, accuracy, and human oversight measures."

severity := "high"

remediation := "Provide deployers with transparent high-risk AI operation and complete instructions for use: provider identity, system characteristics, intended purpose, accuracy and robustness levels, known performance-affecting circumstances, expected lifetime, maintenance, and human oversight measures including technical aids for output interpretation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
