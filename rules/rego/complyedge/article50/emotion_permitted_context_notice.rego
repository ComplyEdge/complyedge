# ComplyEdge — EU AI Act Article 5(1)(f) exception + Article 50(3): Permitted-Context Notice
#
# Emotion recognition in workplace/education is prohibited under Article 5(1)(f)
# except for medical or safety reasons. Even in those permitted contexts,
# Article 50(3) still requires deployers to inform natural persons exposed to
# the system. Deploying medical/safety emotion recognition without notice is a
# transparency failure.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(f) exception + Article 50(3)
# Recital: 44 (emotion recognition limits); Article 50 transparency duties
# Effective: 2025-02-02 (Art 5) / 2026-08-02 (Art 50 high-risk & GPAI timeline)
# Penalty: up to €35M or 7% (Art 5) / transparency fines under Art 99
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-11 (via agent review per RULE_STANDARD §5.1; card M3.3-T3)

package complyedge.article50.emotion_permitted_context_notice

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:medical|safety).*(?:emotion\\s+recognition|emotion\\s+infer).*(?:without|no|lack).*(?:notice|notif|inform|disclosure)",
		"emotion\\s+recognition.*(?:medical|safety).*(?:without|no|lack).*(?:notice|notif|inform|disclosure)",
		"(?:deploy|use).*emotion\\s+recognition.*(?:for\\s+)?(?:medical|safety).*(?:without\\s+informing|no\\s+notice)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-3-002"

citation := "Regulation (EU) 2024/1689, Article 5(1)(f) exception + Article 50(3): Even where emotion recognition is permitted for medical or safety reasons, natural persons exposed to it must be informed."

severity := "high"

remediation := "If emotion recognition is deployed for a lawful medical or safety purpose, inform exposed natural persons of its operation per Article 50(3). Document the permitted-context basis."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
