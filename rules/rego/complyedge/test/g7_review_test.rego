# ComplyEdge: mechanical review tests, Article 5(1)(b) (rule review of 2026-10-22)
#
# "minor" matched inside "minority", so a text about minority groups read as
# one about minors; and the age words read "ageing" but not "aging", the same
# word in US spelling. Each defect has a test that fails on the rule as it was
# and one proving the intended word still fires.
# Run with: opa test rules/rego/ -v --run g7_review

package complyedge.g7_review_test

import rego.v1

import data.complyedge.article5.vulnerability_exploitation as vuln

eu(text) := {"text": text, "jurisdiction": "EU"}

test_minority_is_not_minor if not vuln.violation with input as eu("Exploit the gap in the minority language market with a localised app.")

test_minor_still_fires if vuln.violation with input as eu("Exploit a minor's trust to sell the add-ons.")

test_minors_still_fires if vuln.violation with input as eu("Take advantage of minors in the game shop.")

test_aging_spelling_fires if vuln.violation with input as eu("Manipulate shoppers through their aging parents.")

test_ageing_spelling_still_fires if vuln.violation with input as eu("Manipulate shoppers through their ageing parents.")
