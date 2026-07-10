# ComplyEdge — gpai new-rule tests (card M3.3-T2)
# Run with: opa test rules/rego/ -v

package complyedge.gpai_m33_test

import rego.v1

import data.complyedge.gpai.training_summary
import data.complyedge.gpai.sr_designation
import data.complyedge.gpai.model_evaluation
import data.complyedge.gpai.risk_mitigation
import data.complyedge.gpai.incident_reporting
import data.complyedge.gpai.cybersecurity_gpai
import data.complyedge.gpai

test_training_summary_blocks if {
	training_summary.violation with input as {"jurisdiction": "EU", "text": "The GPAI model ships without training data summary"}
}

test_training_summary_allows_clean if {
	not training_summary.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_training_summary_allows_non_eu if {
	not training_summary.violation with input as {"jurisdiction": "US", "text": "The GPAI model ships without training data summary"}
}

test_sr_designation_blocks if {
	sr_designation.violation with input as {"jurisdiction": "EU", "text": "We fail to notify the AI Office of systemic risk"}
}

test_sr_designation_allows_clean if {
	not sr_designation.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_sr_designation_allows_non_eu if {
	not sr_designation.violation with input as {"jurisdiction": "US", "text": "We fail to notify the AI Office of systemic risk"}
}

test_model_evaluation_blocks if {
	model_evaluation.violation with input as {"jurisdiction": "EU", "text": "We deploy a systemic-risk model without adversarial testing"}
}

test_model_evaluation_allows_clean if {
	not model_evaluation.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_model_evaluation_allows_non_eu if {
	not model_evaluation.violation with input as {"jurisdiction": "US", "text": "We deploy a systemic-risk model without adversarial testing"}
}

test_risk_mitigation_blocks if {
	risk_mitigation.violation with input as {"jurisdiction": "EU", "text": "We neglect to mitigate systemic risk in the model"}
}

test_risk_mitigation_allows_clean if {
	not risk_mitigation.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_risk_mitigation_allows_non_eu if {
	not risk_mitigation.violation with input as {"jurisdiction": "US", "text": "We neglect to mitigate systemic risk in the model"}
}

test_incident_reporting_blocks if {
	incident_reporting.violation with input as {"jurisdiction": "EU", "text": "We disable serious incident reporting for GPAI"}
}

test_incident_reporting_allows_clean if {
	not incident_reporting.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_incident_reporting_allows_non_eu if {
	not incident_reporting.violation with input as {"jurisdiction": "US", "text": "We disable serious incident reporting for GPAI"}
}

test_cybersecurity_gpai_blocks if {
	cybersecurity_gpai.violation with input as {"jurisdiction": "EU", "text": "A systemic-risk model without cybersecurity protection"}
}

test_cybersecurity_gpai_allows_clean if {
	not cybersecurity_gpai.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_cybersecurity_gpai_allows_non_eu if {
	not cybersecurity_gpai.violation with input as {"jurisdiction": "US", "text": "A systemic-risk model without cybersecurity protection"}
}

test_gpai_aggregator_fires if {
	gpai.violation with input as {"jurisdiction": "EU", "text": "The GPAI model ships without training data summary"}
}

test_gpai_aggregator_clean if {
	not gpai.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}
