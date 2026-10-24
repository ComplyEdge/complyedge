# ComplyEdge: EU AI Act Article 27: Fria
#
# A deployer putting a high-risk AI system into use without first carrying out
# the fundamental rights impact assessment Article 27 requires.
#
# Layer 1 detects: "without", "no" or a word starting "skip", then
# "fundamental right" or "fundamental rights" optional, then "impact
# assessment"; and "no" or "without", then "FRIA" or "fundamental right(s)
# assessment" or "fundamental right(s) impact assessment", then "for"
# optional, then "high-risk" or "deployment". It matches wording, not meaning:
# it misses the practice told in other words, it does not read whether the
# deployer is one Article 27 covers, and it fires on any "no impact
# assessment", including one about another kind of assessment such as a data
# protection one, and on text that only names the practice, such as a refusal.
# Whether a text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 27(1)
# Effective: 2027-12-02 (Article 27(1) covers only high-risk AI systems referred to in Article 6(2), that is Annex III; Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_27/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 27(1)

package complyedge.highrisk.art27_fria

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no|skip\\w*)\\s+(?:fundamental\\s+rights?\\s+)?impact\\s+assessment",
		"\\b(?:no|without)\\s+(?:fria|fundamental\\s+rights?\\s+(?:impact\\s+)?assessment)\\s+(?:for\\s+)?(?:high[\\-\\s]?risk|deployment)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art27-001"

citation := "Regulation (EU) 2024/1689, Article 27(1): Prior to deploying a high-risk AI system referred to in Article 6(2), with the exception of high-risk AI systems intended to be used in the area listed in point 2 of Annex III, deployers that are bodies governed by public law, or are private entities providing public services, and deployers of high-risk AI systems referred to in points 5 (b) and (c) of Annex III, shall perform an assessment of the impact on fundamental rights that the use of such system may produce."
severity := "high"

remediation := "Perform a fundamental rights impact assessment before deploying the high-risk AI system. Readiness check, not yet a binding obligation: Article 27 applies from 2 December 2027 and covers only high-risk AI systems referred to in Article 6(2) (Annex III) (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
