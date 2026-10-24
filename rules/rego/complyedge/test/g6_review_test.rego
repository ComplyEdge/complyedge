# ComplyEdge: word-boundary review tests for the leaves approved before 2026-10-22
#
# Same defect as g5_review_test.rego: the negation alternatives ("no",
# "without", "lack") matched inside longer words ("nonprofit", "nothing",
# "announce", "notes", "know", "knowledge"), so a text with no negation in it
# was blocked. A word boundary now sits on each side. Each test below fires on
# the file as it was approved and is silent now; the per-phrase tests in
# layer1_detects_approved_test.rego prove the negation itself still fires.
# Run with: opa test rules/rego/ -v --run g6_review

package complyedge.g6_review_test

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

test_chatbot_nonprofit_is_not_no if not chatbot.violation with input as eu("Our chatbot is a nonprofit tool; see the disclosure page.")

test_deepfake_nothing_is_not_no if not deepfake.violation with input as eu("The deepfake detector found nothing; see the disclosure log.")

test_content_announced_is_not_no if not content.violation with input as eu("Generated content is announced in the disclosure section.")

test_watermark_juno_is_not_no if not watermark.violation with input as eu("Synthetic media from the Juno studio carries a watermark.")

test_copyright_notes_is_not_no if not copyright.violation with input as eu("Training data notes include the copyright policy.")

test_downstream_knowledge_is_not_no if not downstream.violation with input as eu("Downstream partners receive the knowledge base and documentation.")

test_classification_announce_is_not_no if not classification.violation with input as eu("GPAI vendors announce the classification on Tuesday.")

test_systemic_notes_is_not_no if not systemic.violation with input as eu("Systemic risk notes guide how we assess the model.")

test_techdoc_know_is_not_no if not techdoc.violation with input as eu("GPAI providers know the technical documentation duty.")
