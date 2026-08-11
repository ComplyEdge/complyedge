# ComplyEdge — EU AI Act Article 27: Fria
#
# Legal citation: Regulation (EU) 2024/1689, Article 27
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.highrisk.art27_fria

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:without|no|skip\\w*)\\s+(?:fundamental\\s+rights?\\s+)?impact\\s+assessment",
		"(?:no|without)\\s+(?:fria|fundamental\\s+rights?\\s+(?:impact\\s+)?assessment)\\s+(?:for\\s+)?(?:high[\\-\\s]?risk|deployment)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art27-001"

citation := "Regulation (EU) 2024/1689, Article 27(1): Prior to deploying a high-risk AI system referred to in Article 6(2), with the exception of high-risk AI systems intended to be used in the area listed in point 2 of Annex III, deployers that are bodies governed by public law, or are private entities providing public services, and deployers of high-risk AI systems referred to in points 5(b) and (c) of Annex III, shall perform an assessment of the impact on fundamental rights that the use of such system may produce. Article 27(3): Once the assessment has been performed, the deployer shall notify the market surveillance authority of its results."
severity := "high"

remediation := "Perform a fundamental rights impact assessment before deploying the high-risk AI system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
