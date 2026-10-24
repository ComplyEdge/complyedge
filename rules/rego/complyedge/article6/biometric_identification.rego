# ComplyEdge: EU AI Act Article 6 + Annex III §1: Biometric Identification Systems
#
# Flags text describing remote biometric identification systems (facial, gait,
# voice or iris identification, including post-remote identification), which
# Annex III, point 1(a) lists as high-risk. Point 1(a) excludes biometric
# verification whose sole purpose is to confirm that a person is who they claim
# to be. Points 1(b) (categorisation) and 1(c) (emotion recognition) are not
# covered by this rule. Article 5(1)(h) prohibits only real-time remote
# biometric identification in publicly accessible spaces for law enforcement;
# other remote biometric identification is high-risk, not prohibited.
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 1(a)
# Recital: 54: remote biometric identification systems are high-risk because their technical inaccuracies can lead to biased, discriminatory results; biometric verification is excluded
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 1(a)

package complyedge.article6.biometric_identification

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"biometric[\\-\\s]identification\\s+system",
		"facial\\s+recognition\\s+system",
		"deploy.*facial\\s+recognition",
		"gait\\s+analysis\\s+(?:system|\\bai)",
		"voice\\s+identification\\s+(?:system|\\bai)",
		"iris\\s+scan(?:ning)?\\s+(?:system|\\bai)",
		"remote\\s+biometric\\s+identification",
		"post[\\-\\s]remote\\s+biometric",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-1-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 1(a): Biometrics, in so far as their use is permitted under relevant Union or national law: (a) remote biometric identification systems. This shall not include AI systems intended to be used for biometric verification the sole purpose of which is to confirm that a specific natural person is the person he or she claims to be;"
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Maintain technical documentation per Annex IV, conformity assessment, and ongoing risk management for the biometric identification system. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
