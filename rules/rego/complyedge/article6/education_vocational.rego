# ComplyEdge: EU AI Act Article 6 + Annex III §3: Education and Vocational Training
#
# Flags text describing AI used for admissions and for grading or exam scoring
# (Annex III, points 3(a) and 3(b)). Points 3(c) (level of education) and 3(d)
# (monitoring prohibited behaviour during tests) are not matched by the patterns.
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 3
# Recital: 56: AI systems in education and vocational training that determine access, evaluate learning outcomes, assess the level of education or monitor students during tests
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 3

package complyedge.article6.education_vocational

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:student\\s+admission|admissions\\s+screening|admit\\s+student)",
		"\\bai\\b.*(?:grading|automated\\s+grading|exam\\s+scoring|test\\s+scoring)",
		"\\bai\\b.*(?:assess|evaluate)\\s+student",
		"automated\\s+(?:grading|assessment|admissions?)\\s+(?:system|\\bai|tool)",
		"educational\\s+ai\\s+(?:assess|grad|admiss)",
		"vocational\\s+(?:admission|placement)\\s+(?:\\bai|ml|system)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-3-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 3: Education and vocational training: (a) AI systems intended to be used to determine access or admission or to assign natural persons to educational and vocational training institutions at all levels; (b) AI systems intended to be used to evaluate learning outcomes, including when those outcomes are used to steer the learning process of natural persons in educational and vocational training institutions at all levels; (c) AI systems intended to be used for the purpose of assessing the appropriate level of education that an individual will receive or will be able to access, in the context of or within educational and vocational training institutions at all levels; (d) AI systems intended to be used for monitoring and detecting prohibited behaviour of students during tests in the context of or within educational and vocational training institutions at all levels."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Educational AI systems require human oversight, bias testing, transparency, technical documentation, and post-market monitoring per Articles 8–17. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
