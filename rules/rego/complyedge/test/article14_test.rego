# ComplyEdge — Article 14 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article14_test

import rego.v1

import data.complyedge.article14.human_oversight
import data.complyedge.article14

# ============================================================
# Human Oversight — Article 14
# ============================================================

test_human_oversight_blocks_no_oversight if {
	human_oversight.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy our high-risk hiring AI without human oversight or any supervision",
	}
}

test_human_oversight_blocks_no_override if {
	human_oversight.violation with input as {
		"jurisdiction": "EU",
		"text": "Fully autonomous high-risk credit decision system with no stop button and operators cannot override the AI output",
	}
}

test_human_oversight_allows_oversight if {
	not human_oversight.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI designed with human oversight enabling monitor, override, and interrupt via stop mechanism",
	}
}

test_human_oversight_allows_non_eu if {
	not human_oversight.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy our high-risk hiring AI without human oversight or any supervision",
	}
}

# ============================================================
# Aggregated Article 14 tests
# ============================================================

test_aggregated_article14_detects_violation if {
	article14.violation with input as {
		"jurisdiction": "EU",
		"text": "Operate unsupervised high-risk AI deployment without human intervention capability",
	}
}

test_aggregated_article14_no_violation_for_safe_text if {
	not article14.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 14 human oversight implemented with trained operators who can monitor and override outputs",
	}
}
