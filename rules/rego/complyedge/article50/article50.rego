# ComplyEdge — EU AI Act Article 50: Aggregated Transparency Obligations Check
#
# This policy aggregates all Article 50 sub-checks and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/article50
#
# Aggregator carve-out (RULE_STANDARD.md §5.6, added v1.1):
# This file imports and combines other rules' violation results — it has no
# legal condition of its own. Exempt from §5 approval headers. Correctness
# derives from the correctness of the imported sub-rules, each of which is
# individually subject to §5 sign-off.
#
# Imported rules covered by individual §5 approvals:
#   - article50.chatbot_disclosure (Art 50(1)) — approved by Leo Celis 2026-05-16 (agent review)
#   - article50.gpai_content_disclosure (Art 50(2)) — approved by Leo Celis 2026-05-16 (agent review)
#   - article50.synthetic_media_watermark (Art 50(2)) — approved by Leo Celis 2026-05-16 (agent review)
#   - article50.deepfake_disclosure (Art 50(4)) — approved by Leo Celis 2026-05-16 (agent review)

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
