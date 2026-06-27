# ComplyEdge — EU AI Act Article 27: Fundamental Rights Impact Assessment
#
# Prior to deploying a high-risk AI system, certain deployers shall perform
# an assessment of the impact on fundamental rights that the use of such
# system may produce, covering affected persons, specific risks, human
# oversight measures, and remediation. Results shall be notified to the
# market surveillance authority.
#
# Legal citation: Regulation (EU) 2024/1689, Article 27, paragraph 1
# Recital: 73 — deployers must assess fundamental rights impact before high-risk AI deployment in Annex III areas
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article27.fria

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	fria_pattern_match
}

fria_pattern_match if {
	patterns := [
		"(?:without|no|skip(?:ping)?|omit(?:ting)?).*(?:fria|fundamental[\\- ]?rights?[\\- ]?(?:impact[\\- ]?)?assessment|impact[\\- ]?assessment).*(?:high[\\- ]?risk|deploy|annex[\\- ]?iii|before[\\- ]?deployment)?",
		"(?:deploy(?:ing)?|launch|roll[\\- ]?out).*(?:without|before|no).*(?:fria|fundamental[\\- ]?rights?[\\- ]?assessment|impact[\\- ]?assessment).*(?:high[\\- ]?risk|public[\\- ]?(?:body|service|entity))?",
		"(?:high[\\- ]?risk).*(?:deploy(?:ment)?).*(?:without|before|no).*(?:fria|fundamental[\\- ]?rights?[\\- ]?assessment|impact[\\- ]?assessment)",
		"(?:fundamental[\\- ]?rights?).*(?:not[\\- ]?(?:assessed|evaluated|considered|reviewed)).*(?:high[\\- ]?risk|deploy|impact|ai[\\- ]?system)?",
		"(?:public[\\- ]?(?:body|service|entity)|bodies[\\- ]?governed[\\- ]?by[\\- ]?public[\\- ]?law).*(?:without|lacking|no).*(?:fria|fundamental[\\- ]?rights?[\\- ]?assessment|impact[\\- ]?assessment)",
		"(?:fail(?:ing|ure)?[\\- ]?to|neglect(?:ed|ing)?[\\- ]?to).*(?:assess|evaluate).*(?:fundamental[\\- ]?rights?|impact).*(?:high[\\- ]?risk|deploy|ai[\\- ]?system)?",
		"(?:no|without).*(?:impact|rights?).*(?:assessment).*(?:before|prior[\\- ]?to).*(?:deploy|deployment|high[\\- ]?risk)",
		"(?:market[\\- ]?surveillance).*(?:not[\\- ]?notified|no[\\- ]?notification).*(?:fria|fundamental[\\- ]?rights?[\\- ]?assessment|impact[\\- ]?assessment|results)",
		"(?:article[\\- ]?27|art\\.?\\s*27).*(?:not[\\- ]?met|ignored|skipped|bypassed|omitted)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art27-1-001"

citation := "Regulation (EU) 2024/1689, Article 27, paragraph 1: Prior to deploying a high-risk AI system, deployers that are bodies governed by public law or private entities providing public services shall perform an assessment of the impact on fundamental rights that the use of such system may produce, and notify the market surveillance authority of its results."

severity := "high"

remediation := "Conduct a fundamental rights impact assessment before deployment covering deployment processes, period and frequency of use, categories of affected persons, specific risks of harm, human oversight measures, and remediation or complaint mechanisms; notify the market surveillance authority of the results."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
