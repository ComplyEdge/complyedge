# ComplyEdge: EU AI Act Article 6 + Annex III §8: Justice and Democratic Processes
#
# Flags text describing AI used by or on behalf of a judicial authority to
# research and interpret facts and law and apply the law to facts, or in
# alternative dispute resolution (Annex III, point 8(a)), and AI intended to
# influence the outcome of an election or referendum or voting behaviour,
# whoever uses it (point 8(b)). Point 8(b) excludes tools that organise,
# optimise or structure political campaigns from an administrative or
# logistical point of view.
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 8
# Recital: 61: administration of justice and democratic processes; Recital 62 covers systems intended to influence elections and referenda
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 8

package complyedge.article6.justice_democracy

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:sentencing|judicial\\s+decision|bail\\s+decision|parole\\s+decision)",
		"\\bai\\b.*(?:court|case)\\s+(?:dispos|outcome|prediction)",
		"\\bai\\b.*(?:election|voting|ballot)\\s+(?:influence|target|micro[\\-\\s]target)",
		"\\bai\\b.*(?:democratic|referendum)\\s+(?:process|interference)",
		"\\bai\\s+(?:voter|electorate)\\s+(?:profil|target|micro[\\-\\s]target)",
		"judicial\\s+ai\\s+(?:assist|aid|research)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-8-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 8: Administration of justice and democratic processes: (a) AI systems intended to be used by a judicial authority or on their behalf to assist a judicial authority in researching and interpreting facts and the law and in applying the law to a concrete set of facts, or to be used in a similar way in alternative dispute resolution; (b) AI systems intended to be used for influencing the outcome of an election or referendum or the voting behaviour of natural persons in the exercise of their vote in elections or referenda. This does not include AI systems to the output of which natural persons are not directly exposed, such as tools used to organise, optimise or structure political campaigns from an administrative or logistical point of view."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Justice/democracy AI requires fundamental-rights impact assessment (Art 27), transparency, human oversight (Art 14), and EU-database registration. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
