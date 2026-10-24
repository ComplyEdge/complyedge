# ComplyEdge: GPAI review tests (Articles 52, 53 and 55)
#
# Each positive below went the wrong way for a reason unrelated to meaning
# (a head noun after "GPAI", a plural, an article before the object) and
# passes because the pattern now reads the same words it was written for.
# Run with: opa test rules/rego/ -v

package complyedge.g3_review_test

import rego.v1

import data.complyedge.gpai.cybersecurity_gpai
import data.complyedge.gpai.incident_reporting
import data.complyedge.gpai.model_evaluation
import data.complyedge.gpai.risk_mitigation
import data.complyedge.gpai.training_summary

# Article 55(1)(d): a description of protection in place is not a violation.
test_cybersecurity_gpai_allows_protection_in_place if {
	not cybersecurity_gpai.violation with input as {
		"jurisdiction": "EU",
		"text": "The frontier model weights are encrypted at rest and access is limited to six named engineers.",
	}
}

# Chapter V binds in the EU only.
test_cybersecurity_gpai_allows_non_eu if {
	not cybersecurity_gpai.violation with input as {
		"jurisdiction": "US",
		"text": "We keep the systemic risk GPAI model without cybersecurity protection for now.",
	}
}

# Article 55(1)(c): an incident that was tracked and reported is lawful.
test_incident_reporting_allows_reported_incident if {
	not incident_reporting.violation with input as {
		"jurisdiction": "EU",
		"text": "Incident 2026-14 was logged, documented with the corrective patch, and reported to the AI Office on the same day.",
	}
}

test_incident_reporting_allows_non_eu if {
	not incident_reporting.violation with input as {
		"jurisdiction": "US",
		"text": "Skip incident reporting to the AI Office for the GPAI model.",
	}
}

test_model_evaluation_allows_non_eu if {
	not model_evaluation.violation with input as {
		"jurisdiction": "US",
		"text": "Ship the systemic risk GPAI model without red teaming this time.",
	}
}

test_risk_mitigation_allows_non_eu if {
	not risk_mitigation.violation with input as {
		"jurisdiction": "US",
		"text": "Release the systemic-risk GPAI model without mitigation measures for bio misuse.",
	}
}

# Article 53(1)(d) and Recital 104: the summary binds open-source providers too; publishing it is lawful.
test_training_summary_allows_published_summary if {
	not training_summary.violation with input as {
		"jurisdiction": "EU",
		"text": "Even though our model is open source under MIT, we still publish the training content summary required by Article 53(1)(d).",
	}
}

test_training_summary_allows_non_eu if {
	not training_summary.violation with input as {
		"jurisdiction": "US",
		"text": "Release the GPAI model without a training data summary.",
	}
}
