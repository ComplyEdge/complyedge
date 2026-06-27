# ComplyEdge — Article 10 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article10_test

import rego.v1

import data.complyedge.article10.data_governance
import data.complyedge.article10

# ============================================================
# Data Governance — Article 10
# ============================================================

test_data_governance_blocks_unvetted_training_data if {
	data_governance.violation with input as {
		"jurisdiction": "EU",
		"text": "Train our high-risk hiring AI on biased unrepresentative training data with no data governance",
	}
}

test_data_governance_blocks_skipped_bias_review if {
	data_governance.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip bias assessment and deploy with incomplete validation datasets for the high-risk system",
	}
}

test_data_governance_allows_governed_datasets if {
	not data_governance.violation with input as {
		"jurisdiction": "EU",
		"text": "Representative training data examined for bias with documented data governance across validation and testing sets",
	}
}

test_data_governance_allows_non_eu if {
	not data_governance.violation with input as {
		"jurisdiction": "US",
		"text": "Train our high-risk hiring AI on biased unrepresentative training data with no data governance",
	}
}

# ============================================================
# Aggregated Article 10 tests
# ============================================================

test_aggregated_article10_detects_violation if {
	article10.violation with input as {
		"jurisdiction": "EU",
		"text": "Train our high-risk hiring AI on biased unrepresentative training data with no data governance",
	}
}

test_aggregated_article10_no_violation_for_safe_text if {
	not article10.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI trained on representative datasets with bias examination and complete data governance",
	}
}
