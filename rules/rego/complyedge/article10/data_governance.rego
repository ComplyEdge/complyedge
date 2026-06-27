# ComplyEdge — EU AI Act Article 10: Data Governance for High-Risk AI
#
# Training, validation and testing data sets shall be subject to appropriate
# data governance and management practices. They shall be relevant, sufficiently
# representative, and to the best extent possible free of errors and complete
# in view of the intended purpose. Possible biases likely to affect health,
# safety, or fundamental rights shall be examined and gaps or shortcomings
# addressed.
#
# Legal citation: Regulation (EU) 2024/1689, Article 10, paragraph 2
# Recital: 66 — high-risk AI training data must meet quality and governance standards; datasets must be examined for biases affecting fundamental rights
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article10.data_governance

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	data_governance_pattern_match
}

data_governance_pattern_match if {
	patterns := [
		"(?:training|validation|test(?:ing)?)[\\- ]?data.*(?:not[\\- ]?)?(?:representative|biased|incomplete|unvetted|unexamined)",
		"(?:biased|unrepresentative|incomplete).*(?:training|validation|test(?:ing)?).*(?:data|dataset|data[\\- ]?set)",
		"(?:without|no|skip|omit).*(?:data[\\- ]?governance|bias[\\- ]?(?:check|assessment|audit|review|detection))",
		"(?:data[\\- ]?governance).*(?:not[\\- ]?(?:implemented|required|performed|documented))",
		"(?:skip|omit|bypass).*(?:data|bias).*(?:review|assessment|validation|audit)",
		"(?:dataset|training[\\- ]?data).*(?:bias|quality).*(?:not[\\- ]?(?:assessed|checked|verified|examined))",
		"(?:training|deploy).*(?:without|no).*(?:representative|validated|governed).*(?:data|dataset)",
		"(?:insufficient|inadequate).*(?:training|test(?:ing)?|validation).*(?:data|dataset).*(?:high[\\- ]?risk|bias|governance)",
		"(?:high[\\- ]?risk).*(?:without|no).*(?:data[\\- ]?governance|bias[\\- ]?examination)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art10-2-001"

citation := "Regulation (EU) 2024/1689, Article 10, paragraph 2: Training, validation and testing data sets for high-risk AI systems shall be subject to appropriate data governance practices, be relevant and sufficiently representative, be to the best extent possible free of errors and complete, and be examined for possible biases likely to affect health, safety, or fundamental rights."

severity := "high"

remediation := "Implement data governance for training, validation, and testing datasets. Ensure data is relevant, representative, and complete for the intended purpose; examine for biases affecting fundamental rights; detect and address gaps or shortcomings; document the governance process."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
