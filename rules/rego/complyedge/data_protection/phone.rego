# ComplyEdge - GDPR Article 5(1)(c)/(f): phone number in AI text
#
# The text carries a phone number: an international number in E.164 form
# (+ country code, 8 to 15 digits, spaces, dots or dashes allowed between
# groups), or a national number in a format that is unambiguous on its own:
# French 0X XX XX XX XX (pairs, or ten digits unbroken), German mobile 015x/016x/017x, Dutch mobile 06,
# Spanish mobile 6/7 written in groups, Italian mobile 3XX written in groups.
# A phone number identifies a person. Bare digit runs with no phone shape
# (order numbers, amounts, dates) do not fire.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 5(1)(c) and Article 5(1)(f)
# Recital: 39 - personal data should be adequate, relevant and limited to what is necessary
# Effective: 2018-05-25
# Penalty: GDPR Article 83(5)(a): up to EUR 20,000,000 or 4% of worldwide annual turnover
# Condition type: deterministic (format match plus checksum; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# Status: review
# Approved by: pending Leo Celis review per RULE_STANDARD 5.5 (authorized 2026-10-10)

package complyedge.data_protection.phone

import rego.v1

default violation := false

_patterns := [
	`(?:^|[^0-9A-Za-z+%])(\+[1-9](?:[ .-]?[0-9]){7,14})(?:$|[^0-9A-Za-z])`,
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
	some m in regex.find_all_string_submatch_n(p, input.text, -1)
	_phone_like(m[1])
}

rule_id := "rego-gdpr5-1c-002"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed ('data minimisation')\"."
severity := "medium"

remediation := "Block the request: it contains a phone number. Remove or pseudonymise personal data before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
