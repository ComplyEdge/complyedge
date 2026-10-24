# ComplyEdge - GDPR Article 5(1)(c): bank account number (IBAN) in AI text
#
# The text carries an IBAN, in upper or lower case, compact or in groups of
# four separated by spaces, whose ISO 13616 check digits are valid (mod 97 = 1).
# A bank account number identifies its holder and is financial personal data.
# A string with the IBAN shape but wrong check digits does not fire. A word of
# up to four letters or digits after a grouped IBAN has the shape of one more
# group, so the check also runs on the IBAN with the trailing groups left off.
#
# Layer 1 detects: two letters, two digits, then two to seven groups of four
# letters or digits and an optional last group of one to four, with or without
# a single space between groups, in any case, 15 to 34 characters in all,
# whose ISO 13616 check digits are valid (mod 97 equals 1) for the whole
# string or for the string with its trailing space-separated groups left off.
# It does not check the length a country sets for its IBANs. It matches
# formats, not purpose: it fires on every such value whatever the task, and it
# does not judge whether sending the value is necessary for the task (the
# Article 5(1)(c) test, which this rule does not apply). No model reviews a
# hit: a match keeps the block in Layer 2 as well.
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

package complyedge.data_protection.iban

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_pattern := `(?:^|[^A-Za-z0-9])([A-Za-z]{2}[0-9]{2}(?:[ ]?[A-Za-z0-9]{4}){2,7}(?:[ ]?[A-Za-z0-9]{1,4})?)(?:$|[^A-Za-z0-9])`

_pow := [1, 10, 3, 30, 9, 90, 27, 76, 81, 34, 49, 5, 50, 15, 53, 45, 62, 38, 89, 17, 73, 51, 25, 56, 75, 71, 31, 19, 93, 57, 85, 74, 61, 28, 86, 84, 64, 58, 95, 77, 91, 37, 79, 14, 43, 42, 32, 29, 96, 87, 94, 67, 88, 7, 70, 21, 16, 63, 48, 92, 47, 82, 44, 52, 35, 59, 8, 80, 24, 46, 72, 41, 22, 26, 66, 78, 4, 40, 12, 23]

_alphabet := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Each character as its ISO 13616 number: digits stay, A=10 ... Z=35.
_as_digits(s) := concat("", [sprintf("%d", [indexof(_alphabet, c)]) | some c in split(s, "")])

_valid_iban(raw) if {
	s := upper(replace(raw, " ", ""))
	count(s) >= 15
	count(s) <= 34
	rearranged := concat("", [substring(s, 4, -1), substring(s, 0, 4)])
	d := _as_digits(rearranged)
	n := count(d)
	n <= count(_pow)
	total := sum([(to_number(substring(d, i, 1)) * _pow[(n - 1) - i]) | some i in numbers.range(0, n - 1)])
	total % 97 == 1
}

# The match and every shorter run of its space-separated groups: in
# "ES91 2100 0418 4502 0005 1332 to pay" the pattern also takes " to", and the
# IBAN is the run without it.
_candidates(raw) := {c |
	groups := split(raw, " ")
	some k in numbers.range(1, count(groups))
	c := concat("", array.slice(groups, 0, k))
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, normalize.text, -1)
	some c in _candidates(m[1])
	_valid_iban(c)
}

rule_id := "rego-gdpr5-1c-003"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed (‘data minimisation’)\"."
severity := "high"

remediation := "Block the request: it contains a bank account number (IBAN). Remove it before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
