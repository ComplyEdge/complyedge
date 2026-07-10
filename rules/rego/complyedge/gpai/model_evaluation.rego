# ComplyEdge — EU AI Act Article 55(1)(a): Model Evaluation
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(a)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.gpai.model_evaluation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"systemic[\\-\\s]?risk\\s+(?:gpai|model)\\s+(?:without|no)\\s+(?:model\\s+evaluation|adversarial\\s+test|red[\\-\\s]?team)",
		"(?:deploy|release)\\w*\\s+systemic[\\-\\s]?risk\\s+model\\s+without\\s+(?:adversarial\\s+testing|red[\\-\\s]?teaming|model\\s+evaluation)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1a-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(a): Providers of GPAI models with systemic risk must perform model evaluation, including adversarial testing to identify and mitigate systemic risks."

severity := "high"

remediation := "Perform state-of-the-art model evaluation and adversarial testing for GPAI models with systemic risk."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
