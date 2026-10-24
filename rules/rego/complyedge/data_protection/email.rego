# ComplyEdge - GDPR Article 5(1)(c): email address in AI text
#
# The text carries an email address. An email address identifies a person, so
# sending it to an AI model (or returning it to a user) is processing personal
# data beyond what the AI task needs. Addresses at the reserved example domains
# of RFC 2606 / RFC 6761 (example.com, .test, .example, .invalid) are
# documentation placeholders, not people, and do not fire.
#
# Layer 1 detects: an email address, letters, digits and . _ % + - before the
# @, and a domain of one or more labels ending in a top-level domain of at
# least two letters, in any case, with no letter or digit directly before or
# after it; an address at example.com, example.org, example.net or a subdomain
# of them, or at a domain ending .test, .example, .invalid or .localhost does
# not fire. It matches formats, not purpose: it fires on every such value
# whatever the task, and it does not judge whether sending the value is
# necessary for the task (the Article 5(1)(c) test, which this rule does not
# apply). No model reviews a hit: a match keeps the block in Layer 2 as well.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 5(1)(c)
# Recital: 39 - personal data should be adequate, relevant and limited to what is necessary
# Effective: 2018-05-25
# Penalty: GDPR Article 83(5)(a): up to EUR 20,000,000 or 4% of worldwide annual turnover
# Condition type: deterministic (format match; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# ELI: http://data.europa.eu/eli/reg/2016/679/art_5/par_1/pnt_c/oj
# Provision: Regulation (EU) 2016/679, Article 5(1)(c)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.data_protection.email

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_pattern := `(?i)(?:^|[^A-Za-z0-9._%+-])([A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}))(?:$|[^A-Za-z0-9-])`

_reserved_domain(domain) if {
	d := lower(domain)
	some suffix in ["example.com", "example.org", "example.net"]
	d == suffix
}

_reserved_domain(domain) if {
	d := lower(domain)
	some suffix in ["example.com", "example.org", "example.net", ".test", ".example", ".invalid", ".localhost"]
	endswith(d, concat("", [".", trim_prefix(suffix, ".")]))
}

violation if {
	input.jurisdiction == "EU"
	some m in regex.find_all_string_submatch_n(_pattern, normalize.text, -1)
	not _reserved_domain(m[2])
}

rule_id := "rego-gdpr5-1c-001"

citation := "Regulation (EU) 2016/679 (GDPR), Article 5(1)(c): personal data shall be \"adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed (‘data minimisation’)\"."
severity := "medium"

remediation := "Block the request: it contains an email address. Remove or pseudonymise personal data before it reaches the AI model or the user."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
