# ComplyEdge - GDPR Article 5(1)(c): phone number in AI text
#
# The text carries a phone number: an international number in E.164 form
# (+ country code, 8 to 15 digits, spaces, dots or dashes allowed between
# groups, and a bracketed group such as the (0) trunk prefix or an area code),
# or a national number in a format that is unambiguous on its own:
# French 0X XX XX XX XX (pairs, or ten digits unbroken), German mobile 015x/016x/017x, Dutch mobile 06,
# Spanish mobile 6/7 written in groups, Italian mobile 3XX written in groups.
# A phone number identifies a person. Bare digit runs with no phone shape
# (order numbers, amounts, dates) do not fire.
#
# Layer 1 detects: a + (not after a letter, digit, + or %) then a digit 1 to 9
# and more digits, with one space, dot or dash, or one bracketed group of 1 to
# 4 digits such as (0), allowed between digits; French 0[1-9] numbers as ten
# digits unbroken or as 0X then four pairs separated by space, dot or dash;
# German mobiles 015x, 016x or 017x then 7 or 8 digits, with an optional
# space, slash or dash after the prefix; Dutch mobiles 06 then 8 digits, with
# an optional space or dash; Spanish mobiles 6 or 7 written as three groups or
# more separated by space or dot; and Italian mobiles 3XX written as three
# groups separated by space or dot. Every match has 9 to 15 digits and no
# letter or digit directly before or after it. It matches formats, not
# purpose: it fires on every such value whatever the task, and it does not
# judge whether sending the value is necessary for the task (the Article
# 5(1)(c) test, which this rule does not apply). No model reviews a hit: a
# match keeps the block in Layer 2 as well.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 5(1)(c)
# Recital: 39 - personal data should be adequate, relevant and limited to what is necessary
# Effective: 2018-05-25
# Penalty: GDPR Article 83(5)(a): up to EUR 20,000,000 or 4% of worldwide annual turnover
# Condition type: deterministic (format match only, no checksum exists for this value; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# ELI: http://data.europa.eu/eli/reg/2016/679/art_5/par_1/pnt_c/oj
# Provision: Regulation (EU) 2016/679, Article 5(1)(c)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.data_protection.phone

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_patterns := [
	`(?:^|[^0-9A-Za-z+%])(\+[1-9](?:(?:[ .-]|[ ]?\([0-9]{1,4}\)[ ]?)?[0-9]){7,14})(?:$|[^0-9A-Za-z])`,
	`(?:^|[^0-9A-Za-z+%])(0[1-9](?:[0-9]{8}|(?:[ .-][0-9]{2}){4}))(?:$|[^0-9A-Za-z])`,
	`(?:^|[^0-9A-Za-z+%])(01[5-7][0-9][ /-]?[0-9]{7,8})(?:$|[^0-9A-Za-z])`,
	`(?:^|[^0-9A-Za-z+%])(06[ -]?[0-9]{8})(?:$|[^0-9A-Za-z])`,
	`(?:^|[^0-9A-Za-z+%])([67][0-9]{2}[ .][0-9]{2,3}[ .][0-9]{2,3}(?:[ .][0-9]{2})?)(?:$|[^0-9A-Za-z])`,
	`(?:^|[^0-9A-Za-z+%])(3[0-9]{2}[ .][0-9]{3}[ .][0-9]{3,4})(?:$|[^0-9A-Za-z])`,
]

_digits(s) := regex.replace(s, `[^0-9]`, "")

_phone_like(s) if {
	n := count(_digits(s))
	n >= 9
	n <= 15
}

violation if {
	input.jurisdiction == "EU"
	some p in _patterns
	some m in regex.find_all_string_submatch_n(p, normalize.text, -1)
	_phone_like(m[1])
}

rule_id := "rego-gdpr5-1c-002"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed (‘data minimisation’)\"."
severity := "medium"

remediation := "Block the request: it contains a phone number. Remove or pseudonymise personal data before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
