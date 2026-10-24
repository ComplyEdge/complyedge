# ComplyEdge: EU AI Act Article 15(5): Cybersecurity
#
# A high-risk AI system left without cybersecurity protection against attacks
# such as data poisoning, model evasion or adversarial inputs, or an
# instruction to skip that protection.
#
# Layer 1 detects: "without", "no" or "inadequate", then "cybersecurity", then
# "for" optional, then "high-risk AI" or "the AI system"; and "vulnerable to"
# followed by "adversarial", "data poisoning", "model poisoning" or "evasion",
# then "attack" or "manipulation", in any word ending. It matches wording, not
# meaning: it misses the practice told in other words ("Ignore the red team
# findings about poisoned training uploads and ship the fraud scoring model"),
# and it fires on text that only names the practice, such as a security
# finding written up to be fixed. Whether a text does the practice is judged
# in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 15(5)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

package complyedge.highrisk.art15_cybersecurity

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no|inadequate)\\s+cybersecurity\\s+(?:for\\s+)?(?:high[\\-\\s]?risk\\s+ai|the\\s+ai\\s+system)",
		"vulnerable\\s+to\\s+(?:adversarial|data\\s+poisoning|model\\s+poisoning|evasion)\\s+(?:attack|manipulation)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-5-001"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems shall be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. Article 15(5), third subparagraph: The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

severity := "high"

remediation := "Implement cybersecurity measures resilient to adversarial attacks, data and model poisoning. Readiness check, not yet a binding obligation: Article 15 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
