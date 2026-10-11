# ComplyEdge - GDPR Article 5(1)(c)/(f): French social security number (NIR) in AI text
#
# The text carries a French NIR (numero de securite sociale): sex digit 1 or 2,
# year, month, department (including Corsica 2A / 2B), commune, order number,
# plus a two-digit key equal to 97 minus the 13-digit number mod 97. Spaces
# between groups are allowed. A NIR-shaped number with a wrong key does not fire.
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

package complyedge.data_protection.national_id_fr

import rego.v1

default violation := false

_pattern := `(?:^|[^0-9A-Za-z])([12][ ]?[0-9]{2}[ ]?[0-9]{2}[ ]?(?:[0-9]{2}|2[AB])[ ]?[0-9]{3}[ ]?[0-9]{3}[ ]?[0-9]{2})(?:$|[^0-9A-Za-z])`

_valid_nir(raw) if {
	s := upper(replace(raw, " ", ""))
	count(s) == 15
	body := replace(replace(substring(s, 0, 13), "2A", "19"), "2B", "18")
	key := to_number(substring(s, 13, 2))
	key == 97 - (to_number(body) % 97)
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, input.text, -1)
	_valid_nir(m[1])
}

rule_id := "rego-gdpr5-1c-006"

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
