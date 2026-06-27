# ComplyEdge — Article 27 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article27_test

import rego.v1

import data.complyedge.article27.fria
import data.complyedge.article27

# ============================================================
# FRIA — Article 27
# ============================================================

test_fria_blocks_no_assessment if {
	fria.violation with input as {
		"jurisdiction": "EU",
		"text": "Public body deploying high-risk AI without fundamental rights impact assessment before deployment",
	}
}

test_fria_blocks_skipped_fria if {
	fria.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip FRIA and roll out high-risk hiring system to public service users",
	}
}

test_fria_allows_assessment if {
	not fria.violation with input as {
		"jurisdiction": "EU",
		"text": "Fundamental rights impact assessment completed and market surveillance authority notified before high-risk deployment",
	}
}

test_fria_allows_non_eu if {
	not fria.violation with input as {
		"jurisdiction": "US",
		"text": "Public body deploying high-risk AI without fundamental rights impact assessment before deployment",
	}
}

# ============================================================
# Aggregated Article 27 tests
# ============================================================

test_aggregated_article27_detects_violation if {
	article27.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploying without FRIA — fundamental rights not assessed for Annex III high-risk system",
	}
}

test_aggregated_article27_no_violation_for_safe_text if {
	not article27.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 27 FRIA performed with affected persons, risks, and oversight documented before deployment",
	}
}
