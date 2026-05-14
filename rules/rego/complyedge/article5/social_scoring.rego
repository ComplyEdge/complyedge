# ComplyEdge — EU AI Act Article 5(1)(c): Social Scoring
#
# Prohibits AI systems that evaluate or classify natural persons based on
# their social behaviour or personal characteristics, leading to detrimental
# or unfavourable treatment.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(c)
# Recital: 31 — social scoring leading to detrimental treatment in unrelated contexts undermines human dignity and non-discrimination
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-10

package complyedge.article5.social_scoring

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	social_scoring_pattern_match
}

social_scoring_pattern_match if {
	patterns := [
		"social[\\- ]?scor",
		"citizen[\\- ]?scor",
		"social[\\- ]?credit",
		"behavio(?:u)?r[\\- ]?scor",
		"trustworthiness[\\- ]?scor",
		"social[\\- ]?rating",
		"social[\\- ]?rank",
		"score.*social behavior",
		"rank.*citizens",
		"classify.*(?:personal|personality).*characteristics",
		"evaluate.*(?:natural persons|individuals).*(?:social|behavio)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1c-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(c): Prohibits AI systems that evaluate or classify natural persons based on their social behaviour or personal characteristics, with the social score leading to detrimental or unfavourable treatment."

severity := "critical"

remediation := "Remove any social scoring, citizen ranking, or behaviour-based classification that leads to detrimental treatment outside the original data context."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
