# ComplyEdge — EU AI Act Article 6 + Annex III §3: Education and Vocational Training
#
# Classifies AI systems used in education (admissions, grading, exam scoring,
# student assessment, vocational training admissions) as high-risk under
# Annex III §3.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(3)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)

package complyedge.article6.education_vocational

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:student\\s+admission|admissions\\s+screening|admit\\s+student)",
		"ai.*(?:grading|automated\\s+grading|exam\\s+scoring|test\\s+scoring)",
		"ai.*(?:assess|evaluate)\\s+student",
		"automated\\s+(?:grading|assessment|admissions?)\\s+(?:system|ai|tool)",
		"educational\\s+ai\\s+(?:assess|grad|admiss)",
		"vocational\\s+(?:admission|placement)\\s+(?:ai|ml|system)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-3-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(3): AI systems used in education and vocational training for admissions, grading, evaluation, or proctoring are high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Educational AI systems require human oversight, bias testing, transparency, technical documentation, and post-market monitoring per Articles 8–17."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
