# ComplyEdge — EU AI Act Article 5: Aggregated Check
#
# Aggregates all sub-rules in this package and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/article5
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports and combines other
# rules' violation results — no legal condition of its own. Correctness derives
# from the imported sub-rules, each individually subject to §5 sign-off.

package complyedge.article5

import rego.v1

import data.complyedge.article5.biometric_categorisation
import data.complyedge.article5.emotion_recognition
import data.complyedge.article5.facial_scraping
import data.complyedge.article5.predictive_policing
import data.complyedge.article5.realtime_biometric
import data.complyedge.article5.social_scoring
import data.complyedge.article5.subliminal_manipulation
import data.complyedge.article5.vulnerability_exploitation

default violation := false

violation if biometric_categorisation.violation
violation if emotion_recognition.violation
violation if facial_scraping.violation
violation if predictive_policing.violation
violation if realtime_biometric.violation
violation if social_scoring.violation
violation if subliminal_manipulation.violation
violation if vulnerability_exploitation.violation

violations contains v if {
	biometric_categorisation.violation
	v := biometric_categorisation.result
}

violations contains v if {
	emotion_recognition.violation
	v := emotion_recognition.result
}

violations contains v if {
	facial_scraping.violation
	v := facial_scraping.result
}

violations contains v if {
	predictive_policing.violation
	v := predictive_policing.result
}

violations contains v if {
	realtime_biometric.violation
	v := realtime_biometric.result
}

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

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		biometric_categorisation.rule_id,
		emotion_recognition.rule_id,
		facial_scraping.rule_id,
		predictive_policing.rule_id,
		realtime_biometric.rule_id,
		social_scoring.rule_id,
		subliminal_manipulation.rule_id,
		vulnerability_exploitation.rule_id,
	],
}
