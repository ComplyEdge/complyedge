# ComplyEdge: EU AI Act Article 6 + Annex III §7: Migration, Asylum, Border Control
#
# Flags text describing AI used by or on behalf of competent public authorities
# for migration, asylum and border control management (Annex III, point 7):
# polygraphs, risk assessment of persons entering a Member State, examination of
# asylum, visa and residence applications, and detecting, recognising or
# identifying persons. Point 7(d) excludes the verification of travel documents.
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 7
# Recital: 60: migration, asylum and border control management systems used by competent public authorities
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 7

package complyedge.article6.migration_asylum

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:visa\\s+(?:application|decision|approv)|visa\\s+processing)",
		"\\bai\\b.*(?:asylum|migration|refugee)\\s+(?:application|claim|risk|decision)",
		"\\bai\\b.*(?:border\\s+control|customs|immigration\\s+(?:control|processing))",
		"\\bai\\b.*(?:travel\\s+document|residence\\s+permit)\\s+(?:verif|authent|decision)",
		"automated\\s+(?:visa|asylum|migration|border)\\s+(?:decision|processing|screening)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-7-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 7: Migration, asylum and border control management, in so far as their use is permitted under relevant Union or national law: (a) AI systems intended to be used by or on behalf of competent public authorities or by Union institutions, bodies, offices or agencies as polygraphs or similar tools; (b) AI systems intended to be used by or on behalf of competent public authorities or by Union institutions, bodies, offices or agencies to assess a risk, including a security risk, a risk of irregular migration, or a health risk, posed by a natural person who intends to enter or who has entered into the territory of a Member State; (c) AI systems intended to be used by or on behalf of competent public authorities or by Union institutions, bodies, offices or agencies to assist competent public authorities for the examination of applications for asylum, visa or residence permits and for associated complaints with regard to the eligibility of the natural persons applying for a status, including related assessments of the reliability of evidence; (d) AI systems intended to be used by or on behalf of competent public authorities, or by Union institutions, bodies, offices or agencies, in the context of migration, asylum or border control management, for the purpose of detecting, recognising or identifying natural persons, with the exception of the verification of travel documents."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Migration/asylum AI requires fundamental-rights impact assessment (Art 27), strict data governance (Art 10), human oversight (Art 14), and EU-database registration. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
