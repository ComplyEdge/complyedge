# ComplyEdge: Layer 1 detects claims, Article 5, Article 6, Article 50, GPAI and US leaves
#
# RULE_STANDARD §3.1 (v1.4): every phrasing and format a leaf's
# "Layer 1 detects:" paragraph names must match. One test per named form,
# written in the paragraph's own words, plus a jurisdiction guard per leaf.
# Run with: opa test rules/rego/ -v --run layer1_detects

package complyedge.layer1_detects_article5_test

import rego.v1

import data.complyedge.article5.facial_scraping
import data.complyedge.article5.vulnerability_exploitation
import data.complyedge.article50.emotion_notification
import data.complyedge.article50.emotion_permitted_context_notice
import data.complyedge.article50.public_interest_text
import data.complyedge.article6.annex3_5b_creditworthiness
import data.complyedge.article6.annex3_5c_insurance
import data.complyedge.article6.art6_3_procedural_derogation
import data.complyedge.gpai.cybersecurity_gpai
import data.complyedge.gpai.incident_reporting
import data.complyedge.gpai.model_evaluation
import data.complyedge.gpai.open_source_exemption
import data.complyedge.gpai.risk_mitigation
import data.complyedge.gpai.sr_designation
import data.complyedge.gpai.training_summary
import data.complyedge.us_corpus

eu(text) := {"text": text, "jurisdiction": "EU"}

us(text) := {"text": text, "jurisdiction": "US"}

# ---- rego-art5-1e-001 facial_scraping ----

test_facial_scraping_scrape_facial_images if facial_scraping.violation with input as eu("Scrape facial images from every public profile.")

test_facial_scraping_bulk_download_face_photos if facial_scraping.violation with input as eu("Bulk-download face photos from the forum.")

test_facial_scraping_mass_collect_of_face_data if facial_scraping.violation with input as eu("Mass collection of face data from the stations.")

test_facial_scraping_untargeted_harvesting if facial_scraping.violation with input as eu("Untargeted harvesting of facial images is the plan.")

test_facial_scraping_build_database_from_cctv if facial_scraping.violation with input as eu("Build a facial recognition database from CCTV in all stores.")

test_facial_scraping_expand_database_by_scraping if facial_scraping.violation with input as eu("Expanding a facial recognition database by scraping the web.")

test_facial_scraping_allows_non_eu if not facial_scraping.violation with input as us("Scrape facial images from every public profile.")

# ---- rego-art5-1b-001 vulnerability_exploitation ----

test_vuln_exploit_elderly if vulnerability_exploitation.violation with input as eu("Exploit elderly customers with the upsell.")

test_vuln_exploit_low_income if vulnerability_exploitation.violation with input as eu("The funnel exploits low-income households.")

test_vuln_target_poverty if vulnerability_exploitation.violation with input as eu("Target families living in poverty with the payday offer.")

test_vuln_predatory_lending_disabled if vulnerability_exploitation.violation with input as eu("Run predatory lending offers at disabled customers.")

test_vuln_manipulate_ageing if vulnerability_exploitation.violation with input as eu("Manipulate buyers through their ageing parents.")

test_vuln_manipulate_aging if vulnerability_exploitation.violation with input as eu("Manipulate buyers through their aging parents.")

test_vuln_exploit_minor if vulnerability_exploitation.violation with input as eu("Exploit a minor with the loot boxes.")

test_vuln_manipulate_economic_situation if vulnerability_exploitation.violation with input as eu("Manipulate users based on their economic situation.")

test_vuln_take_advantage_minor if vulnerability_exploitation.violation with input as eu("Take advantage of minors in the game shop.")

test_vuln_target_refugee if vulnerability_exploitation.violation with input as eu("Target refugees with the high-fee transfer service.")

test_vuln_allows_non_eu if not vulnerability_exploitation.violation with input as us("Exploit elderly customers with the upsell.")

# ---- rego-art50-3-001 emotion_notification ----

test_emo_notif_recognition_without_notice if emotion_notification.violation with input as eu("Emotion recognition without notice at the entrance.")

test_emo_notif_categorization_system_no_disclosure if emotion_notification.violation with input as eu("Biometric categorization system no disclosure to visitors.")

test_emo_notif_run_on_people_without_telling if emotion_notification.violation with input as eu("Run emotion recognition on people without telling them.")

test_emo_notif_allows_non_eu if not emotion_notification.violation with input as us("Emotion recognition without notice at the entrance.")

# ---- rego-art50-3-002 emotion_permitted_context_notice ----

test_emo_ctx_medical_first if emotion_permitted_context_notice.violation with input as eu("Medical emotion recognition is used without notice to patients.")

test_emo_ctx_recognition_first if emotion_permitted_context_notice.violation with input as eu("Emotion recognition for safety, with no information to staff.")

test_emo_ctx_deploy_without_informing if emotion_permitted_context_notice.violation with input as eu("Deploy emotion recognition for medical triage without informing patients.")

