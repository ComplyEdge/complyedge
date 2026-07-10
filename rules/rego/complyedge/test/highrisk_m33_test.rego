# ComplyEdge — highrisk new-rule tests (card M3.3-T2)
# Run with: opa test rules/rego/ -v

package complyedge.highrisk_m33_test

import rego.v1

import data.complyedge.highrisk.art4_ai_literacy
import data.complyedge.highrisk.art9_risk_management
import data.complyedge.highrisk.art10_data_governance
import data.complyedge.highrisk.art11_technical_documentation
import data.complyedge.highrisk.art12_record_keeping
import data.complyedge.highrisk.art13_transparency
import data.complyedge.highrisk.art14_human_oversight
import data.complyedge.highrisk.art15_accuracy
import data.complyedge.highrisk.art15_robustness
import data.complyedge.highrisk.art15_cybersecurity
import data.complyedge.highrisk.art16_provider_obligations
import data.complyedge.highrisk.art26_deployer_obligations
import data.complyedge.highrisk.art27_fria
import data.complyedge.highrisk

test_art4_ai_literacy_blocks if {
	art4_ai_literacy.violation with input as {"jurisdiction": "EU", "text": "Staff operating AI without AI literacy training"}
}

test_art4_ai_literacy_allows_clean if {
	not art4_ai_literacy.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art4_ai_literacy_allows_non_eu if {
	not art4_ai_literacy.violation with input as {"jurisdiction": "US", "text": "Staff operating AI without AI literacy training"}
}

test_art9_risk_management_blocks if {
	art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "We deploy high-risk AI without risk management system"}
}

test_art9_risk_management_allows_clean if {
	not art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art9_risk_management_allows_non_eu if {
	not art9_risk_management.violation with input as {"jurisdiction": "US", "text": "We deploy high-risk AI without risk management system"}
}

test_art10_data_governance_blocks if {
	art10_data_governance.violation with input as {"jurisdiction": "EU", "text": "The model is trained on biased training data"}
}

test_art10_data_governance_allows_clean if {
	not art10_data_governance.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art10_data_governance_allows_non_eu if {
	not art10_data_governance.violation with input as {"jurisdiction": "US", "text": "The model is trained on biased training data"}
}

test_art11_technical_documentation_blocks if {
	art11_technical_documentation.violation with input as {"jurisdiction": "EU", "text": "We ship high-risk AI without technical documentation"}
}

test_art11_technical_documentation_allows_clean if {
	not art11_technical_documentation.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art11_technical_documentation_allows_non_eu if {
	not art11_technical_documentation.violation with input as {"jurisdiction": "US", "text": "We ship high-risk AI without technical documentation"}
}

test_art12_record_keeping_blocks if {
	art12_record_keeping.violation with input as {"jurisdiction": "EU", "text": "We disable logging for high-risk AI"}
}

test_art12_record_keeping_allows_clean if {
	not art12_record_keeping.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art12_record_keeping_allows_non_eu if {
	not art12_record_keeping.violation with input as {"jurisdiction": "US", "text": "We disable logging for high-risk AI"}
}

test_art13_transparency_blocks if {
	art13_transparency.violation with input as {"jurisdiction": "EU", "text": "We provide high-risk AI without instructions for use"}
}

test_art13_transparency_allows_clean if {
	not art13_transparency.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art13_transparency_allows_non_eu if {
	not art13_transparency.violation with input as {"jurisdiction": "US", "text": "We provide high-risk AI without instructions for use"}
}

test_art14_human_oversight_blocks if {
	art14_human_oversight.violation with input as {"jurisdiction": "EU", "text": "A fully autonomous high-risk AI without human oversight"}
}

test_art14_human_oversight_allows_clean if {
	not art14_human_oversight.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art14_human_oversight_allows_non_eu if {
	not art14_human_oversight.violation with input as {"jurisdiction": "US", "text": "A fully autonomous high-risk AI without human oversight"}
}

test_art15_accuracy_blocks if {
	art15_accuracy.violation with input as {"jurisdiction": "EU", "text": "The system is deployed without declared accuracy metrics"}
}

test_art15_accuracy_allows_clean if {
	not art15_accuracy.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art15_accuracy_allows_non_eu if {
	not art15_accuracy.violation with input as {"jurisdiction": "US", "text": "The system is deployed without declared accuracy metrics"}
}

test_art15_robustness_blocks if {
	art15_robustness.violation with input as {"jurisdiction": "EU", "text": "The system runs without fail-safe redundancy"}
}

test_art15_robustness_allows_clean if {
	not art15_robustness.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art15_robustness_allows_non_eu if {
	not art15_robustness.violation with input as {"jurisdiction": "US", "text": "The system runs without fail-safe redundancy"}
}

test_art15_cybersecurity_blocks if {
	art15_cybersecurity.violation with input as {"jurisdiction": "EU", "text": "The high-risk AI is vulnerable to data poisoning attacks"}
}

test_art15_cybersecurity_allows_clean if {
	not art15_cybersecurity.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art15_cybersecurity_allows_non_eu if {
	not art15_cybersecurity.violation with input as {"jurisdiction": "US", "text": "The high-risk AI is vulnerable to data poisoning attacks"}
}

test_art16_provider_obligations_blocks if {
	art16_provider_obligations.violation with input as {"jurisdiction": "EU", "text": "We place high-risk AI without CE marking"}
}

test_art16_provider_obligations_allows_clean if {
	not art16_provider_obligations.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art16_provider_obligations_allows_non_eu if {
	not art16_provider_obligations.violation with input as {"jurisdiction": "US", "text": "We place high-risk AI without CE marking"}
}

test_art26_deployer_obligations_blocks if {
	art26_deployer_obligations.violation with input as {"jurisdiction": "EU", "text": "We are deploying high-risk AI without oversight"}
}

test_art26_deployer_obligations_allows_clean if {
	not art26_deployer_obligations.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art26_deployer_obligations_allows_non_eu if {
	not art26_deployer_obligations.violation with input as {"jurisdiction": "US", "text": "We are deploying high-risk AI without oversight"}
}

test_art27_fria_blocks if {
	art27_fria.violation with input as {"jurisdiction": "EU", "text": "Deployment without fundamental rights impact assessment"}
}

test_art27_fria_allows_clean if {
	not art27_fria.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_art27_fria_allows_non_eu if {
	not art27_fria.violation with input as {"jurisdiction": "US", "text": "Deployment without fundamental rights impact assessment"}
}

test_highrisk_aggregator_fires if {
	highrisk.violation with input as {"jurisdiction": "EU", "text": "Staff operating AI without AI literacy training"}
}

test_highrisk_aggregator_clean if {
	not highrisk.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}
