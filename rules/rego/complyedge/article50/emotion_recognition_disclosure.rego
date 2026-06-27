# ComplyEdge — EU AI Act Article 50(3): Emotion Recognition Disclosure
#
# Deployers of an emotion recognition system or a biometric categorisation
# system shall inform the natural persons exposed thereto of the operation
# of the system, and shall process personal data in accordance with GDPR
# and applicable Union data protection law.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(3)
# Recital: 132 — persons exposed to emotion recognition or biometric categorisation must be informed of system operation
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Distinct from article5/emotion_recognition.rego (Art 5(1)(f)
# prohibition in workplace/education). Art 50(3) requires disclosure where
# permitted deployers use emotion recognition or biometric categorisation.

package complyedge.article50.emotion_recognition_disclosure

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	emotion_recognition_disclosure_pattern_match
}

emotion_recognition_disclosure_pattern_match if {
	patterns := [
		"(?:emotion[\\- ]?recognition|emotion[\\- ]?(?:detection|analysis|monitoring)).*(?:without|lacking)[\\- ]+(?:notice|disclosure|inform|notif|consent)",
		"(?:emotion[\\- ]?recognition|emotion[\\- ]?(?:detection|analysis|monitoring)).*(?:not[\\- ]+(?:disclos|inform|notif))",
		"(?:biometric[\\- ]?categori[sz]ation|biometric[\\- ]?classification).*(?:without|lacking)[\\- ]+(?:notice|disclosure|inform|notif|consent)",
		"(?:deploy|use|operat\\w*).*(?:emotion[\\- ]?(?:detection|recognition|analysis)).*(?:without|lacking)[\\- ]+(?:inform|notif|disclos)",
		"(?:covert|secret|hidden|undisclosed).*(?:emotion[\\- ]?(?:recognition|detection|analysis|monitoring)|biometric[\\- ]?(?:categori[sz]ation|classification|analysis))",
		"(?:fail(?:ing|ure)?[\\- ]?to|without)[\\- ]+(?:inform|notif|disclos).*(?:persons?|individuals?|users?|customers?|visitors?)",
		"(?:will[\\- ]?not|won't|do[\\- ]?not)[\\- ]+(?:disclos|inform|notif).*(?:customers?|persons?|visitors?)",
		"(?:biometric[\\- ]?(?:analysis|processing)).*(?:without|lacking)[\\- ]+(?:gdpr|data[\\- ]?protection)[\\- ]+(?:compliance)?",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-3-001"

citation := "Regulation (EU) 2024/1689, Article 50(3): Deployers of an emotion recognition system or a biometric categorisation system shall inform the natural persons exposed thereto of the operation of the system, and shall process personal data in accordance with applicable Union data protection law."

severity := "high"

remediation := "Inform all persons exposed to the emotion recognition or biometric categorisation system of its operation before or at first exposure. Ensure personal data processing complies with GDPR and applicable Union law; document lawful basis and notice."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
