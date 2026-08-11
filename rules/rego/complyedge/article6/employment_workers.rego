# ComplyEdge — EU AI Act Article 6 + Annex III §4: Employment, Workers, Self-Employed
#
# Classifies AI systems used in recruitment, candidate screening, employment
# evaluation, performance monitoring, task allocation, promotion, and
# termination decisions as high-risk under Annex III §4.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(4)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)

package complyedge.article6.employment_workers

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:recruitment|hiring|cv\\s+screening|resume\\s+screening|candidate\\s+screening)",
		"ai.*(?:performance\\s+evaluation|employee\\s+monitoring|promotion\\s+decision)",
		"ai.*(?:termination|firing|task\\s+allocation|worker\\s+monitoring)",
		"hiring\\s+ai|ai\\s+hir(?:ing|e)",
		"applicant\\s+(?:scoring|ranking|filter)\\s+(?:ai|ml|system)",
		"workforce\\s+(?:analytics|optimization)\\s+(?:ai|ml)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-4-001"

citation := "Regulation (EU) 2024/1689, Article 6: AI systems referred to in Annex III shall be considered to be high-risk. An AI system referred to in Annex III shall always be considered to be high-risk where the AI system performs profiling of natural persons. A provider who considers that an AI system referred to in Annex III is not high-risk shall document its assessment before that system is placed on the market or put into service."
severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Employment-decision AI requires bias testing, human oversight (Art 14), transparency to candidates/workers, and post-market monitoring."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
