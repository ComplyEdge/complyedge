# ComplyEdge — EU AI Act Article 15(4): Robustness
#
# Legal citation: Regulation (EU) 2024/1689, Article 15(4)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art15_robustness

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no)\\s+(?:robustness|resilience|fail[\\-\\s]?safe|redundancy)\\s+(?:testing|measure|design)?",
		"(?:not\\s+)?resilient\\s+(?:against|to)\\s+(?:errors|faults|inconsistencies)\\s*(?:false|no)?",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-4-001"

citation := "Regulation (EU) 2024/1689, Article 15(4): High-risk AI systems must be as resilient as possible regarding errors, faults, or inconsistencies, through technical redundancy solutions such as backup or fail-safe plans."

severity := "high"

remediation := "Implement robustness and fail-safe/redundancy measures against errors and faults."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
