# ComplyEdge — EU AI Act Article 53(1)(d): Training Summary
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(d)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.gpai.training_summary

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:no|without|missing)\\s+(?:training\\s+(?:data|content)\\s+summary|publicly\\s+available\\s+summary)",
		"(?:gpai|general[\\-\\s]purpose\\s+ai|foundation)\\s+model\\s+(?:without|no)\\s+(?:training\\s+(?:data|content)\\s+summary|disclosure\\s+of\\s+training)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art53-1d-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(d): Providers of general-purpose AI models must draw up and make publicly available a sufficiently detailed summary of the content used for training, per the AI Office template."

severity := "high"

remediation := "Publish a sufficiently detailed summary of the training content per the AI Office template."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
