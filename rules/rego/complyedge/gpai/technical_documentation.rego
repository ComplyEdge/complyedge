# ComplyEdge: EU AI Act Article 53(1)(a): GPAI Technical Documentation
#
# Providers of general-purpose AI models shall draw up and keep up-to-date
# the technical documentation of the model, including its training and
# testing process and the results of its evaluation, which shall contain,
# at a minimum, the information set out in Annex XI for the purpose of
# providing it, upon request, to the AI Office and the national competent
# authorities.
#
# Layer 1 detects: "gpai", or "general purpose" (space, hyphen or one word)
# followed later by model, then the word "no", "not", "without" or "lack" (any
# ending), then "technical doc" or "model card" (space, hyphen or one word);
# the word "no", "not", "without" or "lack" (any ending), then "technical
# documentation" (space, hyphen or one word), then gpai, foundation or
# "general purpose"; "undocumented", or the word "no" or "not" followed later by
# documentation, then training or evaluation, then process or result; deploy,
# then model, then the word "no", "not" or "without", then "model card" or "technical
# doc"; and skip, omit or bypass, then "technical doc" or "model
# documentation" (space, hyphen or one word). Case is ignored, the parts must
# sit on one line in the order given with any words between them, and a part
# not called a word can start inside a longer word. It matches wording, not
# meaning: it misses the practice told without these words ("We release the
# weights of our GPAI model on Friday; the Annex XI file is not written yet."
# does not fire), and it fires on a refusal ("We never deploy a model without
# a model card." fires). Whether a provider has not drawn up the Article
# 53(1)(a) documentation is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(a)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 101: GPAI providers must document model details (training process, testing, evaluation results, Annex XI minimum content) to support enforcement by the AI Office and national authorities
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
#
# Citation fix: this rule was previously cited as Art 52. In the final adopted
# text of Regulation (EU) 2024/1689, Art 52 is the notification procedure for
# GPAI models with systemic risk; the technical documentation obligation is
# Art 53(1)(a). Corrected 2026-05-16.
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_53/par_1/pnt_a/oj
# Provision: Regulation (EU) 2024/1689, Article 53(1)(a)

package complyedge.gpai.technical_documentation

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	technical_documentation_pattern_match
}

technical_documentation_pattern_match if {
	patterns := [
		"(?:gpai|general[\\-\\s]?purpose.*model).*\\b(?:no|not|without|lack\\w*)\\b.*(?:technical[\\-\\s]?doc|model[\\-\\s]?card)",
		"\\b(?:no|not|without|lack\\w*)\\b.*technical[\\-\\s]?documentation.*(?:gpai|foundation|general[\\-\\s]?purpose)",
		"(?:undocumented|\\b(?:no|not)\\b.*documentation).*(?:training|evaluation).*(?:process|result)",
		"deploy.*model.*\\b(?:no|not|without)\\b.*(?:model[\\-\\s]?card|technical[\\-\\s]?doc)",
		"(?:skip|omit|bypass).*(?:technical[\\-\\s]?doc|model[\\-\\s]?documentation)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53a-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(a): draw up and keep up-to-date the technical documentation of the model, including its training and testing process and the results of its evaluation, which shall contain, at a minimum, the information set out in Annex XI for the purpose of providing it, upon request, to the AI Office and the national competent authorities;"
severity := "high"

remediation := "Create and maintain comprehensive technical documentation for the GPAI model, including training methodology, testing processes, evaluation results, and a model card. Keep documentation up-to-date."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
