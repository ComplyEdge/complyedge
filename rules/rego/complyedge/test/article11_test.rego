# ComplyEdge — Article 11 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article11_test

import rego.v1

import data.complyedge.article11.technical_documentation
import data.complyedge.article11

# ============================================================
# Technical Documentation — Article 11
# ============================================================

test_technical_documentation_blocks_no_annex_iv if {
	technical_documentation.violation with input as {
		"jurisdiction": "EU",
		"text": "Place our high-risk AI system on the market without any Annex IV technical documentation",
	}
}

test_technical_documentation_blocks_skipped_docs if {
	technical_documentation.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip technical documentation and launch the high-risk hiring system before market placement",
	}
}

test_technical_documentation_allows_annex_iv if {
	not technical_documentation.violation with input as {
		"jurisdiction": "EU",
		"text": "Annex IV technical documentation drawn up and maintained before high-risk AI market placement",
	}
}

test_technical_documentation_allows_non_eu if {
	not technical_documentation.violation with input as {
		"jurisdiction": "US",
		"text": "Place our high-risk AI system on the market without any Annex IV technical documentation",
	}
}

# ============================================================
# Aggregated Article 11 tests
# ============================================================

test_aggregated_article11_detects_violation if {
	article11.violation with input as {
		"jurisdiction": "EU",
		"text": "Place our high-risk AI system on the market without any Annex IV technical documentation",
	}
}

test_aggregated_article11_no_violation_for_safe_text if {
	not article11.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI deployed with complete Annex IV technical documentation prepared before market placement",
	}
}
