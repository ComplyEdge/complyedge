# ComplyEdge — EU AI Act Article 5: Aggregated Prohibited Practices Check
#
# This policy aggregates all Article 5 sub-checks and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/article5
#
# Aggregator carve-out (RULE_STANDARD.md §5.6, added v1.1):
# This file imports and combines other rules' violation results — it has no
# legal condition of its own. Exempt from §5 approval headers. Correctness
# derives from the correctness of the imported sub-rules, each of which is
# individually subject to §5 sign-off.
#
# Imported rules covered by individual §5 approvals:
#   - article5.social_scoring (Art 5(1)(c)) — approved by Leo Celis 2026-05-10
#   - article5.subliminal_manipulation (Art 5(1)(a)) — approved by Leo Celis 2026-05-10
#   - article5.vulnerability_exploitation (Art 5(1)(b)) — approved by Leo Celis 2026-05-10
#   - article5.biometric_categorisation (Art 5(1)(g)) — approved by Leo Celis 2026-05-10
#   - article5.emotion_recognition (Art 5(1)(f)) — approved by Leo Celis 2026-05-16 (agent review)
#   - article5.predictive_policing (Art 5(1)(d)) — approved by Leo Celis 2026-05-16 (agent review)
#   - article5.realtime_biometric (Art 5(1)(h)) — approved by Leo Celis 2026-05-16 (agent review)

package complyedge.article5

import rego.v1

import data.complyedge.article5.social_scoring
import data.complyedge.article5.subliminal_manipulation
import data.complyedge.article5.vulnerability_exploitation
import data.complyedge.article5.biometric_categorisation
import data.complyedge.article5.emotion_recognition
import data.complyedge.article5.predictive_policing
import data.complyedge.article5.realtime_biometric

# True if ANY Article 5 sub-rule is violated
default violation := false

violation if social_scoring.violation
violation if subliminal_manipulation.violation
violation if vulnerability_exploitation.violation
violation if biometric_categorisation.violation
violation if emotion_recognition.violation
violation if predictive_policing.violation
violation if realtime_biometric.violation

# Collect all triggered violations into an array
violations contains v if {
	social_scoring.violation
	v := social_scoring.result
}

violations contains v if {
	subliminal_manipulation.violation
	v := subliminal_manipulation.result
}

violations contains v if {
	vulnerability_exploitation.violation
	v := vulnerability_exploitation.result
}

violations contains v if {
	biometric_categorisation.violation
	v := biometric_categorisation.result
}

violations contains v if {
	emotion_recognition.violation
	v := emotion_recognition.result
}

violations contains v if {
	predictive_policing.violation
	v := predictive_policing.result
}

violations contains v if {
	realtime_biometric.violation
	v := realtime_biometric.result
}

# Summary result for the OPA client
result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		social_scoring.rule_id,
		subliminal_manipulation.rule_id,
		vulnerability_exploitation.rule_id,
		biometric_categorisation.rule_id,
		emotion_recognition.rule_id,
		predictive_policing.rule_id,
		realtime_biometric.rule_id,
	],
}
