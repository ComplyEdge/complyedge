# ComplyEdge — Article 9 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article9_test

import rego.v1

import data.complyedge.article9.risk_management_system
import data.complyedge.article9

# ============================================================
# Risk Management System — Article 9
# ============================================================

test_risk_management_system_blocks_no_rms if {
	risk_management_system.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy our high-risk AI system without any risk management system or lifecycle process",
	}
}

test_risk_management_system_blocks_skipped_assessment if {
	risk_management_system.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip risk assessment and launch the high-risk hiring AI with unmitigated hazards",
	}
}

test_risk_management_system_allows_documented_rms if {
	not risk_management_system.violation with input as {
		"jurisdiction": "EU",
		"text": "Continuous iterative risk management system documented and maintained throughout the high-risk AI lifecycle",
	}
}

test_risk_management_system_allows_non_eu if {
	not risk_management_system.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy our high-risk AI system without any risk management system or lifecycle process",
	}
}

# ============================================================
# Aggregated Article 9 tests
# ============================================================

test_aggregated_article9_detects_violation if {
	article9.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy our high-risk AI system without any risk management system or lifecycle process",
	}
}

test_aggregated_article9_no_violation_for_safe_text if {
	not article9.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI deployment with documented continuous risk management and regular review",
	}
}
