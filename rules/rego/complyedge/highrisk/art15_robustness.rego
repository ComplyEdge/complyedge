# ComplyEdge: EU AI Act Article 15(4): Robustness
#
# Releasing a high-risk AI system with no robustness testing, redundancy or
# fail-safe design, or an instruction to remove them.
#
# Layer 1 detects: "without" or "no", directly followed by "robustness",
# "resilience", "fail-safe" (with a hyphen, a space or as one word) or
# "redundancy", and then a space, so the word must not end the sentence ("no
# robustness testing", "without redundancy for the nodes"); and "not resilient
# against" or "not resilient to", then "errors", "faults" or
# "inconsistencies", or "resilient against" or "to" one of those followed,
# with only spaces between, by "false" or "no" and then punctuation or the end
# of the text. It matches wording, not meaning: it misses the practice told in
# other words, it does not read whether the text is about an AI system, and it
# fires on text that only names the practice or uses the words in another
# sense ("no redundancy in the team"). Whether a text does the practice is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 15(4)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_4/oj
# Provision: Regulation (EU) 2024/1689, Article 15(4)

package complyedge.highrisk.art15_robustness

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no)\\s+(?:robustness|resilience|fail[\\-\\s]?safe|redundancy)\\s+(?:testing|measure|design)?",
		"(?:not\\s+resilient\\s+(?:against|to)\\s+(?:errors|faults|inconsistencies)|resilient\\s+(?:against|to)\\s+(?:errors|faults|inconsistencies)\\s*(?:false|no)(?:$|[^\\w ]))",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-4-001"

citation := "Regulation (EU) 2024/1689, Article 15(4): High-risk AI systems shall be as resilient as possible regarding errors, faults or inconsistencies that may occur within the system or the environment in which the system operates, in particular due to their interaction with natural persons or other systems. Article 15(4), second subparagraph: The robustness of high-risk AI systems may be achieved through technical redundancy solutions, which may include backup or fail-safe plans."

severity := "high"

remediation := "Implement robustness and fail-safe/redundancy measures against errors and faults. Readiness check, not yet a binding obligation: Article 15 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
