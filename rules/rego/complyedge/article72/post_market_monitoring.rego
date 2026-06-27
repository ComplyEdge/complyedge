# ComplyEdge — EU AI Act Article 72: Post-Market Monitoring
#
# Providers of high-risk AI systems shall establish and document a post-market
# monitoring system proportionate to the nature of the AI technologies and
# the risks of the high-risk AI system.
#
# Legal citation: Regulation (EU) 2024/1689, Article 72, paragraph 1
# Recital: 123 — high-risk providers must collect and analyse performance data throughout the system lifetime via post-market monitoring
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article72.post_market_monitoring

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	post_market_monitoring_pattern_match
}

post_market_monitoring_pattern_match if {
	patterns := [
		"(?:no|without|skip|omit|bypass).*(?:post[\\- ]?market[\\- ]?monitor|postmarket[\\- ]?monitor).*(?:high[\\- ]?risk|ai[\\- ]?system|plan|system)?",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|lacking).*(?:post[\\- ]?market[\\- ]?monitor|performance[\\- ]?monitor|market[\\- ]?surveillance[\\- ]?plan)",
		"(?:deploy|launch|place).*(?:high[\\- ]?risk).*(?:without|before).*(?:post[\\- ]?market[\\- ]?monitor|monitoring[\\- ]?plan|performance[\\- ]?tracking)",
		"(?:post[\\- ]?market[\\- ]?monitor).*(?:not[\\- ]?(?:established|implemented|documented|maintained|required))",
		"(?:article[\\- ]?72|art\\.?\\s*72).*(?:not[\\- ]?met|ignored|skipped|omitted)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art72-1-001"

citation := "Regulation (EU) 2024/1689, Article 72, paragraph 1: Providers of high-risk AI systems shall establish and document a post-market monitoring system in a manner that is proportionate to the nature of the AI technologies and the risks of the high-risk AI system."

severity := "high"

remediation := "Establish and document a post-market monitoring system proportionate to system risks. Collect, document, and analyse relevant performance data throughout the high-risk AI system's lifetime and feed results into risk management."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
