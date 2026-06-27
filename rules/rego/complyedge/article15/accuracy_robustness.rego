# ComplyEdge — EU AI Act Article 15: Accuracy, Robustness and Cybersecurity
#
# High-risk AI systems shall achieve an appropriate level of accuracy,
# robustness, and cybersecurity, performing consistently throughout their
# lifecycle. They shall be resilient against errors, faults, environmental
# inconsistencies, and unauthorized third-party manipulation including
# adversarial attacks and model poisoning.
#
# Legal citation: Regulation (EU) 2024/1689, Article 15, paragraph 1
# Recital: 71 — high-risk AI must maintain appropriate accuracy, robustness, and cybersecurity across the lifecycle
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Distinct from gpai/cybersecurity_measures.rego (Art 55(1)(d)
# systemic-risk GPAI). This rule covers high-risk AI under Chapter III Section 2.

package complyedge.article15.accuracy_robustness

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	accuracy_robustness_pattern_match
}

accuracy_robustness_pattern_match if {
	patterns := [
		"(?:without|no|skip|omit).*(?:accuracy|robustness|cybersecurity).*(?:testing|validation|assessment|evaluation).*(?:high[\\- ]?risk|ai[\\- ]?system|lifecycle)?",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|lacking).*(?:accuracy|robustness|cybersecurity).*(?:testing|validation|assessment|protection|measures)",
		"(?:no|without).*(?:adversarial|robustness|accuracy).*(?:testing|assessment|evaluation|validation).*(?:high[\\- ]?risk|ai|model|system)",
		"(?:vulnerable|exposed).*(?:to|against).*(?:adversarial|model[\\- ]?poisoning|manipulation|attack).*(?:high[\\- ]?risk|ai|system|model)?",
		"(?:adversarial|model[\\- ]?poisoning).*(?:not[\\- ]?(?:tested|assessed|mitigated|addressed)).*(?:high[\\- ]?risk|ai|system|model)?",
		"(?:accuracy|robustness).*(?:not[\\- ]?(?:declared|documented|tested|validated|achieved)).*(?:high[\\- ]?risk|instructions?[\\- ]?for[\\- ]?use|ai[\\- ]?system)?",
		"(?:deploy|launch|place|market).*(?:high[\\- ]?risk).*(?:without|no).*(?:accuracy|robustness|security).*(?:testing|validation|assessment)",
		"(?:no|without).*(?:resilience|resilient).*(?:against|to).*(?:errors|faults|attacks|manipulation).*(?:high[\\- ]?risk|ai|system)?",
		"(?:no|without|insufficient).*(?:cybersecurity|security).*(?:protection|measure|assessment).*(?:high[\\- ]?risk|ai[\\- ]?system)",
		"(?:article[\\- ]?15|art\\.?\\s*15).*(?:not[\\- ]?met|ignored|skipped|bypassed|omitted)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-1-001"

citation := "Regulation (EU) 2024/1689, Article 15, paragraph 1: High-risk AI systems shall be designed and developed to achieve an appropriate level of accuracy, robustness, and cybersecurity, performing consistently throughout their lifecycle and remaining resilient against unauthorized third-party manipulation."

severity := "high"

remediation := "Achieve and document appropriate accuracy levels in instructions for use; test robustness against errors, faults, and environmental inconsistencies; implement cybersecurity proportionate to risks including adversarial attacks, model poisoning, and confidentiality threats; validate performance consistently across the lifecycle."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
