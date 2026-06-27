# ComplyEdge — Article 16 Rego Tests

package complyedge.article16_test

import rego.v1

import data.complyedge.article16.provider_obligations
import data.complyedge.article16

test_provider_obligations_blocks_no_ce if {
	provider_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "Place our high-risk AI system on the EU market without CE marking or conformity assessment",
	}
}

test_provider_obligations_blocks_no_qms if {
	provider_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "Launch high-risk hiring AI without quality management system or EU declaration of conformity",
	}
}

test_provider_obligations_allows_compliant if {
	not provider_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI placed on market with CE marking, conformity assessment, and provider identification complete",
	}
}

test_provider_obligations_allows_non_eu if {
	not provider_obligations.violation with input as {
		"jurisdiction": "US",
		"text": "Place our high-risk AI system on the EU market without CE marking or conformity assessment",
	}
}

test_aggregated_article16_detects_violation if {
	article16.violation with input as {
		"jurisdiction": "EU",
		"text": "Providing high-risk AI without provider registration or Annex IV documentation",
	}
}

test_aggregated_article16_no_violation_for_safe_text if {
	not article16.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 16 provider obligations satisfied before market placement",
	}
}
