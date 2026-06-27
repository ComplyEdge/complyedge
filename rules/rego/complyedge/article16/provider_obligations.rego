# ComplyEdge — EU AI Act Article 16: High-Risk Provider Obligations
#
# Providers of high-risk AI systems shall ensure Section 2 compliance,
# provider identification, quality management, documentation, logs,
# conformity assessment, EU declaration, CE marking, registration,
# corrective actions, demonstrability on request, and accessibility.
#
# Legal citation: Regulation (EU) 2024/1689, Article 16, paragraph 1
# Recital: 79 — high-risk providers must satisfy comprehensive market-placement obligations before EU deployment
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article16.provider_obligations

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	provider_obligations_pattern_match
}

provider_obligations_pattern_match if {
	patterns := [
		"(?:place|plac(?:e|ing)|sell|deploy|launch|release).*(?:high[\\- ]?risk).*(?:ai|system).*(?:on|in).*(?:eu|union|market).*(?:without|lacking).*(?:ce[\\- ]?mark|conformity|registration|declaration)",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|missing|skip).*(?:ce[\\- ]?mark|conformity[\\- ]?assessment|eu[\\- ]?declaration|quality[\\- ]?management|qms|provider[\\- ]?registration)",
		"(?:no|without|skip|bypass).*(?:ce[\\- ]?mark|conformity[\\- ]?assessment|eu[\\- ]?declaration|quality[\\- ]?management|annex[\\- ]?iv).*(?:high[\\- ]?risk|ai[\\- ]?system|market)",
		"(?:article[\\- ]?16|provider[\\- ]?obligation).*(?:not[\\- ]?met|ignored|skipped|bypassed|circumvented)",
		"(?:provide|providing).*(?:high[\\- ]?risk).*(?:without|lacking).*(?:provider[\\- ]?(?:name|identification|contact)|technical[\\- ]?documentation)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art16-1-001"

citation := "Regulation (EU) 2024/1689, Article 16, paragraph 1: Providers of high-risk AI systems shall ensure Section 2 compliance, provider identification, quality management, documentation, conformity assessment, EU declaration of conformity, CE marking, registration, and corrective actions before placing the system on the market."

severity := "high"

remediation := "Complete the Article 16 provider checklist before EU market placement: Section 2 conformity, provider identification, QMS (Art 17), documentation (Art 18), logs (Art 19), Art 43 conformity assessment, EU declaration (Art 47), CE marking (Art 48), registration (Art 49), and accessibility requirements."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
