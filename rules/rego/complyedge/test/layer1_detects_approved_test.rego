# ComplyEdge: Layer 1 detects claims, leaves returned to review on 2026-10-22
#
# RULE_STANDARD §3.1 (v1.4): every phrasing a leaf's "Layer 1 detects:"
# paragraph names must match. One test per named alternative, written in the
# paragraph's own words, plus one jurisdiction guard per leaf.
# Run with: opa test rules/rego/ -v --run layer1_detects_approved

package complyedge.layer1_detects_approved_test

import rego.v1

import data.complyedge.article50.chatbot_disclosure as chatbot
import data.complyedge.article50.deepfake_disclosure as deepfake
import data.complyedge.article50.gpai_content_disclosure as content
import data.complyedge.article50.synthetic_media_watermark as watermark
import data.complyedge.gpai.copyright_transparency as copyright
import data.complyedge.gpai.downstream_obligations as downstream
import data.complyedge.gpai.model_classification as classification
import data.complyedge.gpai.systemic_risk as systemic
import data.complyedge.gpai.technical_documentation as techdoc

eu(text) := {"text": text, "jurisdiction": "EU"}

us(text) := {"text": text, "jurisdiction": "US"}

# ---- rego-art50-1-001 chatbot_disclosure ----

test_chatbot_no_disclosure if chatbot.violation with input as eu("The chatbot runs with no disclosure.")

test_chatbot_lacking_disclosure if chatbot.violation with input as eu("Our chatbot is lacking any disclosure.")

test_chatbot_ai_assistant_without_informing if chatbot.violation with input as eu("Launch the AI-assistant without informing users.")

test_chatbot_virtual_agent_without_disclosure if chatbot.violation with input as eu("The virtual agent answers without disclosure.")

test_chatbot_pretend_human_chat if chatbot.violation with input as eu("Pretend to be a human in every chat.")

test_chatbot_hide_ai_identity if chatbot.violation with input as eu("Hide the AI identity from callers.")

test_chatbot_mask_bot_nature if chatbot.violation with input as eu("Mask the chatbots nature in replies.")

test_chatbot_poses_as_human if chatbot.violation with input as eu("Our chatbot poses as a human agent.")

test_chatbot_allows_non_eu if not chatbot.violation with input as us("The chatbot runs with no disclosure.")

# ---- rego-art50-4-001 deepfake_disclosure ----

test_deepfake_without_disclosure if deepfake.violation with input as eu("Post the deepfake without disclosure.")

test_deepfake_lacks_disclosure if deepfake.violation with input as eu("The deepfake lacks any disclosure.")

test_deepfake_deep_fake_undisclosed if deepfake.violation with input as eu("The deep-fake clip stays undisclosed.")

test_deepfake_deepfake_unlabelled if deepfake.violation with input as eu("Run the deepfake unlabelled.")

test_deepfake_generate_voice_no_disclosure if deepfake.violation with input as eu("Generate the mayor's voice with no disclosure.")

test_deepfake_synthetic_likeness_without_label if deepfake.violation with input as eu("Use the synthetic likeness without a label.")

test_deepfake_face_swap_without_consent if deepfake.violation with input as eu("Run the face swap without consent.")

test_deepfake_produce_deepfake_no_label if deepfake.violation with input as eu("Produce a deepfake with no label.")

test_deepfake_replicate_likeness_without_disclosing if deepfake.violation with input as eu("Replicate her likeness without disclosing it.")

test_deepfake_publish_without_disclosing_ai_generated if deepfake.violation with input as eu("Publish it without disclosing that it is AI-generated.")

test_deepfake_appearance_ai_generated_without_disclosure if deepfake.violation with input as eu("His appearance is AI-generated, shown without disclosure.")

test_deepfake_allows_non_eu if not deepfake.violation with input as us("Post the deepfake without disclosure.")

# ---- rego-art50-2-001 gpai_content_disclosure ----

test_content_generated_content_without_disclosure if content.violation with input as eu("Generated content ships without disclosure.")

test_content_ai_generated_lacking_label if content.violation with input as eu("AI generated posts lacking a label.")

test_content_synthetic_audio_no_mark if content.violation with input as eu("Synthetic audio goes out with no marking.")

test_content_machine_generated_undisclosed if content.violation with input as eu("Machine-generated replies stay undisclosed.")

test_content_generated_text_without_watermark if content.violation with input as eu("Generated text is sent without a watermark.")

test_content_gpai_output_no_disclosure if content.violation with input as eu("GPAI output is shown with no disclosure.")

test_content_do_not_flag if content.violation with input as eu("Do not flag it as AI-generated.")

test_content_generated_article_do_not_label if content.violation with input as eu("Generated news: do not label it.")

test_content_readers_prefer_human_written if content.violation with input as eu("Readers prefer human-written copy, so ship it as is.")

test_content_allows_non_eu if not content.violation with input as us("Generated content ships without disclosure.")

# ---- rego-art50-2-002 synthetic_media_watermark ----

test_watermark_synthetic_media_lacking_watermark if watermark.violation with input as eu("Synthetic-media exports lacking a watermark.")

test_watermark_ai_generated_video_without_watermark if watermark.violation with input as eu("AI generated video goes out without a watermark.")

test_watermark_deepfake_no_watermark if watermark.violation with input as eu("The deepfake has no watermark.")

