# ComplyEdge: EU AI Act Article 6 + Annex III §4: Employment, Workers, Self-Employed
#
# Flags text describing AI used in recruitment, candidate screening, employment
# evaluation, performance monitoring, task allocation, promotion and
# termination decisions (Annex III, points 4(a) and 4(b)).
#
# A match marks a use case that Article 6(2) and Annex III classify as high-risk.
# Classification is not a breach: an Annex III system is lawful when its provider
# and deployer meet Chapter III. The condition does not read the Article 6(3)
# derogation, the Article 6(4) assessment or the 2027-12-02 date.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 4
# Recital: 57: AI systems in recruitment and selection, in decisions on work-related relationships, task allocation and the monitoring and evaluation of workers
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 99(4): up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)
# ELI: http://data.europa.eu/eli/reg/2024/1689/anx_iii/oj
# Provision: Regulation (EU) 2024/1689, Article 6(2) and Annex III, point 4

package complyedge.article6.employment_workers

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\bai\\b.*(?:recruitment|hiring|cv\\s+screening|resume\\s+screening|candidate\\s+screening)",
		"\\bai\\b.*(?:performance\\s+evaluation|employee\\s+monitoring|promotion\\s+decision)",
		"\\bai\\b.*(?:termination|firing|task\\s+allocation|worker\\s+monitoring)",
		"hiring\\s+ai|\\bai\\s+hir(?:ing|e)",
		"applicant\\s+(?:scoring|ranking|filter)\\s+(?:\\bai|ml|system)",
		"workforce\\s+(?:analytics|optimization)\\s+(?:\\bai|ml)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-4-001"

citation := "Regulation (EU) 2024/1689, Article 6(2): In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk. Annex III, point 4: Employment, workers' management and access to self-employment: (a) AI systems intended to be used for the recruitment or selection of natural persons, in particular to place targeted job advertisements, to analyse and filter job applications, and to evaluate candidates; (b) AI systems intended to be used to make decisions affecting terms of work-related relationships, the promotion or termination of work-related contractual relationships, to allocate tasks based on individual behaviour or personal traits or characteristics or to monitor and evaluate the performance and behaviour of persons in such relationships."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Employment-decision AI requires bias testing, human oversight (Art 14), transparency to candidates/workers, and post-market monitoring. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
