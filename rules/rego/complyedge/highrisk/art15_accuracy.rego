# ComplyEdge - EU AI Act Article 15(3): Accuracy
#
# Releasing or running a high-risk AI system without testing or declaring its
# accuracy, or an instruction to skip accuracy validation.
#
# Layer 1 detects: "without" or "no", "declared" optional, then "accuracy
# metric", "accuracy level", "accuracy testing" or "accuracy validation", in
# any word ending ("no accuracy metrics"); and "accuracy not declared", "not
# documented", "not tested" or "not validated", or "accuracy declared",
# "documented", "tested" or "validated" followed, with only spaces between, by
# "false" or "no" and then punctuation or the end of the text. It matches
# wording, not meaning: it misses the practice told in other words, it does
# not read whether the system is high-risk, and it fires on text that only
# names the practice, such as a refusal. Whether a text does the practice is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 15(3)
# Rule ID: rego-art15-1-001 is kept from the first version, which cited Article 15(1); the provision is now Article 15(3). The ID is unchanged so stored decisions still resolve to this rule
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_3/oj
# Provision: Regulation (EU) 2024/1689, Article 15(3)

package complyedge.highrisk.art15_accuracy

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no)\\s+(?:declared\\s+)?accuracy\\s+(?:metric|level|testing|validation)",
		"accuracy\\s+(?:not\\s+(?:declared|documented|tested|validated)|(?:declared|documented|tested|validated)\\s*(?:false|no)(?:$|[^\\w ]))",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

# The ID predates the move to Article 15(3). It stays: audit records key on it.
rule_id := "rego-art15-1-001"

citation := "Regulation (EU) 2024/1689, Article 15(3): The levels of accuracy and the relevant accuracy metrics of high-risk AI systems shall be declared in the accompanying instructions of use."

severity := "high"

remediation := "Declare appropriate accuracy metrics and validate the system's accuracy. Readiness check, not yet a binding obligation: Article 15 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
