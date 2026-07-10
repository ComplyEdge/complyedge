# ComplyEdge — EU AI Act Article 15(1): Accuracy
#
# Legal citation: Regulation (EU) 2024/1689, Article 15(1)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art15_accuracy

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no)\\s+(?:declared\\s+)?accuracy\\s+(?:metric|level|testing|validation)",
		"accuracy\\s+(?:not\\s+)?(?:declared|documented|tested|validated)\\s*(?:false|no)?",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-1-001"

citation := "Regulation (EU) 2024/1689, Article 15(1): High-risk AI systems must achieve an appropriate level of accuracy and declare the relevant accuracy metrics in their instructions for use."

severity := "high"

remediation := "Declare appropriate accuracy metrics and validate the system's accuracy."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
