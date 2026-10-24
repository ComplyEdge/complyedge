# ComplyEdge - GDPR Article 5(1)(c): Italian fiscal code (codice fiscale) in AI text
#
# The text carries an Italian codice fiscale: 16 characters in the fixed
# surname-name-birth-place shape, plain or with spaces between its blocks, whose final control character is the one the
# first fifteen require (odd/even position tables, sum mod 26). A string of
# the right shape with the wrong control character does not fire.
#
# Layer 1 detects: a 16-character codice fiscale, three letters, three
# letters, two year characters, a month letter, two day characters, a letter
# and three place characters, then the control letter, with digits allowed in
# their letter substitutes and an optional single space between blocks, in any
# case, whose control letter is the one the odd and even position tables give
# (sum mod 26). It matches formats, not purpose: it fires on every such value
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

package complyedge.data_protection.national_id_it

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_pattern := `(?:^|[^0-9A-Za-z])([A-Za-z]{3}[ ]?[A-Za-z]{3}[ ]?[0-9LMNPQRSTUVlmnpqrstuv]{2}[ABCDEHLMPRSTabcdehlmprst][0-9LMNPQRSTUVlmnpqrstuv]{2}[ ]?[A-Za-z][0-9LMNPQRSTUVlmnpqrstuv]{3}[ ]?[A-Za-z])(?:$|[^0-9A-Za-z])`

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
	s := upper(replace(raw, " ", ""))
	count(s) == 16
	total := sum([_term(s, i) | some i in numbers.range(0, 14)])
	substring(s, 15, 1) == substring(_even_alphabet, total % 26, 1)
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, normalize.text, -1)
	_valid_cf(m[1])
}

rule_id := "rego-gdpr5-1c-009"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed (‘data minimisation’)\"."
severity := "high"

remediation := "Block the request: it contains a national identification number. Remove it before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
