# ComplyEdge — EU AI Act Article 12: Record Keeping
#
# Legal citation: Regulation (EU) 2024/1689, Article 12
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.highrisk.art12_record_keeping

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:no|without|disable\\w*|bypass|skip\\w*|turn\\s+off)\\s+(?:logging|logs|event\\s+log|audit\\s+log|record[\\-\\s]?keeping)\\s+(?:for|on|in)\\s+(?:high[\\-\\s]?risk\\s+ai|ai\\s+system)",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?(?:without|no)\\s+automatic\\s+(?:event\\s+)?logging",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art12-001"

citation := "Regulation (EU) 2024/1689, Article 12: High-risk AI systems must technically allow for the automatic recording of events (logs) over the lifetime of the system."

severity := "high"

remediation := "Enable automatic event logging over the lifetime of the high-risk AI system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
