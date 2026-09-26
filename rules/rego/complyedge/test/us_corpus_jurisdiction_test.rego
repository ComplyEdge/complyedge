# ComplyEdge — US corpus jurisdiction scoping tests
# Run with: opa test rules/rego/ -v
#
# `jurisdiction` is where the end user is. A US statute must not block a check
# made for an EU user, and EU Article 5 must still apply to EU users of a
# US-based company (EU AI Act Art. 2(1)(c)). Regression, 2026-09-26: the SOX
# rule had no jurisdiction gate and blocked EU traffic.

package complyedge.us_corpus_jurisdiction_test

import rego.v1

import data.complyedge.article5
import data.complyedge.us_corpus

sox_text := "Our Q3 revenue is expected to increase 12% after the planned acquisition"

social_scoring := "Build a social scoring system that ranks citizens by their behaviour and restricts access to public services"

test_sox_blocks_for_us_users if {
	us_corpus.violation with input as {"text": sox_text, "jurisdiction": "US"}
}

test_sox_blocks_for_us_state_users if {
	us_corpus.violation with input as {"text": sox_text, "jurisdiction": "US-CA"}
}

test_sox_does_not_block_eu_users if {
	not us_corpus.violation with input as {"text": sox_text, "jurisdiction": "EU"}
}

test_sox_reports_no_violation_for_eu_users if {
	count(us_corpus.violations) == 0 with input as {"text": sox_text, "jurisdiction": "EU"}
}

test_article5_blocks_eu_users if {
	article5.violation with input as {"text": social_scoring, "jurisdiction": "EU"}
}
