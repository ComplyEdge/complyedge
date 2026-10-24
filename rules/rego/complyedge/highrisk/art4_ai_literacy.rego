# ComplyEdge: EU AI Act Article 4: Ai Literacy
#
# Having staff operate or use AI systems with no AI literacy measures, or an
# instruction to skip AI literacy training.
#
# Layer 1 detects: "no", "without", or a word starting "skip" or "neglect",
# directly followed by "AI literacy training", "AI literacy program" or "AI
# literacy measure", in any word ending ("skipping AI literacy training", "no
# AI literacy measures"); and "staff operating", "staff using" or "staff
# deploying" AI, then "without" or "lacking", then literacy training or
# literacy competence, with "AI" allowed before "literacy". It matches
# wording, not meaning: it misses the practice told in other words ("We are
# not running any training on how it works, they will figure it out"), and it
# fires on text that only names the practice, such as a refusal. Whether a
# text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 4(1), as replaced by Regulation (EU) 2026/1744, Article 1, point (5)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Effective: 2025-02-02 (Article 4 in its original wording); the text quoted here, as replaced by Regulation (EU) 2026/1744, applies from 2026-07-27
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_4/oj
# Provision: Regulation (EU) 2024/1689, Article 4(1), as replaced by Regulation (EU) 2026/1744

package complyedge.highrisk.art4_ai_literacy

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:no|without|skip\\w*|neglect\\w*)\\s+ai\\s+literacy\\s+(?:training|program|measure)",
		"staff\\s+(?:operating|using|deploying)\\s+ai\\s+(?:without|lacking)\\s+(?:\\bai\\s+)?literacy\\s+(?:training|competence)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art4-001"

citation := "Regulation (EU) 2024/1689, Article 4(1), as replaced by Regulation (EU) 2026/1744, Article 1, point (5): Providers and deployers of AI systems shall take measures to support the development of AI literacy of their staff and other persons dealing with the operation and use of AI systems on their behalf, taking into account their technical knowledge, experience, education and training and the context the AI systems are to be used in, and considering the persons or groups of persons on whom the AI systems are to be used. This obligation does not require providers or deployers to guarantee any specific level of AI literacy of any individual."
severity := "medium"

remediation := "Take measures to support the development of AI literacy of staff and other persons operating or using AI systems on your behalf, taking into account their technical knowledge, experience, education and training and the context of use. Article 4, as replaced by Regulation (EU) 2026/1744 from 27 July 2026, does not require any specific level of AI literacy of any individual."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
