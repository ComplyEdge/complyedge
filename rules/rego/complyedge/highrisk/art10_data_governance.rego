# ComplyEdge: EU AI Act Article 10: Data Governance
#
# Training, validation or test data for a high-risk AI system that is
# knowingly biased, unrepresentative, incomplete or unexamined, or an
# instruction to train or ship on such data without the data governance
# Article 10 requires.
#
# Layer 1 detects: "training data" directly followed by "not representative",
# "biased", "incomplete" or "unvetted"; "no", "without" or "inadequate", then
# "data governance", then "for" or "on", then "high-risk" or "training data";
# and "unrepresentative" or "biased", "training" optional, then "data",
# "dataset" or "sample", in any word ending ("biased datasets"). It matches
# wording, not meaning: it misses the practice told in other words ("We know
# the loan dataset barely includes women applicants, but train the credit
# model on it anyway"), it does not read whether the system is high-risk, and
# it fires on text that only names the practice, such as a plan to test for
# biased data. Whether a text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 10(2) and (3)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_10/oj
# Provision: Regulation (EU) 2024/1689, Article 10(2) and (3)

package complyedge.highrisk.art10_data_governance

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"training\\s+data\\s+(?:not\\s+representative|biased|incomplete|unvetted)",
		"\\b(?:no|without|inadequate)\\s+data\\s+governance\\s+(?:for|on)\\s+(?:high[\\-\\s]?risk|training\\s+data)",
		"(?:unrepresentative|biased)\\s+(?:training\\s+)?(?:data|dataset|sample)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art10-001"

citation := "Regulation (EU) 2024/1689, Article 10(2): Training, validation and testing data sets shall be subject to data governance and management practices appropriate for the intended purpose of the high-risk AI system. Article 10(3): Training, validation and testing data sets shall be relevant, sufficiently representative, and to the best extent possible, free of errors and complete in view of the intended purpose."
severity := "high"

remediation := "Apply data governance ensuring training data is relevant, representative, and appropriately vetted. Readiness check, not yet a binding obligation: Article 10 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
