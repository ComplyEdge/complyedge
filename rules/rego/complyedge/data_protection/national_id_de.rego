# ComplyEdge - GDPR Article 5(1)(c)/(f): German tax identification number in AI text
#
# The text carries a German Steuerliche Identifikationsnummer: 11 digits, the
# first not 0, written plain or in groups of 2-3-3-3, whose check digit is
# valid under ISO 7064 MOD 11,10. It is assigned to one person for life.
# An 11-digit run with a wrong check digit does not fire.
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

package complyedge.data_protection.national_id_de

import rego.v1

default violation := false

_pattern := `(?:^|[^0-9A-Za-z%])([1-9][0-9][ ]?[0-9]{3}[ ]?[0-9]{3}[ ]?[0-9]{3})(?:$|[^0-9A-Za-z])`

# ISO 7064 MOD 11,10, unrolled over the ten payload digits.
_step(p, digit) := q if {
	s := (digit + p) % 10
	t := ((s + (10 * to_number(s == 0))) * 2) % 11
	q := t
}

_valid_steuer_id(raw) if {
	d := replace(raw, " ", "")
	count(d) == 11
	x := [to_number(c) | some c in split(d, "")]
	p1 := _step(10, x[0])
	p2 := _step(p1, x[1])
	p3 := _step(p2, x[2])
	p4 := _step(p3, x[3])
	p5 := _step(p4, x[4])
	p6 := _step(p5, x[5])
	p7 := _step(p6, x[6])
	p8 := _step(p7, x[7])
	p9 := _step(p8, x[8])
	p10 := _step(p9, x[9])
	check := (11 - p10) % 10
	check == x[10]
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, input.text, -1)
	_valid_steuer_id(m[1])
}

rule_id := "rego-gdpr5-1c-005"

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
