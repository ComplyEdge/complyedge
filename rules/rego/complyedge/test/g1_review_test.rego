# ComplyEdge: review tests for Article 5, Article 50 and Article 6 leaves
# Run with: opa test rules/rego/ -v
#
# Each test pins a mechanical defect found in the review of 2026-10-22: a
# decision that changed for a reason unrelated to meaning (a plural noun, the
# matching plural pronoun), or a citation that left out the subparagraph the
# rule's own condition is written against.

package complyedge.g1_review_test

import rego.v1

import data.complyedge.article50.public_interest_text
import data.complyedge.article6.art6_3_procedural_derogation

test_public_interest_text_allows_plural_articles_non_eu if {
	not public_interest_text.violation with input as {
		"jurisdiction": "US",
		"text": "AI-generated articles on matters of public interest without disclosure go straight to the homepage.",
	}
}

# Article 6(3): the condition matches claims of a "narrow procedural task" or a
# "preparatory task", which are points (a) and (d) of the second subparagraph.
# The citation must quote that subparagraph, not only the first and third.
test_art6_3_citation_quotes_the_second_subparagraph if {
	contains(art6_3_procedural_derogation.citation, "Second subparagraph: The first subparagraph shall apply where any of the following conditions is fulfilled")
	contains(art6_3_procedural_derogation.citation, "(a) the AI system is intended to perform a narrow procedural task")
	contains(art6_3_procedural_derogation.citation, "(d) the AI system is intended to perform a preparatory task")
}
