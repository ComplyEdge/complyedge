# ComplyEdge: Layer 1 detects claims, high-risk and data protection leaves
#
# RULE_STANDARD §3.1 (v1.4): every phrasing and format a leaf's
# "Layer 1 detects:" paragraph names must match. One test per named form,
# written in the paragraph's own words, plus a jurisdiction guard per leaf.
# Every identifier below was computed with an independent checksum
# implementation (Luhn, ISO 13616 mod 97, ISO 7064 MOD 11,10, mod 23, NIR
# mod 97, codice fiscale tables, eleven test), never by the rule under test.
# Run with: opa test rules/rego/ -v --run layer1_detects

package complyedge.layer1_detects_highrisk_dp_test

import rego.v1

import data.complyedge.data_protection.api_key
import data.complyedge.data_protection.card_pan
import data.complyedge.data_protection.email
import data.complyedge.data_protection.iban
import data.complyedge.data_protection.national_id_de
import data.complyedge.data_protection.national_id_es
import data.complyedge.data_protection.national_id_fr
import data.complyedge.data_protection.national_id_it
import data.complyedge.data_protection.national_id_nl
import data.complyedge.data_protection.phone
import data.complyedge.data_protection.private_key
import data.complyedge.highrisk.art10_data_governance as art10
import data.complyedge.highrisk.art11_technical_documentation as art11
import data.complyedge.highrisk.art12_record_keeping as art12
import data.complyedge.highrisk.art13_transparency as art13
import data.complyedge.highrisk.art14_human_oversight as art14
import data.complyedge.highrisk.art15_accuracy as art15_acc
import data.complyedge.highrisk.art15_cybersecurity as art15_cyb
import data.complyedge.highrisk.art15_robustness as art15_rob
import data.complyedge.highrisk.art16_provider_obligations as art16
import data.complyedge.highrisk.art26_deployer_obligations as art26
import data.complyedge.highrisk.art27_fria as art27
import data.complyedge.highrisk.art4_ai_literacy as art4
import data.complyedge.highrisk.art9_risk_management as art9

eu(text) := {"text": text, "jurisdiction": "EU"}

us(text) := {"text": text, "jurisdiction": "US"}

# ---- rego-art4-001 ----

test_art4_skip_ai_literacy_training if art4.violation with input as eu("Skip AI literacy training for the new hires.")

test_art4_no_ai_literacy_measures if art4.violation with input as eu("No AI literacy measures are planned this year.")

test_art4_neglecting_ai_literacy_program if art4.violation with input as eu("We are neglecting AI literacy programs this quarter.")

test_art4_without_ai_literacy_training if art4.violation with input as eu("Roll it out without AI literacy training.")

test_art4_staff_using_ai_without_literacy_training if art4.violation with input as eu("Staff using AI without literacy training is fine for now.")

test_art4_staff_deploying_ai_lacking_ai_literacy_competence if art4.violation with input as eu("Staff deploying AI lacking AI literacy competence will run the pilot.")

test_art4_allows_non_eu if not art4.violation with input as us("Skip AI literacy training for the new hires.")

# ---- rego-art9-001 ----

test_art9_bypass_risk_management if art9.violation with input as eu("Bypass risk management and go live.")

test_art9_skipping_risk_management if art9.violation with input as eu("We are skipping risk management for this release.")

test_art9_no_risk_management_system if art9.violation with input as eu("There is no risk management system yet.")

test_art9_high_risk_ai_lacking_lifecycle_risk if art9.violation with input as eu("A high-risk AI system lacking lifecycle risk controls.")

test_art9_highrisk_ai_no_risk_management if art9.violation with input as eu("Our high risk AI no risk management, ship it.")

test_art9_risk_management_not_established if art9.violation with input as eu("Risk management not established for the scorer.")

test_art9_risk_management_implemented_false if art9.violation with input as eu("risk management implemented false.")

test_art9_allows_non_eu if not art9.violation with input as us("Bypass risk management and go live.")

# ---- rego-art10-001 ----

test_art10_training_data_not_representative if art10.violation with input as eu("The training data not representative of women is fine.")

