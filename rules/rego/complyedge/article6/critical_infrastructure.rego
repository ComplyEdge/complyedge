# ComplyEdge: EU AI Act Article 6 + Annex III §2: Critical Infrastructure
#
# Flags text describing AI used in the management and operation of critical
# infrastructure. Annex III, point 2 covers only safety components in the
# management and operation of critical digital infrastructure, road traffic,
# or the supply of water, gas, heating or electricity.
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 2
# Recital: 55: safety components in the management and operation of critical digital infrastructure, road traffic and the supply of water, gas, heating and electricity
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 2

package complyedge.article6.critical_infrastructure

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:power\\s+grid|electricity|water\\s+supply|gas\\s+distribution|traffic\\s+management|transport\\s+infrastructure)",
		"(?:power\\s+grid|water\\s+supply|gas|traffic|transport)\\s+(?:management|control|optimization)\\s+(?:\\bai|ml|model)",
		"critical\\s+infrastructure\\s+(?:\\bai|ml|system)",
		"smart\\s+grid\\s+(?:\\bai|control|optimization)",
		"traffic\\s+control\\s+(?:\\bai|automation)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-2-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 2: Critical infrastructure: AI systems intended to be used as safety components in the management and operation of critical digital infrastructure, road traffic, or in the supply of water, gas, heating or electricity."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Critical infrastructure AI requires conformity assessment, technical documentation (Annex IV), human oversight, and post-market monitoring. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
