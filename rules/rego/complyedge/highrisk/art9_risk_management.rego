# ComplyEdge: EU AI Act Article 9: Risk Management
#
# Placing or running a high-risk AI system with no risk management system
# across its lifecycle, or an instruction to skip or bypass risk management.
#
# Layer 1 detects: "without", "no", or a word starting "skip" or "bypass",
# directly followed by "risk management" ("bypass risk management", "no risk
# management system"); "high-risk AI" (with a hyphen, a space or neither),
# "system" optional, then "without", "lacking" or "no", then "risk management"
# or "lifecycle risk"; and "risk management not required", "not needed", "not
# implemented" or "not established", or "risk management required", "needed",
# "implemented" or "established" followed, with only spaces between, by
# "false" or "no" and then punctuation or the end of the text. It matches
# wording, not meaning: it misses the practice told in other words ("Ship the
# credit scoring model to production today; we will write up the hazard
# analysis some time after launch"), it does not read whether the system is
# high-risk, and it fires on text that only names the practice, such as a
# refusal. Whether a text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 9(1)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_9/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 9(1)

package complyedge.highrisk.art9_risk_management

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no|skip\\w*|bypass\\w*)\\s+risk\\s+management(?:\\s+(?:system|process|plan))?",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?\\b(?:without|lacking|no)\\s+(?:risk\\s+management|lifecycle\\s+risk)",
		"risk\\s+management\\s+(?:not\\s+(?:required|needed|implemented|established)|(?:required|needed|implemented|established)\\s*(?:false|no)(?:$|[^\\w ]))",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art9-001"

citation := "Regulation (EU) 2024/1689, Article 9(1): A risk management system shall be established, implemented, documented and maintained in relation to high-risk AI systems."
severity := "high"

remediation := "Establish and maintain a lifecycle risk-management system for the high-risk AI system. Readiness check, not yet a binding obligation: Article 9 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
