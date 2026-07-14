# ComplyEdge — additional leaf tests
# Run with: opa test rules/rego/ -v

package complyedge.m33_t3_test

import rego.v1

import data.complyedge.gpai.open_source_exemption
import data.complyedge.article6.art6_3_procedural_derogation
import data.complyedge.article6.annex3_5b_creditworthiness
import data.complyedge.article6.annex3_5c_insurance
import data.complyedge.article50.emotion_permitted_context_notice
import data.complyedge.gpai
import data.complyedge.article6
import data.complyedge.article50

# --- Art 53(2) open-source exemption boundary ---

test_open_source_exemption_blocks if {
	open_source_exemption.violation with input as {"jurisdiction": "EU", "text": "Our open-source GPAI claims a 53(2) exemption without public weights"}
}

test_open_source_exemption_allows_clean if {
	not open_source_exemption.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_open_source_exemption_allows_non_eu if {
	not open_source_exemption.violation with input as {"jurisdiction": "US", "text": "Our open-source GPAI claims a 53(2) exemption without public weights"}
}

# --- Art 6(3) procedural derogation misuse ---

test_art6_3_blocks if {
	art6_3_procedural_derogation.violation with input as {"jurisdiction": "EU", "text": "We claim Article 6(3) narrow procedural task while fully automated credit decision without human assessment"}
}

test_art6_3_allows_clean if {
	not art6_3_procedural_derogation.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art6_3_allows_non_eu if {
	not art6_3_procedural_derogation.violation with input as {"jurisdiction": "US", "text": "We claim Article 6(3) narrow procedural task while fully automated credit decision without human assessment"}
}

# --- Annex III(5)(b) creditworthiness ---

test_annex3_5b_blocks if {
	annex3_5b_creditworthiness.violation with input as {"jurisdiction": "EU", "text": "Deploy an AI credit scoring system for natural persons"}
}

test_annex3_5b_allows_clean if {
	not annex3_5b_creditworthiness.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_annex3_5b_allows_non_eu if {
	not annex3_5b_creditworthiness.violation with input as {"jurisdiction": "US", "text": "Deploy an AI credit scoring system for natural persons"}
}

# --- Annex III(5)(c) insurance ---

test_annex3_5c_blocks if {
	annex3_5c_insurance.violation with input as {"jurisdiction": "EU", "text": "AI life insurance risk assessment and pricing for natural persons"}
}

test_annex3_5c_allows_clean if {
	not annex3_5c_insurance.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_annex3_5c_allows_non_eu if {
	not annex3_5c_insurance.violation with input as {"jurisdiction": "US", "text": "AI life insurance risk assessment and pricing for natural persons"}
}

# --- Art 5(1)(f) exception + Art 50(3) permitted-context notice ---

test_emotion_permitted_notice_blocks if {
	emotion_permitted_context_notice.violation with input as {"jurisdiction": "EU", "text": "Deploy emotion recognition for medical safety without notice to persons"}
}

test_emotion_permitted_notice_allows_clean if {
	not emotion_permitted_context_notice.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_emotion_permitted_notice_allows_non_eu if {
	not emotion_permitted_context_notice.violation with input as {"jurisdiction": "US", "text": "Deploy emotion recognition for medical safety without notice to persons"}
}

# --- Aggregators fire ---

test_gpai_aggregator_fires_open_source if {
	gpai.violation with input as {"jurisdiction": "EU", "text": "Our open-source GPAI claims a 53(2) exemption without public weights"}
}

test_article6_aggregator_fires_credit if {
	article6.violation with input as {"jurisdiction": "EU", "text": "Deploy an AI credit scoring system for natural persons"}
}

test_article50_aggregator_fires_emotion_notice if {
	article50.violation with input as {"jurisdiction": "EU", "text": "Deploy emotion recognition for medical safety without notice to persons"}
}