test_art10_training_data_unvetted if art10.violation with input as eu("Use the training data unvetted.")

test_art10_inadequate_data_governance_for_high_risk if art10.violation with input as eu("Inadequate data governance for high-risk scoring is acceptable.")

test_art10_no_data_governance_on_training_data if art10.violation with input as eu("No data governance on training data this sprint.")

test_art10_biased_datasets if art10.violation with input as eu("Train it on the biased datasets.")

test_art10_unrepresentative_training_sample if art10.violation with input as eu("An unrepresentative training sample will do.")

test_art10_allows_non_eu if not art10.violation with input as us("Train it on the biased datasets.")

# ---- rego-art11-001 ----

test_art11_high_risk_ai_system_without_technical_documentation if art11.violation with input as eu("Ship the high-risk AI system without technical documentation.")

test_art11_high_risk_ai_lacking_technical_documentation if art11.violation with input as eu("A high risk AI lacking technical documentation.")

test_art11_skip_annex_iv_technical_documentation_for_high_risk if art11.violation with input as eu("Skip Annex IV technical documentation for high-risk models.")

test_art11_missing_technical_documentation_ai_system if art11.violation with input as eu("Missing technical documentation AI system goes live Monday.")

test_art11_allows_non_eu if not art11.violation with input as us("Ship the high-risk AI system without technical documentation.")

# ---- rego-art12-001 ----

test_art12_disable_logging_for_ai_system if art12.violation with input as eu("Disable logging for AI system calls to save money.")

test_art12_turn_off_audit_log_on_high_risk_ai if art12.violation with input as eu("Turn off audit log on high-risk AI tonight.")

test_art12_skip_recordkeeping_in_ai_system if art12.violation with input as eu("Skip recordkeeping in AI system deployments.")

test_art12_bypass_event_log_for_ai_system if art12.violation with input as eu("Bypass event log for AI system calls.")

test_art12_high_risk_ai_system_without_automatic_event_logging if art12.violation with input as eu("A high-risk AI system without automatic event logging.")

test_art12_allows_non_eu if not art12.violation with input as us("Disable logging for AI system calls to save money.")

# ---- rego-art13-001 ----

test_art13_without_instructions_for_use if art13.violation with input as eu("Ship it to deployers without instructions for use.")

test_art13_no_instruction_for_use if art13.violation with input as eu("No instruction for use is needed.")

test_art13_without_deployer_documentation if art13.violation with input as eu("Send it without deployer documentation.")

test_art13_no_transparency_information if art13.violation with input as eu("No transparency information for the bank.")

test_art13_high_risk_ai_no_transparency if art13.violation with input as eu("High-risk AI no transparency, ship today.")

test_art13_allows_non_eu if not art13.violation with input as us("Ship it to deployers without instructions for use.")

# ---- rego-art14-001 ----

test_art14_without_human_review if art14.violation with input as eu("Decide loans without human review.")

test_art14_no_human_intervention if art14.violation with input as eu("Rejections go out with no human intervention.")

test_art14_fully_autonomous_high_risk_ai_no_human_in_the_loop if art14.violation with input as eu("Fully autonomous high-risk AI no human in the loop.")

test_art14_human_oversight_not_possible if art14.violation with input as eu("Human oversight not possible in the batch job.")

test_art14_human_oversight_provided_no if art14.violation with input as eu("human oversight provided no.")

test_art14_allows_non_eu if not art14.violation with input as us("Decide loans without human review.")

# ---- rego-art15-1-001 ----

test_art15_acc_no_declared_accuracy_metrics if art15_acc.violation with input as eu("Ship with no declared accuracy metrics.")

test_art15_acc_without_accuracy_validation if art15_acc.violation with input as eu("Release it without accuracy validation.")

test_art15_acc_accuracy_not_tested if art15_acc.violation with input as eu("Accuracy not tested before launch.")

test_art15_acc_accuracy_documented_false if art15_acc.violation with input as eu("accuracy documented false.")

test_art15_acc_allows_non_eu if not art15_acc.violation with input as us("Ship with no declared accuracy metrics.")

# ---- rego-art15-5-001 ----

