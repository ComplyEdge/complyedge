# ComplyEdge — Article 72 Rego Tests

package complyedge.article72_test

import rego.v1

import data.complyedge.article72.post_market_monitoring
import data.complyedge.article72

test_post_market_monitoring_blocks_no_plan if {
	post_market_monitoring.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy high-risk AI without post-market monitoring or any monitoring plan",
	}
}

test_post_market_monitoring_blocks_undocumented if {
	post_market_monitoring.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk system launched with post-market monitoring not established or documented",
	}
}

test_post_market_monitoring_allows_plan if {
	not post_market_monitoring.violation with input as {
		"jurisdiction": "EU",
		"text": "Post-market monitoring system established and documented for high-risk AI performance tracking",
	}
}

test_post_market_monitoring_allows_non_eu if {
	not post_market_monitoring.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy high-risk AI without post-market monitoring or any monitoring plan",
	}
}

test_aggregated_article72_detects_violation if {
	article72.violation with input as {
		"jurisdiction": "EU",
		"text": "Skip post-market monitoring for our high-risk hiring system",
	}
}

test_aggregated_article72_no_violation_for_safe_text if {
	not article72.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 72 post-market monitoring plan active and documented",
	}
}
