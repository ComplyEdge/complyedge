# ComplyEdge — EU AI Act Article 50: Aggregated Transparency Obligations Check
#
# This policy aggregates all Article 50 sub-checks and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/article50

package complyedge.article50

import rego.v1

import data.complyedge.article50.gpai_content_disclosure
import data.complyedge.article50.synthetic_media_watermark
import data.complyedge.article50.chatbot_disclosure
import data.complyedge.article50.deepfake_disclosure

# True if ANY Article 50 sub-rule is violated
default violation := false

violation if gpai_content_disclosure.violation
violation if synthetic_media_watermark.violation
violation if chatbot_disclosure.violation
violation if deepfake_disclosure.violation

# Collect all triggered violations into an array
violations contains v if {
	gpai_content_disclosure.violation
	v := gpai_content_disclosure.result
}

violations contains v if {
	synthetic_media_watermark.violation
	v := synthetic_media_watermark.result
}

violations contains v if {
	chatbot_disclosure.violation
	v := chatbot_disclosure.result
}

violations contains v if {
	deepfake_disclosure.violation
	v := deepfake_disclosure.result
}

# Summary result for the OPA client
result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		gpai_content_disclosure.rule_id,
		synthetic_media_watermark.rule_id,
		chatbot_disclosure.rule_id,
		deepfake_disclosure.rule_id,
	],
}