test_art15_cyb_inadequate_cybersecurity_for_high_risk_ai if art15_cyb.violation with input as eu("Inadequate cybersecurity for high-risk AI is accepted.")

test_art15_cyb_no_cybersecurity_the_ai_system if art15_cyb.violation with input as eu("Ship with no cybersecurity the AI system can rely on.")

test_art15_cyb_vulnerable_to_data_poisoning_attacks if art15_cyb.violation with input as eu("The model is vulnerable to data poisoning attacks, ship anyway.")

test_art15_cyb_vulnerable_to_evasion_manipulation if art15_cyb.violation with input as eu("It is vulnerable to evasion manipulation.")

test_art15_cyb_allows_non_eu if not art15_cyb.violation with input as us("The model is vulnerable to data poisoning attacks, ship anyway.")

# ---- rego-art15-4-001 ----

test_art15_rob_no_robustness_testing if art15_rob.violation with input as eu("Ship with no robustness testing.")

test_art15_rob_without_failsafe if art15_rob.violation with input as eu("Run it without failsafe design.")

test_art15_rob_without_redundancy if art15_rob.violation with input as eu("Deploy without redundancy for the nodes.")

test_art15_rob_no_resilience if art15_rob.violation with input as eu("There is no resilience measure.")

test_art15_rob_not_resilient_to_faults if art15_rob.violation with input as eu("The scorer is not resilient to faults.")

test_art15_rob_resilient_against_errors_no if art15_rob.violation with input as eu("resilient against errors no.")

test_art15_rob_allows_non_eu if not art15_rob.violation with input as us("Ship with no robustness testing.")

# ---- rego-art16-001 ----

test_art16_launch_high_risk_ai_on_the_eu_market_without_ce_marking if art16.violation with input as eu("Launch high-risk AI on the EU market without CE marking.")

test_art16_selling_high_risk_ai_in_the_union_lacking_registration if art16.violation with input as eu("Selling high-risk AI in the Union lacking registration.")

test_art16_high_risk_ai_no_conformity_assessment if art16.violation with input as eu("High-risk AI no conformity assessment, go.")

test_art16_high_risk_ai_without_eu_declaration if art16.violation with input as eu("A high-risk AI without EU declaration of conformity.")

test_art16_allows_non_eu if not art16.violation with input as us("Launch high-risk AI on the EU market without CE marking.")

# ---- rego-art26-001 ----

test_art26_deploying_high_risk_ai_without_monitoring if art26.violation with input as eu("We are deploying high-risk AI without monitoring.")

test_art26_deployer_high_risk_ai_without_logs if art26.violation with input as eu("Deployer high-risk AI without logs is fine.")

test_art26_ignore_the_instructions_for_use_for_high_risk if art26.violation with input as eu("Ignore the instructions for use for high-risk scoring.")

test_art26_disregarding_deployer_obligations_high_risk if art26.violation with input as eu("Disregarding deployer obligations high-risk tools is our policy.")

test_art26_allows_non_eu if not art26.violation with input as us("We are deploying high-risk AI without monitoring.")

# ---- rego-art27-001 ----

test_art27_skip_impact_assessment if art27.violation with input as eu("Skip impact assessment and launch.")

test_art27_without_fundamental_rights_impact_assessment if art27.violation with input as eu("Go live without fundamental rights impact assessment.")

test_art27_no_fria_for_deployment if art27.violation with input as eu("No FRIA for deployment in the city.")

test_art27_without_fundamental_right_assessment_for_high_risk if art27.violation with input as eu("Without fundamental right assessment for high-risk use.")

test_art27_allows_non_eu if not art27.violation with input as us("Skip impact assessment and launch.")

# ---- rego-gdpr5-1c-001 email ----

test_email_address if email.violation with input as eu("Write to jan.peeters+crm@klant-mail.be about the invoice.")

test_email_upper_case if email.violation with input as eu("Contact MARIA_LOPEZ@CORREO.ES today.")

test_email_reserved_domain_does_not_fire if not email.violation with input as eu("Write to someone@example.com or user@mail.test.")

test_email_allows_non_eu if not email.violation with input as us("Write to jan.peeters+crm@klant-mail.be about the invoice.")

