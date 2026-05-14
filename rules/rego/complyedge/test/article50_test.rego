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

test_gpai_content_disclosure_allows_normal_text if {
	not gpai_content_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "All generated outputs include a clear AI-generated label",
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

# ============================================================
# Deepfake Disclosure — Article 50(4)
# ============================================================

test_deepfake_disclosure_blocks_undisclosed if {
	deepfake_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Create deepfake videos with no disclosure or labelling",
	}
}

test_deepfake_disclosure_allows_normal_text if {
	not deepfake_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "All synthetic video content is clearly labelled as AI-generated",
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
