# ComplyEdge: EU AI Act Article 14: Human Oversight
#
# Running a high-risk AI system so that its decisions take effect with no
# human able to oversee, stop or override them, or an instruction to remove
# that oversight.
#
# Layer 1 detects: "without" or "no", directly followed by "human oversight",
# "human supervision", "human review", "human intervention" or "human
# control"; "fully autonomous high-risk AI" then "without" or "no" then "human
# oversight" or "human in the loop"; and "human oversight not implemented",
# "not possible" or "not provided", or "human oversight implemented",
# "possible" or "provided" followed, with only spaces between, by "false" or
# "no" and then punctuation or the end of the text. It matches wording, not
# meaning: it misses the practice told in other words ("Auto-reject candidates
# who score below 40 and send the rejection email right away, nobody needs to
# look at them"), it does not read whether the system is high-risk, and it
# fires on text that only names the practice, such as a refusal. Whether a
# text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 14(1)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_14/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 14(1)

package complyedge.highrisk.art14_human_oversight

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:without|no)\\s+human\\s+(?:oversight|supervision|review|intervention|control)",
		"fully\\s+autonomous\\s+high[\\-\\s]?risk\\s+ai\\s+(?:without|no)\\s+human\\s+(?:oversight|in\\s+the\\s+loop)",
		"human\\s+oversight\\s+(?:not\\s+(?:implemented|possible|provided)|(?:implemented|possible|provided)\\s*(?:false|no)(?:$|[^\\w ]))",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art14-001"

citation := "Regulation (EU) 2024/1689, Article 14(1): High-risk AI systems shall be designed and developed in such a way, including with appropriate human-machine interface tools, that they can be effectively overseen by natural persons during the period in which they are in use."
severity := "high"

remediation := "Design effective human oversight measures for the high-risk AI system. Readiness check, not yet a binding obligation: Article 14 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
