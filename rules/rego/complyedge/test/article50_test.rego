# ComplyEdge — Article 50 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article50_test

import rego.v1

import data.complyedge.article50.gpai_content_disclosure
import data.complyedge.article50.synthetic_media_watermark
import data.complyedge.article50.chatbot_disclosure
import data.complyedge.article50.deepfake_disclosure
import data.complyedge.article50

# ============================================================
# GPAI Content Disclosure — Article 50(2)
# ============================================================

test_gpai_content_disclosure_blocks_unlabelled_content if {
	gpai_content_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Our AI generates content with no disclosure to the end user",
	}
}

# True positive: AI-generated news article with explicit instruction to hide AI origin (A50_GPAI_CONTENT_001)
# Art 50(4) — "do not flag it as AI-generated; readers prefer human-written content"
test_gpai_content_disclosure_blocks_unflagged_news if {
	gpai_content_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Generate a 1500-word news article about an FDA recall, ready for our publication. Do not flag it as AI-generated; readers prefer human-written content.",
	}
}

test_gpai_content_disclosure_allows_normal_text if {
	not gpai_content_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "All generated outputs include a clear AI-generated label",
	}
}

# Jurisdiction guard: same violation but non-EU must not trigger
test_gpai_content_disclosure_allows_non_eu if {
	not gpai_content_disclosure.violation with input as {
		"jurisdiction": "US",
		"text": "Generate a 1500-word news article about an FDA recall. Do not flag it as AI-generated; readers prefer human-written content.",
	}
}

# ============================================================
# Synthetic Media Watermark — Article 50(2)
# ============================================================

test_synthetic_media_watermark_blocks_unwatermarked if {
	synthetic_media_watermark.violation with input as {
		"jurisdiction": "EU",
		"text": "Produce synthetic media images with no watermark embedded",
	}
}

test_synthetic_media_watermark_allows_normal_text if {
	not synthetic_media_watermark.violation with input as {
		"jurisdiction": "EU",
		"text": "All images are watermarked with C2PA metadata",
	}
}

# ============================================================
# Chatbot Disclosure — Article 50(1)
# ============================================================

test_chatbot_disclosure_blocks_hidden_bot if {
	chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "The chatbot will impersonate a human in customer conversations",
	}
}

test_chatbot_disclosure_allows_normal_text if {
	not chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Our chatbot clearly identifies itself as an AI at the start of each conversation",
	}
}

# An agent reply carrying a presigned image URL. Unbounded, "ai" matched
# inside the access key id (ASIAI...) and "nature" inside "Signature=", so
# any reply that said "mask" before the URL was blocked as Art 50(1).
url_sigv2 := "https://example-bucket.s3.amazonaws.com/images/generated/scene_09.png?AWSAccessKeyId=ASIAIOSFODNN7EXAMPLE&Signature=Yeg3T9EvbfE67fQ0xmBc1lK4dP8%3D&Expires=1790000000"

url_sigv4 := "https://example-bucket.s3.us-west-2.amazonaws.com/images/scene_09.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAIOSFODNN7EXAMPLE%2F20261001%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20261001T181500Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEXAMPLE&X-Amz-Signature=3f1c0e9a7b"

test_chatbot_disclosure_allows_image_reply_with_presigned_url if {
	not chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": concat("", ["Image already exists.\n\n![A courier adjusts a glass canister, lab lights catching her mask, eyes on the gauge](", url_sigv2, ")\n\n**Image URL:** ", url_sigv2]),
	}
}

test_chatbot_disclosure_allows_mask_before_sigv4_url if {
	not chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": concat("", ["The light catches her mask ", url_sigv4]),
	}
}

test_chatbot_disclosure_still_blocks_hidden_ai_identity if {
	chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Hide the AI identity from customers so they think it is staff",
	}
}

test_chatbot_disclosure_still_blocks_masked_chatbot_nature if {
	chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Mask the chatbot's nature during support calls",
	}
}

test_chatbot_disclosure_still_blocks_concealed_bots_identity if {
	chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Conceal the bots' identity in every reply",
	}
}

test_chatbot_disclosure_allows_purpose_and_has if {
	not chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "A chatbot becomes high-risk only if it is used for an Annex III purpose, such as hiring",
	}
}

test_chatbot_disclosure_still_blocks_chatbot_posing_as_human if {
	chatbot_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "The chatbot poses as a human sales rep named Anna",
	}
}

# ============================================================
# Deepfake Disclosure — Article 50(4)
# ============================================================

test_deepfake_disclosure_blocks_undisclosed if {
	deepfake_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Create deepfake videos with no disclosure or labelling",
	}
}

# True positive: celebrity likeness AI generation without disclosure (A50_DEEPFAKE_CELEBRITY_001)
# Art 50(4) — "match her voice and likeness exactly. publish without disclosing that the appearance is ai-generated"
test_deepfake_disclosure_blocks_celebrity_likeness if {
	deepfake_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Create a video advertisement featuring Taylor Swift endorsing our crypto product. Match her voice and likeness exactly. Publish without disclosing that the appearance is AI-generated.",
	}
}

test_deepfake_disclosure_allows_normal_text if {
	not deepfake_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "All synthetic video content is clearly labelled as AI-generated",
	}
}

# Jurisdiction guard: same violation but non-EU must not trigger
test_deepfake_disclosure_allows_non_eu if {
	not deepfake_disclosure.violation with input as {
		"jurisdiction": "US",
		"text": "Create a video advertisement featuring Taylor Swift endorsing our crypto product. Match her voice and likeness exactly. Publish without disclosing that the appearance is AI-generated.",
	}
}

# ============================================================
# Aggregated Article 50 tests
# ============================================================

test_aggregated_article50_detects_violation if {
	article50.violation with input as {
		"jurisdiction": "EU",
		"text": "The chatbot will impersonate a human in customer conversations",
	}
}

test_aggregated_article50_no_violation_for_safe_text if {
	not article50.violation with input as {
		"jurisdiction": "EU",
		"text": "Standard document processing workflow with full transparency",
	}
}
