# ComplyEdge: EU AI Act Article 55: GPAI Systemic Risk
#
# Providers of general-purpose AI models with systemic risk shall
# perform model evaluations, assess and mitigate systemic risks,
# track and report serious incidents, and ensure adequate cybersecurity.
#
# Layer 1 detects: "systemic risk" (space, hyphen or one word), then the word
# "no", "not", "without" or "lack" (any ending), then assess, evaluat or mitigat; the
# word "no", "not", "without" or "lack" (any ending), then "systemic risk" written
# the same way, then assess or evaluat; "gpai" or "foundation model" (space,
# hyphen or one word), then systemic, then the word "no", "not" or "without", then
# mitigat or report; skip, bypass, omit or ignor, then "systemic risk"; and
# "high capability" or "frontier" (high capability with space, hyphen or one
# word), then model, then the word "no", "not" or "without", then risk followed later
# by assess, or "red team" (space, hyphen or one word). Case is ignored, the
# parts must sit on one line in the order given with any words between them,
# and a part not called a word can start inside a longer word. It matches
# wording, not meaning: it does not read the training compute or the
# designation ("Our 10^26 FLOP model goes public Friday; evals can wait." does
# not fire), and it fires on text that says the Article does not apply ("Our
# 2B model is not a systemic-risk model, so no systemic risk assessment is
# required." fires). Whether a provider of a model with systemic risk skips an
# Article 55(1) duty is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 114: model evaluation including adversarial testing, and assessment and mitigation of systemic risks. Recital 115 covers serious-incident tracking and reporting and cybersecurity protection of the model and its physical infrastructure. Recitals 116 and 117 cover codes of practice
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_55/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 55(1)

package complyedge.gpai.systemic_risk

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	systemic_risk_pattern_match
}

systemic_risk_pattern_match if {
	patterns := [
		"systemic[\\-\\s]?risk.*\\b(?:no|not|without|lack\\w*)\\b.*(?:assess|evaluat|mitigat)",
		"\\b(?:no|not|without|lack\\w*)\\b.*systemic[\\-\\s]?risk.*(?:assess|evaluat)",
		"(?:gpai|foundation[\\-\\s]?model).*systemic.*\\b(?:no|not|without)\\b.*(?:mitigat|report)",
		"(?:skip|bypass|omit|ignor).*systemic[\\-\\s]?risk",
		"(?:high[\\-\\s]?capability|frontier).*model.*\\b(?:no|not|without)\\b.*(?:risk.*assess|red[\\-\\s]?team)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-55-001"

citation := "Regulation (EU) 2024/1689, Article 55(1): In addition to the obligations listed in Articles 53 and 54, providers of general-purpose AI models with systemic risk shall: (a) perform model evaluation in accordance with standardised protocols and tools reflecting the state of the art, including conducting and documenting adversarial testing of the model with a view to identifying and mitigating systemic risks; (b) assess and mitigate possible systemic risks at Union level, including their sources, that may stem from the development, the placing on the market, or the use of general-purpose AI models with systemic risk; (c) keep track of, document, and report, without undue delay, to the AI Office and, as appropriate, to national competent authorities, relevant information about serious incidents and possible corrective measures to address them; (d) ensure an adequate level of cybersecurity protection for the general-purpose AI model with systemic risk and the physical infrastructure of the model."
severity := "critical"

remediation := "Conduct adversarial testing and red-teaming for systemic risks. Implement risk mitigation measures, establish incident tracking and reporting processes, and ensure cybersecurity protections are in place."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
