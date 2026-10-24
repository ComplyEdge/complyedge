# ComplyEdge: EU AI Act Article 6 + Annex III §5: Access to Essential Services
#
# Flags text describing AI used for access to essential private and public
# services (Annex III, point 5). Point 5(a) covers only systems used by or on
# behalf of public authorities for public assistance benefits; point 5(b)
# excludes systems used to detect financial fraud; point 5(c) covers only risk
# assessment and pricing for natural persons in life and health insurance;
# point 5(d) covers emergency call evaluation, dispatch and patient triage.
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 5
# Recital: 58: access to and enjoyment of essential private and public services and benefits, including credit scoring, life and health insurance and emergency dispatch
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 5

package complyedge.article6.essential_services

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:credit\\s+scor|creditworthiness|loan\\s+approv|loan\\s+decision)",
		"\\bai\\b.*(?:insurance\\s+pricing|insurance\\s+risk\\s+assess|underwrit)",
		"\\bai\\b.*(?:welfare|social\\s+benefit|benefits?\\s+eligibility)",
		"\\bai\\b.*(?:emergency\\s+(?:response|dispatch|services?)\\s+(?:routing|triage))",
		"automated\\s+(?:credit|loan|insurance)\\s+(?:decision|approv|underwrit)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-5-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 5: Access to and enjoyment of essential private services and essential public services and benefits: (a) AI systems intended to be used by public authorities or on behalf of public authorities to evaluate the eligibility of natural persons for essential public assistance benefits and services, including healthcare services, as well as to grant, reduce, revoke, or reclaim such benefits and services; (b) AI systems intended to be used to evaluate the creditworthiness of natural persons or establish their credit score, with the exception of AI systems used for the purpose of detecting financial fraud; (c) AI systems intended to be used for risk assessment and pricing in relation to natural persons in the case of life and health insurance; (d) AI systems intended to evaluate and classify emergency calls by natural persons or to be used to dispatch, or to establish priority in the dispatching of, emergency first response services, including by police, firefighters and medical aid, as well as of emergency healthcare patient triage systems."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Essential-services AI requires bias and fairness testing, human oversight (Art 14), explainability to affected persons, and post-market monitoring. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
