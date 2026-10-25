# ComplyEdge: EU AI Act Article 5(1)(f): Emotion Recognition
#
# Prohibits AI systems that infer emotions of natural persons in the
# areas of workplace and education institutions, except where the AI
# system is intended to be put into place for medical or safety reasons.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(f)
# Recital: 44: limited scientific reliability of emotion inference; cultural variability of expression; power imbalance in workplace/education justifies prohibition (medical/safety uses excepted)
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_5/par_1/pnt_f/oj
# Provision: Regulation (EU) 2024/1689, Article 5(1)(f)

package complyedge.article5.emotion_recognition

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	emotion_recognition_pattern_match
}

emotion_recognition_pattern_match if {
	patterns := [
		"emotion[\\-\\s]?recognition",
		"employee[\\-\\s]?emotion[\\-\\s]?detect",
		"student[\\-\\s]?emotion[\\-\\s]?detect",
		"employee[\\-\\s]?mood[\\-\\s]?detect",
		"student[\\-\\s]?mood[\\-\\s]?detect",
		"workplace[\\-\\s]?emotion",
		"classroom[\\-\\s]?emotion",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1f-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(f): The placing on the market, the putting into service for this specific purpose, or the use of AI systems to infer emotions of a natural person in the areas of workplace and education institutions, except where the use of the AI system is intended to be put in place or into the market for medical or safety reasons."
severity := "critical"

# Remediation states the ban as the law draws it (2026-10-24, Leo: "is that answer
# law based? make sure that the language is clear, and legal"). The old text said
# "document the lawful basis", a GDPR term that is not the Art 5(1)(f) exception,
# and did not say the ban turns on biometric data. Commission Guidelines on
# prohibited AI practices (4 Feb 2025, updated 31 Jul 2025), paras 245 and 251:
# 5(1)(f) is read with Art 3(39), so it covers emotion inference from biometric
# data (faces, voice, keystrokes, posture); inference from written text alone is
# outside it. The exception is a system intended for medical or safety reasons.
remediation := "Do not use AI to infer the emotions of people at work or in education from their biometric data, such as faces, voices or typing patterns. The only exception is a system intended for medical or safety reasons."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
