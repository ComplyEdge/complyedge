# ComplyEdge — Article 50 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article50_test

import rego.v1

import data.complyedge.article50.gpai_content_disclosure
import data.complyedge.article50.synthetic_media_watermark
import data.complyedge.article50.chatbot_disclosure
import data.complyedge.article50.deepfake_disclosure
import data.complyedge.article50.emotion_recognition_disclosure
import data.complyedge.article50.deepfake_audio
import data.complyedge.article50.provider_transparency_tools
import data.complyedge.article50.public_interest_text
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
# Deepfake Audio — Article 50(4) audio variant
# ============================================================

test_deepfake_audio_blocks_voice_clone if {
	deepfake_audio.violation with input as {
		"jurisdiction": "EU",
		"text": "Clone the CEO voice for the earnings call audio without any disclosure or audio watermark",
	}
}

test_deepfake_audio_blocks_synthetic_podcast if {
	deepfake_audio.violation with input as {
		"jurisdiction": "EU",
		"text": "Generate AI synthetic podcast speech impersonating a politician with no label or disclosure marker",
	}
}

test_deepfake_audio_allows_labelled if {
	not deepfake_audio.violation with input as {
		"jurisdiction": "EU",
		"text": "Synthetic voice audio clearly labelled as AI-generated speech with audible disclosure before playback",
	}
}

test_deepfake_audio_allows_non_eu if {
	not deepfake_audio.violation with input as {
		"jurisdiction": "US",
		"text": "Clone the CEO voice for the earnings call audio without any disclosure or audio watermark",
	}
}

# ============================================================
# Provider Transparency Tools — Article 50(5)
# ============================================================

test_provider_transparency_tools_blocks_delayed_disclosure if {
	provider_transparency_tools.violation with input as {
		"jurisdiction": "EU",
		"text": "Hide AI chatbot disclosure until after the first interaction so users feel it is human",
	}
}

test_provider_transparency_tools_blocks_no_detection_tools if {
	provider_transparency_tools.violation with input as {
		"jurisdiction": "EU",
		"text": "GPAI provider ships synthetic content without detection tools or marking solutions available at first exposure",
	}
}

test_provider_transparency_tools_allows_first_exposure if {
	not provider_transparency_tools.violation with input as {
		"jurisdiction": "EU",
		"text": "Clear distinguishable AI transparency notice at first interaction with accessible detection methods for marked content",
	}
}

test_provider_transparency_tools_allows_non_eu if {
	not provider_transparency_tools.violation with input as {
		"jurisdiction": "US",
		"text": "Hide AI chatbot disclosure until after the first interaction so users feel it is human",
	}
}

# ============================================================
# Public Interest Text — Article 50(4) text variant
# ============================================================

test_public_interest_text_blocks_undisclosed if {
	public_interest_text.violation with input as {
		"jurisdiction": "EU",
		"text": "Generate AI-generated news article on public interest matters without disclosure or AI label",
	}
}

test_public_interest_text_blocks_do_not_flag if {
	public_interest_text.violation with input as {
		"jurisdiction": "EU",
		"text": "Publish AI-generated public interest text — do not flag as AI-generated; readers prefer human-written content",
	}
}

test_public_interest_text_allows_disclosed if {
	not public_interest_text.violation with input as {
		"jurisdiction": "EU",
		"text": "Public interest article clearly labelled as AI-generated text with editorial disclosure",
	}
}

test_public_interest_text_allows_non_eu if {
	not public_interest_text.violation with input as {
		"jurisdiction": "US",
		"text": "Generate AI-generated news article on public interest matters without disclosure or AI label",
	}
}

# ============================================================
# Emotion Recognition Disclosure — Article 50(3)
# ============================================================

test_emotion_recognition_disclosure_blocks_undisclosed if {
	emotion_recognition_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Run emotion detection on retail store visitors via camera without disclosure or informing customers",
	}
}

test_emotion_recognition_disclosure_blocks_covert if {
	emotion_recognition_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy covert emotion recognition monitoring with no notice to exposed persons",
	}
}

test_emotion_recognition_disclosure_allows_disclosed if {
	not emotion_recognition_disclosure.violation with input as {
		"jurisdiction": "EU",
		"text": "Emotion recognition system deployed with clear notice informing all visitors of system operation and GDPR-compliant processing",
	}
}

test_emotion_recognition_disclosure_allows_non_eu if {
	not emotion_recognition_disclosure.violation with input as {
		"jurisdiction": "US",
		"text": "Run emotion detection on retail store visitors via camera without disclosure or informing customers",
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
