# ComplyEdge: highrisk new-rule tests
# Run with: opa test rules/rego/ -v

package complyedge.highrisk_corpus_test

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

# Review 2026-10-21: five patterns made the negation optional, so the
# affirmative compliant statement matched ("training data representative ...",
# "accuracy validated ..."). The negation is now required. Each pair below: the
# review's compliant sentence is allowed (it blocked before the fix), and the
# negated sentence still blocks.

test_art9_allows_risk_management_implemented if {
	not art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Risk management implemented and signed off by the clinical safety officer on 12 May."}
}

test_art9_blocks_risk_management_not_implemented if {
	art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Risk management not implemented for the triage model."}
}

test_art10_allows_training_data_representative if {
	not art10_data_governance.violation with input as {"jurisdiction": "EU", "text": "Training data representative of all age groups, per the Article 10(3) review signed off on 4 June."}
}

test_art10_blocks_training_data_not_representative if {
	art10_data_governance.violation with input as {"jurisdiction": "EU", "text": "Training data not representative of rural applicants."}
}

test_art14_allows_human_oversight_implemented if {
	not art14_human_oversight.violation with input as {"jurisdiction": "EU", "text": "Human oversight implemented: reviewers can halt the scoring system with the stop button."}
}

test_art14_blocks_human_oversight_not_implemented if {
	art14_human_oversight.violation with input as {"jurisdiction": "EU", "text": "Human oversight not implemented on the loan approval flow."}
}

test_art15_accuracy_allows_accuracy_validated if {
	not art15_accuracy.violation with input as {"jurisdiction": "EU", "text": "Accuracy validated at 94% on the held-out test set; metrics are declared in the instructions for use."}
}

test_art15_accuracy_blocks_accuracy_not_validated if {
	art15_accuracy.violation with input as {"jurisdiction": "EU", "text": "Accuracy not validated before release."}
}

test_art15_robustness_allows_resilient_to_errors if {
	not art15_robustness.violation with input as {"jurisdiction": "EU", "text": "The robustness test report shows the system is resilient to errors and faults in its inputs."}
}

test_art15_robustness_blocks_not_resilient_to_errors if {
	art15_robustness.violation with input as {"jurisdiction": "EU", "text": "The model is not resilient to errors in sensor input."}
}

# The qualifier after the phrase is optional, so the phrase also fires at the
# end of a sentence. This did not fire before 2026-10-21: the pattern required
# a space after "management" even with no qualifier. (Art 15(4) keeps the
# space: "no redundancy." at the end also ends ordinary climbing advice.)
test_art9_fires_at_end_of_sentence if {
	art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Ship the credit scoring model without risk management."}
}
