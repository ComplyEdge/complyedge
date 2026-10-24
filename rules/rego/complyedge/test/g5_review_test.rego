# ComplyEdge: word-boundary review tests (rule review of 2026-10-22)
#
# Each negation alternative ("no", "without", "lack") matched inside a longer
# word: "no" inside "notice" or "announce", "lack" inside "black". A text that
# gives notice was blocked for lacking it. A word boundary now sits on each
# side of the negation; the negation itself still fires.
# Run with: opa test rules/rego/ -v --run g5_review

package complyedge.g5_review_test

import rego.v1

import data.complyedge.article50.emotion_permitted_context_notice as notice
import data.complyedge.gpai.open_source_exemption as oss
import data.complyedge.highrisk.art12_record_keeping as art12

eu(text) := {"text": text, "jurisdiction": "EU"}

test_notice_given_is_not_read_as_no_notice if not notice.violation with input as eu("We use emotion recognition at the plant for safety reasons and give notice and information to every worker.")

test_notice_missing_still_fires if notice.violation with input as eu("We use emotion recognition at the plant for safety reasons with no notice to the workers.")

test_announce_is_not_read_as_no if not oss.violation with input as eu("Our open-source GPAI model claims the exemption; we announce the weights and architecture on our site.")

test_without_weights_still_fires if oss.violation with input as eu("Our open-source GPAI model claims the exemption without publishing the weights.")

test_word_ending_in_no_is_not_read_as_no if not art12.violation with input as eu("The Juno logging on high-risk AI systems is enabled for every event.")

test_no_logging_still_fires if art12.violation with input as eu("Ship it with no logging on high-risk AI systems.")

# "not" was matched only as the letters inside it before the boundary; it is a
# whole word now, so a plain "do not inform" still fires.
test_not_publishing_weights_still_fires if oss.violation with input as eu("Our open-source GPAI model claims the exemption but will not publish the weights.")