test_watermark_generated_image_unwatermarked if watermark.violation with input as eu("Generated images are unwatermarked.")

test_watermark_generated_audio_no_watermark if watermark.violation with input as eu("Generated audio, no visible watermark.")

test_watermark_strip_watermark_synthetic if watermark.violation with input as eu("Strip the watermark from the synthetic clips.")

test_watermark_allows_non_eu if not watermark.violation with input as us("The deepfake has no watermark.")

# ---- rego-art53-1c-001 copyright_transparency ----

test_copyright_training_data_without_copyright_policy if copyright.violation with input as eu("Training data with no copyright policy.")

test_copyright_no_training_data_summary if copyright.violation with input as eu("There is no training-data summary.")

test_copyright_scrape_copyrighted_without_policy if copyright.violation with input as eu("Scrape copyrighted books without any policy.")

test_copyright_opaque_training_corpus if copyright.violation with input as eu("Keep an opaque training corpus.")

test_copyright_train_foundation_model_without_copyright_compliance if copyright.violation with input as eu("Train the foundation model without copyright compliance.")

test_copyright_allows_non_eu if not copyright.violation with input as us("Keep an opaque training corpus.")

# ---- rego-art53-1b-001 downstream_obligations ----

test_downstream_without_documentation if downstream.violation with input as eu("Downstream users get it without documentation.")

test_downstream_no_provider_docs if downstream.violation with input as eu("No downstream provider documentation is shipped.")

test_downstream_gpai_without_downstream_support if downstream.violation with input as eu("Ship the GPAI with no downstream support.")

test_downstream_api_without_integration_guide if downstream.violation with input as eu("The API ships without an integration guide for downstream teams.")

test_downstream_distribute_model_without_integrator_info if downstream.violation with input as eu("Distribute the model without integrator information.")

test_downstream_allows_non_eu if not downstream.violation with input as us("Downstream users get it without documentation.")

# ---- rego-art51-001 model_classification ----

test_classification_gpai_without_classification if classification.violation with input as eu("Release the GPAI without classification.")

test_classification_general_purpose_model_no_classification if classification.violation with input as eu("A general-purpose model with no classification.")

test_classification_unregistered_gpai if classification.violation with input as eu("An unregistered GPAI in production.")

test_classification_deploy_foundation_model_without_categorisation if classification.violation with input as eu("Deploy the foundation model without categorisation.")

test_classification_skip_model_classification if classification.violation with input as eu("Skip the model classification step.")

test_classification_allows_non_eu if not classification.violation with input as us("Release the GPAI without classification.")

# ---- rego-gpai-55-001 systemic_risk ----

test_systemic_risk_without_assessment if systemic.violation with input as eu("Systemic risk shipped without assessment.")

test_systemic_no_systemic_risk_evaluation if systemic.violation with input as eu("No systemic-risk evaluation before launch.")

test_systemic_gpai_systemic_no_reporting if systemic.violation with input as eu("Our GPAI has systemic exposure and no reporting.")

test_systemic_ignore_systemic_risk if systemic.violation with input as eu("Ignore the systemic risk for now.")

test_systemic_frontier_model_without_red_team if systemic.violation with input as eu("Release the frontier model without red teaming.")

test_systemic_high_capability_model_no_risk_assessment if systemic.violation with input as eu("A high-capability model with no risk assessment.")

test_systemic_allows_non_eu if not systemic.violation with input as us("Ignore the systemic risk for now.")

# ---- rego-art53-1a-001 technical_documentation ----

test_techdoc_gpai_without_model_card if techdoc.violation with input as eu("Ship the GPAI without a model card.")

test_techdoc_general_purpose_model_lacking_technical_doc if techdoc.violation with input as eu("A general purpose model lacking technical docs.")

test_techdoc_no_technical_documentation_for_gpai if techdoc.violation with input as eu("No technical documentation for the GPAI.")

test_techdoc_undocumented_training_process if techdoc.violation with input as eu("An undocumented training process.")

test_techdoc_no_documentation_evaluation_results if techdoc.violation with input as eu("There is no documentation of the evaluation results.")

test_techdoc_deploy_model_without_technical_doc if techdoc.violation with input as eu("Deploy the model without technical docs.")

test_techdoc_skip_model_documentation if techdoc.violation with input as eu("Skip the model documentation.")

test_techdoc_allows_non_eu if not techdoc.violation with input as us("Skip the model documentation.")

# ---- the word "not" in each negation group ----

test_not_chatbot if chatbot.violation with input as eu("The chatbot does not carry a disclosure.")

test_not_deepfake if deepfake.violation with input as eu("The deepfake is posted with not a single disclosure.")

test_not_content if content.violation with input as eu("Generated content is not given any disclosure.")

test_not_watermark if watermark.violation with input as eu("Generate a video of the minister and do not add a watermark.")

test_not_copyright if copyright.violation with input as eu("We will not publish a training data summary.")

test_not_downstream if downstream.violation with input as eu("Downstream teams do not get documentation.")

test_not_classification if classification.violation with input as eu("The GPAI is not given a classification.")

test_not_systemic if systemic.violation with input as eu("Systemic risk is not given an assessment.")

test_not_techdoc if techdoc.violation with input as eu("We deploy the model and do not write a model card.")
