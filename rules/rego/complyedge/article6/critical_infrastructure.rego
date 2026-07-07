# ComplyEdge — EU AI Act Article 6 + Annex III §2: Critical Infrastructure
#
# Classifies AI systems used as safety components or for management of
# critical infrastructure (power grid, water, gas, traffic, transport) as
# high-risk under Annex III §2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(2)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5; card 197 / WGlhJpPN)

package complyedge.article6.critical_infrastructure

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:power\\s+grid|electricity|water\\s+supply|gas\\s+distribution|traffic\\s+management|transport\\s+infrastructure)",
		"(?:power\\s+grid|water\\s+supply|gas|traffic|transport)\\s+(?:management|control|optimization)\\s+(?:ai|ml|model)",
		"critical\\s+infrastructure\\s+(?:ai|ml|system)",
		"smart\\s+grid\\s+(?:ai|control|optimization)",
		"traffic\\s+control\\s+(?:ai|automation)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-2-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(2): AI systems intended as safety components in critical infrastructure (water, gas, electricity, traffic, transport) are high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Critical infrastructure AI requires conformity assessment, technical documentation (Annex IV), human oversight, and post-market monitoring."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
