# ComplyEdge — Article 15 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article15_test

import rego.v1

import data.complyedge.article15.accuracy_robustness
import data.complyedge.article15

# ============================================================
# Accuracy Robustness — Article 15
# ============================================================

test_accuracy_robustness_blocks_no_testing if {
	accuracy_robustness.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy our high-risk AI system without accuracy testing or robustness validation",
	}
}

test_accuracy_robustness_blocks_adversarial_gap if {
	accuracy_robustness.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk credit model vulnerable to adversarial attacks with model poisoning not tested or mitigated",
	}
}

test_accuracy_robustness_allows_validated if {
	not accuracy_robustness.violation with input as {
		"jurisdiction": "EU",
		"text": "High-risk AI with documented accuracy levels, adversarial testing, and cybersecurity measures across lifecycle",
	}
}

test_accuracy_robustness_allows_non_eu if {
	not accuracy_robustness.violation with input as {
		"jurisdiction": "US",
		"text": "Deploy our high-risk AI system without accuracy testing or robustness validation",
	}
}

# ============================================================
# Aggregated Article 15 tests
# ============================================================

test_aggregated_article15_detects_violation if {
	article15.violation with input as {
		"jurisdiction": "EU",
		"text": "Place high-risk AI on market without cybersecurity protection or accuracy assessment",
	}
}

test_aggregated_article15_no_violation_for_safe_text if {
	not article15.violation with input as {
		"jurisdiction": "EU",
		"text": "Article 15 accuracy and robustness validated with resilience testing throughout lifecycle",
	}
}
