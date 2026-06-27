# ComplyEdge — Article 4 Rego Tests

package complyedge.article4_test

import rego.v1

import data.complyedge.article4.ai_literacy
import data.complyedge.article4

test_ai_literacy_blocks_no_training if {
	ai_literacy.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy AI systems without any AI literacy training for staff or operators",
	}
}

test_ai_literacy_blocks_untrained_staff if {
	ai_literacy.violation with input as {
		"jurisdiction": "EU",
		"text": "Untrained employees operating our AI tool with no competence program required",
	}
}

test_ai_literacy_allows_program if {
	not ai_literacy.violation with input as {
		"jurisdiction": "EU",
		"text": "AI literacy program ensures trained staff operate AI systems with documented competence",
	}
}

test_ai_literacy_allows_non_eu if {
	not ai_literacy.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy AI systems without any AI literacy training for staff or operators",
	}
}

test_aggregated_article4_detects_violation if {
	article4.violation with input as {
		"jurisdiction": "EU",
		"text": "Roll out AI without staff training or AI literacy measures",
	}
}

test_aggregated_article4_no_violation_for_safe_text if {
	not article4.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 4 AI literacy requirements met for all operators",
	}
}
