# ComplyEdge: EU AI Act Article 55(1)(a): Model Evaluation
#
# A general-purpose AI model with systemic risk released or run without model
# evaluation, adversarial testing or red-teaming.
#
# Layer 1 detects: as adjacent words, "systemic risk" (also "systemic-risk"),
# then gpai or model, then without or no, then "model evaluation",
# "adversarial test" or "red team" (also "red-team", any ending); and deploy
# or release (any ending), then "systemic risk", then "model" (singular), then
# "without", then "adversarial testing", "red teaming" or "model evaluation".
# It matches wording, not meaning: it misses a release without evaluation told
# in other words, and it fires on text that only names it, such as a refusal.
# Whether a model with systemic risk is placed on the market or used without
# the required evaluation is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(a)
# Recital: 114: providers of models with systemic risk should perform the necessary model evaluations, in particular before first placing on the market, including conducting and documenting adversarial testing
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_55/par_1/pnt_a/oj
# Provision: Regulation (EU) 2024/1689, Article 55(1)(a)

package complyedge.gpai.model_evaluation

import rego.v1

import data.complyedge.shared.normalize

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

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1a-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(a): In addition to the obligations listed in Articles 53 and 54, providers of general-purpose AI models with systemic risk shall: ... (a) perform model evaluation in accordance with standardised protocols and tools reflecting the state of the art, including conducting and documenting adversarial testing of the model with a view to identifying and mitigating systemic risks;"

severity := "high"

remediation := "Perform model evaluation in accordance with standardised protocols and tools reflecting the state of the art, including conducting and documenting adversarial testing, for GPAI models with systemic risk."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
