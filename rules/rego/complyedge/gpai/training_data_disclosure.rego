# ComplyEdge — EU AI Act Article 53(1)(d): GPAI Training Content Summary
#
# Providers of general-purpose AI models shall draw up and make publicly
# available a sufficiently detailed summary about the content used for
# training of the general-purpose AI model, according to a template
# provided by the AI Office.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(d)
# Recital: 107 — GPAI providers must publish a sufficiently detailed public summary of training content using the AI Office template; this obligation applies even to open-source providers (Art 53(2) exempts only points (a) and (b))
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Art 53(1)(d) is the public training-content summary obligation.
# Art 53(1)(c) (copyright_transparency.rego) covers the copyright compliance
# policy. Art 53(1)(b) (downstream_obligations.rego) covers downstream
# integrator documentation per Annex XII.

package complyedge.gpai.training_data_disclosure

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	training_data_disclosure_pattern_match
}

training_data_disclosure_pattern_match if {
	patterns := [
		"(?:gpai|general[\\- ]?purpose|foundation[\\- ]?model|llm).*(?:released|deployed|launched|placed).*(?:without|lacking).*(?:training[\\- ]?(?:data|content)[\\- ]?summar|public[\\- ]?(?:training[\\- ]?)?disclosure)",
		"(?:no|without|missing).*(?:public(?:ly)?[\\- ]?(?:available)?)?.*training[\\- ]?(?:data|content)[\\- ]?summar",
		"(?:training[\\- ]?(?:data|content)|training[\\- ]?corpus|training[\\- ]?sources).*(?:summary|disclosure).*(?:not[\\- ]?published|undisclosed|hidden|withheld|conceal)",
		"(?:refus|withhold|conceal|hid).*(?:training[\\- ]?(?:data|content|sources|corpus)).*(?:disclosure|summary|information|details)",
		"(?:skip|omit|bypass).*(?:training[\\- ]?content[\\- ]?summar|public[\\- ]?training[\\- ]?disclosure)",
		"(?:vague|token|minimal|insufficient).*(?:training[\\- ]?(?:data|content)[\\- ]?summar).*(?:not[\\- ]?sufficient|insufficient|inadequate|non[\\- ]?compliant)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53d-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(d): Providers of general-purpose AI models shall draw up and make publicly available a sufficiently detailed summary about the content used for training of the general-purpose AI model, according to a template provided by the AI Office."

severity := "high"

remediation := "Publish a sufficiently detailed public summary of the training content used for the GPAI model, following the AI Office template. Open-source providers remain subject to this obligation; systemic-risk models must comply regardless of licence."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
