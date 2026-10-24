# ComplyEdge: EU AI Act Article 13: Transparency
#
# Supplying a high-risk AI system to deployers without the instructions for
# use and transparency information Article 13 requires.
#
# Layer 1 detects: "without" or "no", directly followed by "instructions for
# use" (or "instruction for use"), "deployer information", "deployer
# documentation", "transparency information" or "transparency documentation";
# and "high-risk AI", "system" optional, then "without" or "no", then
# "instructions for use" or "transparency". It matches wording, not meaning:
# it misses the practice told in other words ("Ship the credit model to the
# bank's deployers now and send them the user manual next quarter"), it does
# not read whether the system is high-risk, and it fires on text that only
# names the practice, such as a refusal. Whether a text does the practice is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 13(2)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_13/par_2/oj
# Provision: Regulation (EU) 2024/1689, Article 13(2)

package complyedge.highrisk.art13_transparency

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no)\\s+(?:instructions?\\s+for\\s+use|deployer\\s+(?:information|documentation)|transparency\\s+(?:information|documentation))",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?\\b(?:without|no)\\s+(?:instructions\\s+for\\s+use|transparency)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art13-001"

citation := "Regulation (EU) 2024/1689, Article 13(2): High-risk AI systems shall be accompanied by instructions for use in an appropriate digital format or otherwise that include concise, complete, correct and clear information that is relevant, accessible and comprehensible to deployers."
severity := "high"

remediation := "Provide instructions for use enabling deployers to interpret and use the system's output appropriately. Readiness check, not yet a binding obligation: Article 13 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
