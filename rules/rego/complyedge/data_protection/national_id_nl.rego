# ComplyEdge - GDPR Article 5(1)(c): Dutch citizen service number (BSN) in AI text
#
# The text carries a Dutch BSN: 9 digits, standalone or as 3-3-3 / 4-2-3
# groups separated by spaces or dots, followed by a space, punctuation or the
# end of the text, that pass the eleven test (9*d1 + 8*d2 + ... + 2*d8 - d9 is a
# multiple of 11, and not zero). Limit, stated plainly: the eleven test is
# passed by about one 9-digit number in eleven, so an unrelated 9-digit
# reference number can fire. Longer digit runs never fire.
#
# Layer 1 detects: 9 digits, unbroken or in groups of 3 or 4 digits separated
# by a single space or dot, not part of a longer number or a decimal, that
# pass the eleven test (9 times the first digit plus 8 times the second and so
# on down to 2 times the eighth, minus the ninth, is a non-zero multiple of
# 11). About one 9-digit number in eleven passes, so an unrelated reference
# number can fire. It matches formats, not purpose: it fires on every such
# value whatever the task, and it does not judge whether sending the value is
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

package complyedge.data_protection.national_id_nl

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_pattern := `(?:^|[^0-9A-Za-z.,%])([0-9]{3,4}[ .]?[0-9]{2,3}[ .]?[0-9]{3,4})(?:$|[^0-9A-Za-z.,]|[.,](?:[^0-9]|$))`

_valid_bsn(raw) if {
	d := regex.replace(raw, `[ .]`, "")
	count(d) == 9
	x := [to_number(c) | some c in split(d, "")]
	total := ((((((((9 * x[0]) + (8 * x[1])) + (7 * x[2])) + (6 * x[3])) + (5 * x[4])) + (4 * x[5])) + (3 * x[6])) + (2 * x[7])) - x[8]
	total != 0
	total % 11 == 0
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, normalize.text, -1)
	_valid_bsn(m[1])
}

rule_id := "rego-gdpr5-1c-008"

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
