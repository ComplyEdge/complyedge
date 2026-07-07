# ComplyEdge — EU AI Act Article 6 + Annex III §1: Biometric Identification Systems
#
# Classifies AI biometric identification systems (post-remote biometric ID,
# facial recognition systems for identification, gait/voice/iris ID) as
# high-risk under Annex III §1. NOT prohibited (that's Article 5(1)(g)/(h)) —
# these are permitted only with conformity assessment + high-risk
# classification under Article 6.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(1)
# Effective: 2026-08-02 (Annex III high-risk obligations enter into force)
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5; card 197 / WGlhJpPN)

package complyedge.article6.biometric_identification

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"biometric[\\- ]identification\\s+system",
		"facial\\s+recognition\\s+system",
		"deploy.*facial\\s+recognition",
		"gait\\s+analysis\\s+(?:system|ai)",
		"voice\\s+identification\\s+(?:system|ai)",
		"iris\\s+scan(?:ning)?\\s+(?:system|ai)",
		"remote\\s+biometric\\s+identification",
		"post[\\- ]remote\\s+biometric",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-1-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(1): AI biometric identification systems (post-remote biometric, gait/voice/iris) are high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Maintain technical documentation per Annex IV, conformity assessment, and ongoing risk management for the biometric identification system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
