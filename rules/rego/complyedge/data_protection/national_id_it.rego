# ComplyEdge - GDPR Article 5(1)(c)/(f): Italian fiscal code (codice fiscale) in AI text
#
# The text carries an Italian codice fiscale: 16 characters in the fixed
# surname-name-birth-place shape, whose final control character is the one the
# first fifteen require (odd/even position tables, sum mod 26). A string of
# the right shape with the wrong control character does not fire.
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

package complyedge.data_protection.national_id_it

import rego.v1

default violation := false

_pattern := `(?:^|[^0-9A-Za-z])([A-Za-z]{6}[0-9LMNPQRSTUVlmnpqrstuv]{2}[ABCDEHLMPRSTabcdehlmprst][0-9LMNPQRSTUVlmnpqrstuv]{2}[A-Za-z][0-9LMNPQRSTUVlmnpqrstuv]{3}[A-Za-z])(?:$|[^0-9A-Za-z])`

_odd := {
	"0": 1, "1": 0, "2": 5, "3": 7, "4": 9, "5": 13, "6": 15, "7": 17, "8": 19, "9": 21,
	"A": 1, "B": 0, "C": 5, "D": 7, "E": 9, "F": 13, "G": 15, "H": 17, "I": 19, "J": 21,
	"K": 2, "L": 4, "M": 18, "N": 20, "O": 11, "P": 3, "Q": 6, "R": 8, "S": 12, "T": 14,
	"U": 16, "V": 10, "W": 22, "X": 25, "Y": 24, "Z": 23,
}

_even_alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

_even(c) := to_number(c) if regex.match(`^[0-9]$`, c)

_even(c) := indexof(_even_alphabet, c) if regex.match(`^[A-Z]$`, c)

# Position 1, 3, 5 ... (index 0, 2, 4 ...) use the odd table.
_term(s, i) := _odd[substring(s, i, 1)] if i % 2 == 0

_term(s, i) := _even(substring(s, i, 1)) if i % 2 == 1

_valid_cf(raw) if {
	s := upper(raw)
	count(s) == 16
	total := sum([_term(s, i) | some i in numbers.range(0, 14)])
	substring(s, 15, 1) == substring(_even_alphabet, total % 26, 1)
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, input.text, -1)
	_valid_cf(m[1])
}

rule_id := "rego-gdpr5-1c-009"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed ('data minimisation')\"."
severity := "high"

remediation := "Block the request: it contains a national identification number. Remove it before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
