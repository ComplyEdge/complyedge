# ComplyEdge — EU AI Act Article 5(1)(f): Emotion Recognition
#
# Prohibits AI systems that infer emotions of natural persons in the
# areas of workplace and education institutions, except where the AI
# system is intended to be put into place for medical or safety reasons.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(f)
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue

package complyedge.article5.emotion_recognition

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	emotion_recognition_pattern_match
}

emotion_recognition_pattern_match if {
	patterns := [
		"emotion[\\- ]?recognition",
		"employee[\\- ]?emotion[\\- ]?detect",
		"student[\\- ]?emotion[\\- ]?detect",
		"employee[\\- ]?mood[\\- ]?detect",
		"student[\\- ]?mood[\\- ]?detect",
		"workplace[\\- ]?emotion",
		"classroom[\\- ]?emotion",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1f-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(f): Prohibits AI systems that infer emotions of natural persons in workplace and education settings, except for medical or safety purposes."

severity := "critical"

remediation := "Remove emotion recognition capabilities from workplace and education contexts. If emotion inference is required for medical or safety reasons, document the lawful basis and ensure compliance with applicable exceptions."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
