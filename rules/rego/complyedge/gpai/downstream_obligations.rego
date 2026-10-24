# ComplyEdge: EU AI Act Article 53(1)(b): GPAI Downstream Provider Information
#
# Providers of general-purpose AI models shall draw up, keep up-to-date
# and make available information and documentation to providers of AI
# systems who intend to integrate the general-purpose AI model into
# their AI systems. The information shall enable downstream providers to
# understand the capabilities and limitations of the GPAI model and to
# comply with their obligations under this Regulation; it shall contain,
# at a minimum, the elements set out in Annex XII.
#
# Layer 1 detects: "downstream", then the word "no", "not", "without" or "lack" (any
# ending), then documentation, information or support; the word "no",
# "not",
# "without" or "lack" (any ending), then "downstream", then provider or
# integrator, then doc, info or guid; "gpai" or "foundation model" (space,
# hyphen or one word), then the word "no", "not" or "without", then "downstream",
# then obligat or support; "api" or "model", then the word "no", "not" or "without",
# then "integration guid" or "usage doc" (space, hyphen or one word), then
# "downstream"; and provid or distribut, then model, then the word "no", "not" or
# "without", then "downstream" or "integrator", then doc, guid or info. Case
# is ignored, the parts must sit on one line in the order given with any words
# between them, and a part not called a word can start inside a longer word.
# It matches wording, not meaning: it misses the practice told without these
# words ("Ship the model weights to integrators with nothing explaining what
# it can and cannot do." does not fire), and it fires on a denial ("Downstream
# providers never go without documentation: we ship the Annex XII pack."
# fires). Whether the Article 53(1)(b) information is withheld is judged in
# Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(b)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 101: downstream providers integrating a GPAI model need sufficient information to understand its capabilities, limitations, and integration requirements in order to meet their own AI Act obligations
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
#
# Citation fix: this rule was previously cited as Art 53(1)(d). In the final
# adopted text of Regulation (EU) 2024/1689, downstream provider documentation
# is Art 53(1)(b) (with details in Annex XII); Art 53(1)(d) is the public
# training-data summary. Corrected 2026-05-16.
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_53/par_1/pnt_b/oj
# Provision: Regulation (EU) 2024/1689, Article 53(1)(b)

package complyedge.gpai.downstream_obligations

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	downstream_obligations_pattern_match
}

downstream_obligations_pattern_match if {
	patterns := [
		"downstream.*\\b(?:no|not|without|lack\\w*)\\b.*(?:documentation|information|support)",
		"\\b(?:no|not|without|lack\\w*)\\b.*downstream.*(?:provider|integrator).*(?:doc|info|guid)",
		"(?:gpai|foundation[\\-\\s]?model).*\\b(?:no|not|without)\\b.*downstream.*(?:obligat|support)",
		"(?:api|model).*\\b(?:no|not|without)\\b.*(?:integration[\\-\\s]?guid|usage[\\-\\s]?doc).*downstream",
		"(?:provid|distribut).*model.*\\b(?:no|not|without)\\b.*(?:downstream|integrator).*(?:doc|guid|info)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53b-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(b): draw up, keep up-to-date and make available information and documentation to providers of AI systems who intend to integrate the general-purpose AI model into their AI systems. Without prejudice to the need to observe and protect intellectual property rights and confidential business information or trade secrets in accordance with Union and national law, the information and documentation shall: (i) enable providers of AI systems to have a good understanding of the capabilities and limitations of the general-purpose AI model and to comply with their obligations pursuant to this Regulation; and (ii) contain, at a minimum, the elements set out in Annex XII;"
severity := "high"

remediation := "Provide comprehensive documentation and integration guidance to downstream providers. Include model capabilities, limitations, intended use cases, and compliance requirements to enable downstream regulatory compliance."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
