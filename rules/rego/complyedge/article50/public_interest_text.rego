# ComplyEdge — EU AI Act Article 50(4): Public Interest Text
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(4)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.article50.public_interest_text

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:ai[\\-\\s]?generated|synthetic|machine[\\-\\s]?generated)\\s+(?:text|article|news|content)\\s+(?:on|about)\\s+(?:matters\\s+of\\s+)?public\\s+interest\\s+(?:without|no)\\s+(?:disclosure|label|marking)",
		"publish\\w*\\s+ai[\\-\\s]?generated\\s+(?:news|article|text)\\s+without\\s+(?:disclosing|labelling|marking)\\s+(?:it\\s+)?(?:as\\s+)?ai",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-4-002"

citation := "Regulation (EU) 2024/1689, Article 50(4): AI-generated or manipulated text published to inform the public on matters of public interest must be disclosed as artificially generated, unless human editorial review applies."

severity := "high"

remediation := "Disclose AI-generated text published on matters of public interest as artificially generated."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
