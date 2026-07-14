# ComplyEdge — article50 new-rule tests
# Run with: opa test rules/rego/ -v

package complyedge.article50_m33_test

import rego.v1

import data.complyedge.article50.emotion_notification
import data.complyedge.article50.public_interest_text
import data.complyedge.article50

test_emotion_notification_blocks if {
	emotion_notification.violation with input as {"jurisdiction": "EU", "text": "We deploy emotion recognition without notice to users"}
}

test_emotion_notification_allows_clean if {
	not emotion_notification.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_emotion_notification_allows_non_eu if {
	not emotion_notification.violation with input as {"jurisdiction": "US", "text": "We deploy emotion recognition without notice to users"}
}

test_public_interest_text_blocks if {
	public_interest_text.violation with input as {"jurisdiction": "EU", "text": "We publish AI-generated news without disclosing it as AI"}
}

test_public_interest_text_allows_clean if {
	not public_interest_text.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_public_interest_text_allows_non_eu if {
	not public_interest_text.violation with input as {"jurisdiction": "US", "text": "We publish AI-generated news without disclosing it as AI"}
}

test_article50_aggregator_fires if {
	article50.violation with input as {"jurisdiction": "EU", "text": "We deploy emotion recognition without notice to users"}
}

test_article50_aggregator_clean if {
	not article50.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}
