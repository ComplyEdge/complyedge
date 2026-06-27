# ComplyEdge — Article 26 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article26_test

import rego.v1

import data.complyedge.article26.deployer_obligations
import data.complyedge.article26

# ============================================================
# Deployer Obligations — Article 26
# ============================================================

test_deployer_obligations_blocks_no_instructions if {
	deployer_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "Deployer operating high-risk hiring AI without instructions for use or deployer compliance",
	}
}

test_deployer_obligations_blocks_no_log_retention if {
	deployer_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk deployer failing to keep logs and no log retention for six months",
	}
}

test_deployer_obligations_allows_compliant if {
	not deployer_obligations.violation with input as {
		"jurisdiction": "EU",
		"text": "Deployer uses high-risk AI per instructions with trained oversight, monitoring, and six-month log retention",
	}
}

test_deployer_obligations_allows_non_eu if {
	not deployer_obligations.violation with input as {
		"jurisdiction": "US",
		"text": "Deployer operating high-risk hiring AI without instructions for use or deployer compliance",
	}
}

# ============================================================
# Aggregated Article 26 tests
# ============================================================

test_aggregated_article26_detects_violation if {
	article26.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploying high-risk AI without monitoring or competent human oversight at workplace",
	}
}

test_aggregated_article26_no_violation_for_safe_text if {
	not article26.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 26 deployer obligations met with instructions for use, oversight, and automatic logs kept six months",
	}
}
