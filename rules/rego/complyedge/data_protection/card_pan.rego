# ComplyEdge - GDPR Article 5(1)(c)/(f): payment card number in AI text
#
# The text carries a payment card number: 13 to 19 digits, plain or in groups
# separated by spaces or dashes, starting with a card-network prefix (Visa 4,
# Mastercard 51-55 / 22-27, American Express 34 / 37, Discover 6011 / 65) and
# passing the Luhn check. A card number identifies its holder. Digit runs that
# fail Luhn or carry no network prefix do not fire.
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

package complyedge.data_protection.card_pan

import rego.v1

default violation := false

_pattern := `(?:^|[^0-9A-Za-z%])((?:[0-9][ -]?){12,18}[0-9])(?:$|[^0-9A-Za-z])`

_network(d) if regex.match(`^(?:4|5[1-5]|2[2-7]|3[47]|6011|65)`, d)

# Luhn: from the right, double every second digit, subtract 9 when over 9.
_luhn_term(d, i, n) := v if {
	x := to_number(substring(d, i, 1))
	((n - 1) - i) % 2 == 0
	v := x
}

_luhn_term(d, i, n) := v if {
	x := to_number(substring(d, i, 1))
	((n - 1) - i) % 2 == 1
	y := x * 2
	v := y - (9 * to_number(y > 9))
}

_valid_pan(raw) if {
	d := regex.replace(raw, `[ -]`, "")
	n := count(d)
	n >= 13
	n <= 19
	_network(d)
	sum([_luhn_term(d, i, n) | some i in numbers.range(0, n - 1)]) % 10 == 0
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, input.text, -1)
	_valid_pan(m[1])
}

rule_id := "rego-gdpr5-1c-004"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed ('data minimisation')\"."
severity := "critical"

remediation := "Block the request: it contains a payment card number. Remove it before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