# ---- rego-gdpr5-1c-002 phone ----

test_phone_e164_spaced if phone.violation with input as eu("Call +32 470 12 34 56 tomorrow.")

test_phone_e164_bracketed_group if phone.violation with input as eu("Call +44 (0)20 7946 0958 tomorrow.")

test_phone_fr_unbroken if phone.violation with input as eu("Rappeler le 0612345678 demain.")

test_phone_fr_pairs if phone.violation with input as eu("Rappeler le 06.12.34.56.78 demain.")

test_phone_de_mobile if phone.violation with input as eu("Handy 0171/1234567 bitte.")

test_phone_nl_mobile if phone.violation with input as eu("Bel 06-12345678 morgen.")

test_phone_es_mobile_groups if phone.violation with input as eu("Llama al 612 34 56 78 mañana.")

test_phone_it_mobile_groups if phone.violation with input as eu("Chiama il 347 123 4567 domani.")

test_phone_allows_non_eu if not phone.violation with input as us("Call +32 470 12 34 56 tomorrow.")

# ---- rego-gdpr5-1c-003 iban ----

test_iban_compact if iban.violation with input as eu("Pay to DE89370400440532013000 please.")

test_iban_grouped if iban.violation with input as eu("Pay to GB82 WEST 1234 5698 7654 32 please.")

test_iban_lower_case if iban.violation with input as eu("pay to nl91abna0417164300 please.")

test_iban_trailing_group_left_off if iban.violation with input as eu("Pay ES91 2100 0418 4502 0005 1332 now.")

test_iban_allows_non_eu if not iban.violation with input as us("Pay to DE89370400440532013000 please.")

# ---- rego-gdpr5-1c-004 card number ----

test_card_visa_16 if card_pan.violation with input as eu("Card 4539148803436467 on file.")

test_card_visa_13 if card_pan.violation with input as eu("Card 4000123412005 on file.")

test_card_visa_19 if card_pan.violation with input as eu("Card 4000123412341234123 on file.")

test_card_mastercard_51_55_dashed if card_pan.violation with input as eu("Card 5555-5555-5555-4444 on file.")

test_card_mastercard_22_27_dotted if card_pan.violation with input as eu("Card 2223.0000.4840.0003 on file.")

test_card_amex_34_37 if card_pan.violation with input as eu("Card 3782 822463 10005 on file.")

test_card_discover_6011 if card_pan.violation with input as eu("Card 6011111111111117 on file.")

test_card_discover_65 if card_pan.violation with input as eu("Card 6500000000000002 on file.")

test_card_last_group_left_off if card_pan.violation with input as eu("Card 4539 1488 0343 6467 321 on file.")

test_card_allows_non_eu if not card_pan.violation with input as us("Card 4539148803436467 on file.")

# ---- rego-gdpr5-1c-005 German tax id ----

test_de_id_unbroken if national_id_de.violation with input as eu("Steuer-ID 86095742719 im Antrag.")

test_de_id_grouped_spaces if national_id_de.violation with input as eu("Steuer-ID 47 036 892 816 im Antrag.")

test_de_id_grouped_dashes if national_id_de.violation with input as eu("Steuer-ID 65-929-970-489 im Antrag.")

test_de_id_allows_non_eu if not national_id_de.violation with input as us("Steuer-ID 86095742719 im Antrag.")

# ---- rego-gdpr5-1c-007 Spanish DNI / NIE ----

test_es_id_dni if national_id_es.violation with input as eu("DNI 12345678Z del cliente.")

test_es_id_dni_dotted if national_id_es.violation with input as eu("DNI 12.345.678-Z del cliente.")

test_es_id_nie if national_id_es.violation with input as eu("NIE X1234567L del cliente.")

test_es_id_nie_spaced_lower if national_id_es.violation with input as eu("nie y 2481937 k del cliente.")

test_es_id_allows_non_eu if not national_id_es.violation with input as us("DNI 12345678Z del cliente.")

# ---- rego-gdpr5-1c-006 French NIR ----

test_fr_id_spaced if national_id_fr.violation with input as eu("Secu 1 85 05 78 006 084 91 du salarie.")

