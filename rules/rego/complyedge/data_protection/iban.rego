# ComplyEdge - GDPR Article 5(1)(c)/(f): bank account number (IBAN) in AI text
#
# The text carries an IBAN whose ISO 13616 check digits are valid (mod 97 = 1).
# A bank account number identifies its holder and is financial personal data.
# A string with the IBAN shape but wrong check digits does not fire.
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

package complyedge.data_protection.iban

import rego.v1

default violation := false

_pattern := `(?:^|[^A-Za-z0-9])([A-Z]{2}[0-9]{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?)(?:$|[^A-Za-z0-9])`

_pow := [1, 10, 3, 30, 9, 90, 27, 76, 81, 34, 49, 5, 50, 15, 53, 45, 62, 38, 89, 17, 73, 51, 25, 56, 75, 71, 31, 19, 93, 57, 85, 74, 61, 28, 86, 84, 64, 58, 95, 77, 91, 37, 79, 14, 43, 42, 32, 29, 96, 87, 94, 67, 88, 7, 70, 21, 16, 63, 48, 92, 47, 82, 44, 52, 35, 59, 8, 80, 24, 46, 72, 41, 22, 26, 66, 78, 4, 40, 12, 23]

_alphabet := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Each character as its ISO 13616 number: digits stay, A=10 ... Z=35.
_as_digits(s) := concat("", [sprintf("%d", [indexof(_alphabet, c)]) | some c in split(s, "")])

_valid_iban(raw) if {
	s := replace(raw, " ", "")
	count(s) >= 15
	count(s) <= 34
	rearranged := concat("", [substring(s, 4, -1), substring(s, 0, 4)])
	d := _as_digits(rearranged)
	n := count(d)
	n <= count(_pow)
	total := sum([(to_number(substring(d, i, 1)) * _pow[(n - 1) - i]) | some i in numbers.range(0, n - 1)])
	total % 97 == 1
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, input.text, -1)
	_valid_iban(m[1])
}

rule_id := "rego-gdpr5-1c-003"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed ('data minimisation')\"."
severity := "high"

remediation := "Block the request: it contains a bank account number (IBAN). Remove it before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
