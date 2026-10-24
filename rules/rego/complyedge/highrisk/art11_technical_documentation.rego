# ComplyEdge: EU AI Act Article 11: Technical Documentation
#
# Placing or running a high-risk AI system without the technical documentation
# of Annex IV, or an instruction to skip or omit that documentation.
#
# Layer 1 detects: "high-risk AI" (with a hyphen, a space or neither),
# "system" optional, then "without", "no" or "lacking", then "technical
# documentation"; and "no", "without", "missing" or a word starting "skip",
# then "Annex IV" optional, then "technical documentation", then "for"
# optional, then "high-risk" or "AI system". It matches wording, not meaning:
# it misses the practice told in other words ("Launch the CV screening model
# in the EU next week; the Annex IV docs can wait until after launch"), and it
# fires on text that only names the practice, such as a refusal. Whether a
# text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 11(1)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_11/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 11(1)

package complyedge.highrisk.art11_technical_documentation

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?\\b(?:without|no|lacking)\\s+technical\\s+documentation",
		"\\b(?:no|without|skip\\w*|missing)\\s+(?:annex\\s+iv\\s+)?technical\\s+documentation\\s+(?:for\\s+)?(?:high[\\-\\s]?risk|\\bai\\s+system)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art11-001"

citation := "Regulation (EU) 2024/1689, Article 11(1): The technical documentation of a high-risk AI system shall be drawn up before that system is placed on the market or put into service and shall be kept up-to date."

severity := "high"

remediation := "Draw up and maintain Annex IV technical documentation before placing the system on the market. Readiness check, not yet a binding obligation: Article 11 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