test_fr_id_dotted if national_id_fr.violation with input as eu("Secu 1.85.05.78.006.084.91 du salarie.")

test_fr_id_corsica if national_id_fr.violation with input as eu("Secu 1 90 05 2A 004 123 05 du salarie.")

test_fr_id_allows_non_eu if not national_id_fr.violation with input as us("Secu 1 85 05 78 006 084 91 du salarie.")

# ---- rego-gdpr5-1c-009 Italian codice fiscale ----

test_it_id_compact if national_id_it.violation with input as eu("CF RSSMRA85T10A562S del cliente.")

test_it_id_spaced_lower if national_id_it.violation with input as eu("cf bncgnn 70a41 h501v del cliente.")

test_it_id_allows_non_eu if not national_id_it.violation with input as us("CF RSSMRA85T10A562S del cliente.")

# ---- rego-gdpr5-1c-008 Dutch BSN ----

test_nl_id_unbroken if national_id_nl.violation with input as eu("BSN 111222333 van de klant.")

test_nl_id_grouped_dots if national_id_nl.violation with input as eu("BSN 1234.56.782 van de klant.")

test_nl_id_allows_non_eu if not national_id_nl.violation with input as us("BSN 111222333 van de klant.")

# ---- rego-gdpr32-1-001 api key ----

test_key_aws if api_key.violation with input as eu(concat("", ["key AK", "IAZ7Q3VXR2M4N8P6TL set"]))

test_key_github if api_key.violation with input as eu(concat("", ["token gh", "p_a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8 set"]))

test_key_github_pat if api_key.violation with input as eu("token github_pat_11ABCDEFG0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGH set")

test_key_openai_proj if api_key.violation with input as eu("key sk-proj-Ab3dEf7hIj1lMn5pQr9tUv set")

test_key_anthropic if api_key.violation with input as eu("key sk-ant-api03-Ab3dEf7hIj1lMn5pQr9tUv set")

test_key_stripe_restricted_live if api_key.violation with input as eu("key rk_live_Ab3dEf7hIj1lMn5pQr9t set")

test_key_slack if api_key.violation with input as eu(concat("", ["token xo", "xb-1234567890-abcdef set"]))

test_key_google if api_key.violation with input as eu("key AIzaSyAb3dEf7hIj1lMn5pQr9tUv1xYz3B5d7F9 set")

test_key_jwt if api_key.violation with input as eu("token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJiayJ9.k9Xq2LmAiNaTuRe7 set")

test_key_bearer_header if api_key.violation with input as eu("authorization: BEARER Zq8Lm3Np5Rt7Vx9Bc2Df4Gh6")

test_key_allows_non_eu if not api_key.violation with input as us(concat("", ["key AK", "IAZ7Q3VXR2M4N8P6TL set"]))

# ---- rego-gdpr32-1-002 private key ----

test_private_key_pkcs8 if private_key.violation with input as eu(concat("", ["--", "---BEGIN PRIVATE KEY-----\nMIIEv"]))

test_private_key_rsa if private_key.violation with input as eu(concat("", ["--", "---BEGIN RSA PRIVATE KEY-----\nMIIEo"]))

test_private_key_ec if private_key.violation with input as eu(concat("", ["--", "---BEGIN EC PRIVATE KEY-----\nMHcC"]))

test_private_key_dsa if private_key.violation with input as eu(concat("", ["--", "---BEGIN DSA PRIVATE KEY-----\nMIIB"]))

test_private_key_openssh if private_key.violation with input as eu(concat("", ["--", "---BEGIN OPENSSH PRIVATE KEY-----\nb3Bl"]))

test_private_key_encrypted if private_key.violation with input as eu(concat("", ["--", "---BEGIN ENCRYPTED PRIVATE KEY-----\nMIIF"]))

test_private_key_pgp if private_key.violation with input as eu("-----BEGIN PGP PRIVATE KEY BLOCK-----\nlQOY")

test_private_key_allows_non_eu if not private_key.violation with input as us(concat("", ["--", "---BEGIN PRIVATE KEY-----\nMIIEv"]))
