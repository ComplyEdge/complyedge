# ComplyEdge - GDPR Article 5(1)(c): Spanish DNI / NIE in AI text
#
# The text carries a Spanish DNI (8 digits and a control letter) or NIE
# (X, Y or Z, 7 digits and a control letter); a DNI may be written with dots
# (12.345.678-Z) and a NIE with dashes or spaces (X-1234567-L), whose control letter is the one
# the number requires (number mod 23 into TRWAGMYFPDXBNJZSQVHLCKE). A DNI-shaped
# string with the wrong letter does not fire.
#
# Layer 1 detects: a DNI, 8 digits (or 2.3.3 digits separated by dots) then a
# letter, and a NIE, X, Y or Z then 7 digits then a letter, with an optional
# single dash or space after the first letter and before the last, in any
# case, whose last letter is the one TRWAGMYFPDXBNJZSQVHLCKE gives at the
# number mod 23. It matches formats, not purpose: it fires on every such value
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

package complyedge.data_protection.national_id_es

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_pattern := `(?:^|[^0-9A-Za-z])((?:[XYZxyz][- ]?)?(?:[0-9]{7,8}|[0-9]{2}\.[0-9]{3}\.[0-9]{3})[- ]?[A-Za-z])(?:$|[^0-9A-Za-z])`

_letters := "TRWAGMYFPDXBNJZSQVHLCKE"

_number(s) := to_number(s) if regex.match(`^[0-9]{8}$`, s)

_number(s) := to_number(concat("", [sprintf("%d", [indexof("XYZ", substring(s, 0, 1))]), substring(s, 1, 7)])) if regex.match(`^[XYZ][0-9]{7}$`, s)

_valid_dni(raw) if {
	s := upper(regex.replace(raw, `[-. ]`, ""))
	count(s) == 9
	head := substring(s, 0, 8)
	letter := substring(s, 8, 1)
	letter == substring(_letters, _number(head) % 23, 1)
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, normalize.text, -1)
	_valid_dni(m[1])
}

rule_id := "rego-gdpr5-1c-007"

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
