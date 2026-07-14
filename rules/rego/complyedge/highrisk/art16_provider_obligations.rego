# ComplyEdge — EU AI Act Article 16: Provider Obligations
#
# Legal citation: Regulation (EU) 2024/1689, Article 16
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.highrisk.art16_provider_obligations

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:place|placing|sell|deploy|launch|release)\\w*\\s+high[\\-\\s]?risk\\s+ai\\s+(?:on\\s+(?:the\\s+)?eu\\s+market|in\\s+(?:the\\s+)?union)\\s+(?:without|lacking)\\s+(?:ce\\s+marking|conformity\\s+assessment|registration)",
		"high[\\-\\s]?risk\\s+ai\\s+(?:without|no)\\s+(?:ce\\s+marking|conformity\\s+assessment|eu\\s+declaration)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art16-001"

citation := "Regulation (EU) 2024/1689, Article 16: Providers of high-risk AI systems must ensure conformity, affix the CE marking, draw up the EU declaration of conformity, and register the system before placing it on the market."

severity := "high"

remediation := "Complete conformity assessment, CE marking, and EU registration before market placement."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
