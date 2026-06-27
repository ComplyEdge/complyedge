# ComplyEdge — Article 12 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article12_test

import rego.v1

import data.complyedge.article12.record_keeping
import data.complyedge.article12

# ============================================================
# Record Keeping — Article 12
# ============================================================

test_record_keeping_blocks_no_logging if {
	record_keeping.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy our high-risk AI system without automatic logging or any audit trail",
	}
}

test_record_keeping_blocks_disabled_logs if {
	record_keeping.violation with input as {
		"jurisdiction": "EU",
		"text": "Disable event logging on the biometric system to reduce storage costs",
	}
}

test_record_keeping_allows_logging if {
	not record_keeping.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI system with automatic event logging and traceability over its lifetime",
	}
}

test_record_keeping_allows_non_eu if {
	not record_keeping.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy our high-risk AI system without automatic logging or any audit trail",
	}
}

# ============================================================
# Aggregated Article 12 tests
# ============================================================

test_aggregated_article12_detects_violation if {
	article12.violation with input as {
		"jurisdiction": "EU",
		"text": "Operate high-risk AI without logs, traceability, or record-keeping",
	}
}

test_aggregated_article12_no_violation_for_safe_text if {
	not article12.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 12 record-keeping implemented with automatic logging for post-market monitoring",
	}
}
