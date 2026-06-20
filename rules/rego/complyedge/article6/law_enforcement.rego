# ComplyEdge — EU AI Act Article 6 + Annex III §6: Law Enforcement
#
# Classifies AI systems used by or on behalf of law enforcement for
# individual-risk assessment, evidence reliability, predictive policing
# (where not prohibited by Art 5(1)(d)), suspect ID profiling, lie
# detection, and crime analytics as high-risk under Annex III §6.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(6)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: agent review — pending Leo sign-off (RULE_STANDARD §5, card 197)
# Approved by: (TBD)

package complyedge.article6.law_enforcement

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:predictive\\s+polic|crime\\s+predict|recidivism\\s+predict)",
		"ai.*(?:suspect\\s+identif|profile\\s+suspect|lie\\s+detect|polygraph)",
		"ai.*(?:evidence\\s+assess|reliab.*evidence)",
		"law\\s+enforcement\\s+ai",
		"ai\\s+(?:assist|aid).*(?:investig|prosecut)",
		"crime\\s+analytics\\s+(?:ai|ml|model)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-6-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(6): AI used by law enforcement for individual risk assessment, predictive policing (where not prohibited by Art 5(1)(d)), profiling, lie detection, or evidence assessment is high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Law-enforcement AI requires fundamental-rights impact assessment (Art 27), human oversight, data quality controls (Art 10), and registration in the EU database."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