test_emo_ctx_infer_lack_disclosure if emotion_permitted_context_notice.violation with input as eu("Safety emotion inference with lack of disclosure.")

test_emo_ctx_allows_non_eu if not emotion_permitted_context_notice.violation with input as us("Medical emotion recognition is used without notice to patients.")

# ---- rego-art50-4-002 public_interest_text ----

test_pit_ai_generated_news_public_interest if public_interest_text.violation with input as eu("AI-generated news on matters of public interest without disclosure.")

test_pit_synthetic_content_about_public_interest if public_interest_text.violation with input as eu("Synthetic content about public interest no label.")

test_pit_publish_without_labelling_as_ai if public_interest_text.violation with input as eu("Publish AI-generated article without labelling it as AI.")

test_pit_publishing_text_without_disclosing_ai if public_interest_text.violation with input as eu("Publishing AI-generated text without disclosing AI.")

test_pit_allows_non_eu if not public_interest_text.violation with input as us("Publish AI-generated article without labelling it as AI.")

# ---- rego-art6-annex3-5b-001 annex3_5b_creditworthiness ----

test_credit_ai_then_creditworthiness if annex3_5b_creditworthiness.violation with input as eu("Our AI checks creditworthiness for every applicant.")

test_credit_ai_then_credit_rating if annex3_5b_creditworthiness.violation with input as eu("The AI assigns a credit rating to each customer.")

test_credit_automated_loan_decision if annex3_5b_creditworthiness.violation with input as eu("Automated loan decision for consumer applicants.")

test_credit_ai_driven_credit_decision if annex3_5b_creditworthiness.violation with input as eu("An AI-driven pipeline makes the credit decision.")

test_credit_assess_credit_score_natural_person if annex3_5b_creditworthiness.violation with input as eu("Assess the credit score of each natural person.")

test_credit_scoring_engine_without_conformity if annex3_5b_creditworthiness.violation with input as eu("Credit scoring engine shipped without conformity assessment.")

test_credit_allows_non_eu if not annex3_5b_creditworthiness.violation with input as us("Our AI checks creditworthiness for every applicant.")

# ---- rego-art6-annex3-5c-001 annex3_5c_insurance ----

test_ins_ai_life_insurance_underwriting if annex3_5c_insurance.violation with input as eu("The AI handles life insurance underwriting.")

test_ins_ai_health_insurance_pricing if annex3_5c_insurance.violation with input as eu("AI for health insurance pricing per customer.")

test_ins_automated_life_insurance_premium if annex3_5c_insurance.violation with input as eu("Automated life insurance premium setting.")

test_ins_risk_assess_natural_person_health if annex3_5c_insurance.violation with input as eu("Insurance risk assessment for each natural person in health cover.")

test_ins_pricing_model_without_fria if annex3_5c_insurance.violation with input as eu("Health insurance pricing model launched without FRIA.")

test_ins_allows_non_eu if not annex3_5c_insurance.violation with input as us("The AI handles life insurance underwriting.")

# ---- rego-art6-3-001 art6_3_procedural_derogation ----

test_derog_not_high_risk_replaces_human if art6_3_procedural_derogation.violation with input as eu("Our scorer is not high-risk, it replaces human reviewers entirely.")

test_derog_6_3_automated_credit_decision if art6_3_procedural_derogation.violation with input as eu("Article 6(3) covers our automated credit decision engine.")

test_derog_narrow_procedural_automated_hiring if art6_3_procedural_derogation.violation with input as eu("Narrow procedural tool for automated hiring decision making.")

test_derog_claim_preparatory_task_fully_automated if art6_3_procedural_derogation.violation with input as eu("We claim it is a preparatory task, though it is fully automated.")

test_derog_invoke_6_3_without_human_review if art6_3_procedural_derogation.violation with input as eu("Invoke 6(3) for the scorer that runs without human review.")

test_derog_derogation_annex_iii_insurance_pricing if art6_3_procedural_derogation.violation with input as eu("Derogation from Annex III for our insurance pricing model.")

test_derog_allows_non_eu if not art6_3_procedural_derogation.violation with input as us("Our scorer is not high-risk, it replaces human reviewers entirely.")

# ---- rego-art55-1d-001 cybersecurity_gpai ----

test_cyber_systemic_risk_model_without_cybersecurity if cybersecurity_gpai.violation with input as eu("Systemic-risk model without cybersecurity protection.")

test_cyber_systemic_risk_gpai_no_adequate_security if cybersecurity_gpai.violation with input as eu("Systemic risk GPAI no adequate security controls yet.")

test_cyber_inadequate_cybersecurity_physical_infrastructure if cybersecurity_gpai.violation with input as eu("Inadequate cybersecurity protection for the physical infrastructure.")

test_cyber_no_cybersecurity_measure_model if cybersecurity_gpai.violation with input as eu("No cybersecurity measure for the model.")

