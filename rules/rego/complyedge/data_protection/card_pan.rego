# ComplyEdge - GDPR Article 5(1)(c): payment card number in AI text
#
# The text carries a payment card number: 13 to 19 digits, plain or in groups
# separated by spaces, dots or dashes, starting with a card-network prefix (Visa 4,
# Mastercard 51-55 / 22-27, American Express 34 / 37, Discover 6011 / 65) and
# passing the Luhn check. A card number identifies its holder. Digit runs that
# fail Luhn or carry no network prefix do not fire. A security code or expiry
# written after the number with the same separator ("4539 1488 0343 6467 321",
# "4539148803436467 12/28") joins the digit run, so the check also runs on the
# run without its last group when that group has at most four digits.
#
# Layer 1 detects: 13 to 19 digits, unbroken or separated by single spaces,
# dots or dashes, starting 4, 51 to 55, 22 to 27, 34, 37, 6011 or 65, that
# pass the Luhn check, either as written or with a last group of up to four
# digits (a security code or expiry) left off; no letter, digit or % directly
# before it. It matches formats, not purpose: it fires on every such value
# whatever the task, and it does not judge whether sending the value is
# necessary for the task (the Article 5(1)(c) test, which this rule does not
# apply). No model reviews a hit: a match keeps the block in Layer 2 as well.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 5(1)(c)
# Recital: 39 - personal data should be adequate, relevant and limited to what is necessary
# Effective: 2018-05-25
# Penalty: GDPR Article 83(5)(a): up to EUR 20,000,000 or 4% of worldwide annual turnover
# Condition type: deterministic (format match plus checksum; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# ELI: http://data.europa.eu/eli/reg/2016/679/art_5/par_1/pnt_c/oj
# Provision: Regulation (EU) 2016/679, Article 5(1)(c)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.data_protection.card_pan

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_pattern := `(?:^|[^0-9A-Za-z%])((?:[0-9][ .-]?){12,18}[0-9])(?:$|[^0-9A-Za-z])`

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
	d := regex.replace(raw, `[ .-]`, "")
	n := count(d)
	n >= 13
	n <= 19
	_network(d)
	sum([_luhn_term(d, i, n) | some i in numbers.range(0, n - 1)]) % 10 == 0
}

_candidates(raw) := {raw} | {c |
	groups := regex.split(`[ .-]`, raw)
	n := count(groups)
	n > 1
	count(groups[n - 1]) <= 4
	c := concat("", array.slice(groups, 0, n - 1))
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, normalize.text, -1)
	some c in _candidates(m[1])
	_valid_pan(c)
}

rule_id := "rego-gdpr5-1c-004"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed (‘data minimisation’)\"."
severity := "critical"

remediation := "Block the request: it contains a payment card number. Remove it before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
