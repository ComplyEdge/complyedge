# ComplyEdge — EU AI Act Article 55(1)(a): GPAI Adversarial Model Evaluation
#
# Providers of general-purpose AI models with systemic risk shall perform
# model evaluation in accordance with standardised protocols and tools
# reflecting the state of the art, including conducting and documenting
# adversarial testing of the model with a view to identifying and
# mitigating systemic risks.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(a)
# Recital: 114 — systemic-risk GPAI providers must perform standardised model evaluation including adversarial testing to identify and mitigate systemic risks at Union level
# Effective: 2026-08-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Art 55(1)(a) is the adversarial model-evaluation obligation only.
# systemic_risk.rego (rego-gpai-55-001) enforces Art 55 holistically; this
# rule narrows to paragraph 1(a). Art 55(1)(b)-(d) are separate rules.

package complyedge.gpai.systemic_risk_assessment

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	systemic_risk_assessment_pattern_match
}

systemic_risk_assessment_pattern_match if {
	patterns := [
		"(?:no|without|skip|omit|bypass).*(?:adversarial[\\- ]?test|red[\\- ]?team|redteam)",
		"(?:adversarial[\\- ]?test|red[\\- ]?team).*(?:not[\\- ]?(?:conduct|perform|run|document)|undocument|unconduct)",
		"(?:systemic[\\- ]?risk|frontier|high[\\- ]?impact).*(?:gpai|model).*(?:without|no|skip).*(?:adversarial|red[\\- ]?team|model[\\- ]?evaluat)",
		"(?:launch|release|deploy).*(?:systemic[\\- ]?risk|frontier).*(?:without|before).*(?:adversarial[\\- ]?test|red[\\- ]?team|standardi[sz]ed.*evaluat)",
		"(?:no|without|skip).*(?:standardi[sz]ed.*protocol|state[\\- ]?of[\\- ]?the[\\- ]?art).*(?:model[\\- ]?evaluat|adversarial)",
		"(?:undocumented|unconducted).*(?:adversarial[\\- ]?test|red[\\- ]?team|model[\\- ]?evaluat).*(?:systemic[\\- ]?risk|gpai|foundation)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-55-1a-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(a): Providers of general-purpose AI models with systemic risk shall perform model evaluation in accordance with standardised protocols and tools reflecting the state of the art, including conducting and documenting adversarial testing of the model with a view to identifying and mitigating systemic risks."

severity := "critical"

remediation := "Perform model evaluation using standardised state-of-the-art protocols. Conduct and document adversarial testing and red-teaming to identify systemic risks before placing the model on the market."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
