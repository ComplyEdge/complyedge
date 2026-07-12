# ComplyEdge — EU AI Act Article 50: Aggregated Check
#
# Aggregates all sub-rules in this package and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/article50
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): imports and combines other
# rules' violation results — no legal condition of its own. Correctness derives
# from the imported sub-rules, each individually subject to §5 sign-off.

package complyedge.article50

import rego.v1

import data.complyedge.article50.chatbot_disclosure
import data.complyedge.article50.deepfake_disclosure
import data.complyedge.article50.emotion_notification
import data.complyedge.article50.emotion_permitted_context_notice
import data.complyedge.article50.gpai_content_disclosure
import data.complyedge.article50.public_interest_text
import data.complyedge.article50.synthetic_media_watermark

default violation := false

violation if chatbot_disclosure.violation
violation if deepfake_disclosure.violation
violation if emotion_notification.violation
violation if emotion_permitted_context_notice.violation
violation if gpai_content_disclosure.violation
violation if public_interest_text.violation
violation if synthetic_media_watermark.violation

violations contains v if {
	chatbot_disclosure.violation
	v := chatbot_disclosure.result
}

violations contains v if {
	deepfake_disclosure.violation
	v := deepfake_disclosure.result
}

violations contains v if {
	emotion_notification.violation
	v := emotion_notification.result
}

violations contains v if {
	emotion_permitted_context_notice.violation
	v := emotion_permitted_context_notice.result
}

violations contains v if {
	gpai_content_disclosure.violation
	v := gpai_content_disclosure.result
}

violations contains v if {
	public_interest_text.violation
	v := public_interest_text.result
}

violations contains v if {
	synthetic_media_watermark.violation
	v := synthetic_media_watermark.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		chatbot_disclosure.rule_id,
		deepfake_disclosure.rule_id,
		emotion_notification.rule_id,
		emotion_permitted_context_notice.rule_id,
		gpai_content_disclosure.rule_id,
		public_interest_text.rule_id,
		synthetic_media_watermark.rule_id,
	],
}
