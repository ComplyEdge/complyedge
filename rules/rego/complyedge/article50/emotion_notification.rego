# ComplyEdge — EU AI Act Article 50(3): Emotion Notification
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(3)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.article50.emotion_notification

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:emotion\\s+recognition|biometric\\s+categori[sz]ation)\\s+(?:system\\s+)?(?:without|lacking|no)\\s+(?:notice|notif|disclosure|inform)",
		"(?:deploy|use|run)\\w*\\s+emotion\\s+recognition\\s+(?:on\\s+)?(?:users|people|persons)\\s+without\\s+(?:informing|telling|notice)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-3-001"

citation := "Regulation (EU) 2024/1689, Article 50(3): Deployers of an emotion recognition or biometric categorisation system must inform the natural persons exposed to it of its operation."

severity := "high"

remediation := "Inform natural persons when they are subject to emotion recognition or biometric categorisation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
