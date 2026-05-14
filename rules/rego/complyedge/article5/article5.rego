# ComplyEdge — EU AI Act Article 5: Aggregated Prohibited Practices Check
#
# This policy aggregates all Article 5 sub-checks and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/article5

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
