# ComplyEdge — EU AI Act Article 26: Deployer Obligations
#
# Legal citation: Regulation (EU) 2024/1689, Article 26
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art26_deployer_obligations

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"deploy(?:ing|er)?\\s+high[\\-\\s]?risk\\s+ai\\s+without\\s+(?:instructions|oversight|monitoring|logs)",
		"(?:ignor|disregard)\\w*\\s+(?:the\\s+)?(?:instructions\\s+for\\s+use|deployer\\s+obligations)\\s+(?:for\\s+)?high[\\-\\s]?risk",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art26-001"

citation := "Regulation (EU) 2024/1689, Article 26: Deployers of high-risk AI systems must use them in accordance with the instructions for use, ensure human oversight, monitor operation, and keep automatically generated logs."

severity := "high"

remediation := "Use the high-risk system per instructions, ensure oversight and monitoring, and retain logs."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
