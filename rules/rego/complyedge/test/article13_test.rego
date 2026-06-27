# ComplyEdge — Article 13 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article13_test

import rego.v1

import data.complyedge.article13.transparency_deployers
import data.complyedge.article13

# ============================================================
# Transparency Deployers — Article 13
# ============================================================

test_transparency_deployers_blocks_no_instructions if {
	transparency_deployers.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy our high-risk hiring AI to customers without instructions for use or deployer documentation",
	}
}

test_transparency_deployers_blocks_hidden_limits if {
	transparency_deployers.violation with input as {
		"jurisdiction": "EU",
		"text": "Ship the black-box high-risk credit scoring system with hidden accuracy limitations and no transparency disclosure",
	}
}

test_transparency_deployers_allows_complete_docs if {
	not transparency_deployers.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI supplied with complete instructions for use covering capabilities, limitations, accuracy levels, and human oversight",
	}
}

test_transparency_deployers_allows_non_eu if {
	not transparency_deployers.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy our high-risk hiring AI to customers without instructions for use or deployer documentation",
	}
}

# ============================================================
# Aggregated Article 13 tests
# ============================================================

test_aggregated_article13_detects_violation if {
	article13.violation with input as {
		"jurisdiction": "EU",
		"text": "Provide high-risk AI without transparency information or deployer instructions for use",
	}
}

test_aggregated_article13_no_violation_for_safe_text if {
	not article13.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 13 transparency requirements met with deployer instructions for use and disclosed performance levels",
	}
}
