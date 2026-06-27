# ComplyEdge — Article 21 Rego Tests

package complyedge.article21_test

import rego.v1

import data.complyedge.article21.authority_cooperation
import data.complyedge.article21

test_authority_cooperation_blocks_refusal if {
	authority_cooperation.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI provider will refuse to cooperate with competent authorities during market surveillance investigation",
	}
}

test_authority_cooperation_blocks_obstruction if {
	authority_cooperation.violation with input as {
		"jurisdiction": "EU",
		"text": "Obstruct the national authority inspection of our high-risk system",
	}
}

test_authority_cooperation_allows_cooperation if {
	not authority_cooperation.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk provider cooperates with competent authorities and provides requested documentation",
	}
}

test_authority_cooperation_allows_non_eu if {
	not authority_cooperation.violation with input as {
		"jurisdiction": "US",
		"text": "High-risk AI provider will refuse to cooperate with competent authorities during market surveillance investigation",
	}
}

test_aggregated_article21_detects_violation if {
	article21.violation with input as {
		"jurisdiction": "EU",
		"text": "Deny cooperation with market surveillance authority on high-risk AI system",
	}
}

test_aggregated_article21_no_violation_for_safe_text if {
	not article21.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 21 authority cooperation implemented for high-risk provider",
	}
}
