# ComplyEdge — EU AI Act Article 26: Deployer Obligations for High-Risk AI
#
# Deployers of high-risk AI systems shall take appropriate technical and
# organisational measures to use systems in accordance with instructions for
# use, assign competent human oversight, ensure relevant representative input
# data, monitor operation, retain automatically generated logs for at least
# six months, and cooperate with competent authorities.
#
# Legal citation: Regulation (EU) 2024/1689, Article 26, paragraph 1
# Recital: 72 — deployers must use high-risk AI per instructions with oversight, monitoring, and log retention
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Six-month log retention is Art 26(6); patterns also cover
# monitoring, oversight assignment, and instructions-for-use compliance.

package complyedge.article26.deployer_obligations

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	deployer_obligations_pattern_match
}

deployer_obligations_pattern_match if {
	patterns := [
		"(?:deploy(?:ing|er)?|operat(?:e|ing)).*(?:without|no|ignor(?:e|ing)).*(?:instructions?[\\- ]?for[\\- ]?use|deployer[\\- ]?obligations?|compliance)",
		"(?:high[\\- ]?risk).*(?:deploy(?:er|ment)?).*(?:without|no|ignor(?:e|ing)).*(?:instructions?[\\- ]?for[\\- ]?use|oversight|monitoring|logs)",
		"(?:no|without|fail(?:ing|ure)?[\\- ]?to).*(?:log[\\- ]?retention|keep[\\- ]?logs|automatic[\\- ]?log).*(?:six[\\- ]?months?|6[\\- ]?months?|deployer|high[\\- ]?risk)?",
		"(?:logs?).*(?:not[\\- ]?kept|deleted|discarded).*(?:six[\\- ]?months?|6[\\- ]?months?|deployer|high[\\- ]?risk)",
		"(?:fail(?:ing|ure)?[\\- ]?to|without|no).*(?:monitor|assign[\\- ]?human[\\- ]?oversight|inform[\\- ]?(?:workers?|provider|authority|affected)).*(?:high[\\- ]?risk|deployer|ai[\\- ]?system)",
		"(?:without|no).*(?:competent|trained).*(?:oversight|personnel|supervision).*(?:deployer|high[\\- ]?risk|ai[\\- ]?system)",
		"(?:input[\\- ]?data).*(?:not[\\- ]?(?:representative|relevant|validated)).*(?:high[\\- ]?risk|deployer|intended[\\- ]?purpose)",
		"(?:deploy(?:ing|er)?).*(?:without|no).*(?:oversight|monitoring|logs|instructions?|notification).*(?:high[\\- ]?risk|ai|workplace)?",
		"(?:article[\\- ]?26|art\\.?\\s*26).*(?:not[\\- ]?met|ignored|skipped|bypassed|omitted)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art26-1-001"

citation := "Regulation (EU) 2024/1689, Article 26, paragraph 1: Deployers of high-risk AI systems shall take appropriate technical and organisational measures to ensure they use such systems in accordance with the instructions for use, including competent human oversight, operation monitoring, representative input data, and retention of automatically generated logs for at least six months."

severity := "high"

remediation := "Use the high-risk AI system per instructions for use; assign human oversight to competent trained personnel; ensure input data is relevant and representative; monitor operation and report risks or incidents; retain automatically generated logs for at least six months; inform workers and affected persons; cooperate with competent authorities."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