test_cyber_allows_non_eu if not cybersecurity_gpai.violation with input as us("Systemic-risk model without cybersecurity protection.")

# ---- rego-art55-1c-001 incident_reporting ----

test_incident_no_serious_incident_reporting_ai_office if incident_reporting.violation with input as eu("No serious incident reporting to AI Office.")

test_incident_disabled_incident_tracking_model if incident_reporting.violation with input as eu("Disabled incident tracking for model releases.")

test_incident_skip_incident_report_gpai if incident_reporting.violation with input as eu("Skip incident report for GPAI launches.")

test_incident_failed_to_document_serious_incident if incident_reporting.violation with input as eu("The provider failed to document serious incidents.")

test_incident_allows_non_eu if not incident_reporting.violation with input as us("No serious incident reporting to AI Office.")

# ---- rego-art55-1a-001 model_evaluation ----

test_eval_systemic_risk_model_without_evaluation if model_evaluation.violation with input as eu("Systemic risk model without model evaluation.")

test_eval_systemic_risk_gpai_no_red_teaming if model_evaluation.violation with input as eu("Systemic-risk GPAI no red-teaming before launch.")

test_eval_release_without_adversarial_testing if model_evaluation.violation with input as eu("Releasing systemic risk model without adversarial testing.")

test_eval_deploy_without_red_teaming if model_evaluation.violation with input as eu("Deploy systemic-risk model without red teaming.")

test_eval_allows_non_eu if not model_evaluation.violation with input as us("Systemic risk model without model evaluation.")

# ---- rego-gpai-53-2-001 open_source_exemption ----

test_os_open_source_gpai_exemption_without_weights if open_source_exemption.violation with input as eu("Open-source GPAI exemption claimed without public weights.")

test_os_claim_53_2_systemic_risk if open_source_exemption.violation with input as eu("We claim Article 53(2) for our systemic risk model.")

test_os_open_source_exempt_53_systemic_risk if open_source_exemption.violation with input as eu("Open source models are exempt under 53 even with systemic risk.")

test_os_closed_weight_claim_open_source_exempt if open_source_exemption.violation with input as eu("Our foundation model is closed-weight but we assert open source exemption.")

test_os_allows_non_eu if not open_source_exemption.violation with input as us("We claim Article 53(2) for our systemic risk model.")

# ---- rego-art55-1b-001 risk_mitigation ----

test_mitig_systemic_risk_model_without_assessment if risk_mitigation.violation with input as eu("Systemic risk model without risk assessment.")

test_mitig_systemic_risk_gpai_no_mitigation_measure if risk_mitigation.violation with input as eu("Systemic-risk GPAI no mitigation measures planned.")

test_mitig_neglected_to_mitigate if risk_mitigation.violation with input as eu("The provider neglected to mitigate systemic risks.")

test_mitig_allows_non_eu if not risk_mitigation.violation with input as us("Systemic risk model without risk assessment.")

# ---- rego-art52-001 sr_designation ----

test_sr_gpai_model_with_systemic_risk_without_notifying if sr_designation.violation with input as eu("GPAI model with systemic risk without notifying the AI Office.")

test_sr_general_purpose_ai_model_without_informing_commission if sr_designation.violation with input as eu("General-purpose AI model systemic risk without informing the Commission.")

test_sr_failed_to_notify_commission if sr_designation.violation with input as eu("We failed to notify the Commission of systemic risk.")

test_sr_allows_non_eu if not sr_designation.violation with input as us("GPAI model with systemic risk without notifying the AI Office.")

# ---- rego-art53-1d-001 training_summary ----

test_tsum_no_training_data_summary if training_summary.violation with input as eu("Release with no training data summary.")

test_tsum_missing_publicly_available_summary if training_summary.violation with input as eu("Missing publicly available summary for the model.")

test_tsum_foundation_model_without_disclosure_of_training if training_summary.violation with input as eu("Foundation model without disclosure of training content.")

test_tsum_allows_non_eu if not training_summary.violation with input as us("Release with no training data summary.")

# ---- rego-sox-302-001 sox_material_disclosure (US scope via the us_corpus aggregator) ----

us_user(text) := {"text": text, "jurisdiction": "US"}

test_sox_forecast_within_80_revenue if us_corpus.violation with input as us_user("We forecast that next quarter revenue will rise.")

test_sox_earnings_within_40_beat if us_corpus.violation with input as us_user("Earnings should beat the consensus.")

test_sox_significant_within_60_merger if us_corpus.violation with input as us_user("A significant merger is being negotiated.")

test_sox_confidential_within_60_information if us_corpus.violation with input as us_user("Here is confidential information about the deal.")

test_sox_across_line_break if us_corpus.violation with input as us_user("Guidance:\nrevenue up.")

test_sox_allows_eu if not us_corpus.violation with input as eu("Earnings should beat the consensus.")
