# ComplyEdge: EU AI Act Article 6 + Annex III §6: Law Enforcement
#
# Flags text describing AI used by or on behalf of law enforcement authorities
# (Annex III, point 6): assessing the risk of a person becoming a victim (6(a)),
# polygraphs and similar tools (6(b)), evaluating the reliability of evidence
# (6(c)), assessing the risk of offending not solely on profiling (6(d)), and
# profiling in the detection, investigation or prosecution of offences (6(e)).
# Risk assessments based solely on profiling are prohibited by Article 5(1)(d).
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 6
# Recital: 59: law enforcement uses of AI that involve a significant power imbalance and can lead to surveillance, arrest or deprivation of liberty
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 6

package complyedge.article6.law_enforcement

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:predictive\\s+polic|crime\\s+predict|recidivism\\s+predict)",
		"\\bai\\b.*(?:suspect\\s+identif|profile\\s+suspect|lie\\s+detect|polygraph)",
		"\\bai\\b.*(?:evidence\\s+assess|reliab.*evidence)",
		"law\\s+enforcement\\s+ai",
		"\\bai\\s+(?:assist|aid).*(?:investig|prosecut)",
		"crime\\s+analytics\\s+(?:\\bai|ml|model)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-6-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 6: Law enforcement, in so far as their use is permitted under relevant Union or national law: (a) AI systems intended to be used by or on behalf of law enforcement authorities, or by Union institutions, bodies, offices or agencies in support of law enforcement authorities or on their behalf to assess the risk of a natural person becoming the victim of criminal offences; (b) AI systems intended to be used by or on behalf of law enforcement authorities or by Union institutions, bodies, offices or agencies in support of law enforcement authorities as polygraphs or similar tools; (c) AI systems intended to be used by or on behalf of law enforcement authorities, or by Union institutions, bodies, offices or agencies, in support of law enforcement authorities to evaluate the reliability of evidence in the course of the investigation or prosecution of criminal offences; (d) AI systems intended to be used by law enforcement authorities or on their behalf or by Union institutions, bodies, offices or agencies in support of law enforcement authorities for assessing the risk of a natural person offending or re-offending not solely on the basis of the profiling of natural persons as referred to in Article 3(4) of Directive (EU) 2016/680, or to assess personality traits and characteristics or past criminal behaviour of natural persons or groups; (e) AI systems intended to be used by or on behalf of law enforcement authorities or by Union institutions, bodies, offices or agencies in support of law enforcement authorities for the profiling of natural persons as referred to in Article 3(4) of Directive (EU) 2016/680 in the course of the detection, investigation or prosecution of criminal offences."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Law-enforcement AI requires fundamental-rights impact assessment (Art 27), human oversight, data quality controls (Art 10), and registration in the EU database. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
