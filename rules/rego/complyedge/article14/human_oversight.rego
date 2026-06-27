# ComplyEdge — EU AI Act Article 14: Human Oversight for High-Risk AI
#
# High-risk AI systems shall be designed and developed with appropriate
# human-machine interface tools so they can be effectively overseen by natural
# persons during use. Oversight must enable understanding, monitoring,
# correct interpretation of output, decision to override, and intervention
# or interruption of operation.
#
# Legal citation: Regulation (EU) 2024/1689, Article 14, paragraph 1
# Recital: 70 — high-risk AI must enable effective human oversight including monitor, override, and interrupt capabilities
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article14.human_oversight

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	human_oversight_pattern_match
}

human_oversight_pattern_match if {
	patterns := [
		"(?:without|no|missing|skip|omit).*(?:human[\\- ]?oversight|human[\\- ]?(?:supervision|review|intervention|control))",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|lacking).*(?:human[\\- ]?oversight|human[\\- ]?in[\\- ]?the[\\- ]?loop|supervision)",
		"(?:fully[\\- ]?autonomous|unsupervised).*(?:high[\\- ]?risk|ai[\\- ]?system|decision|operation|deployment).*(?:without|lacking|no).*(?:human|oversight|supervision)",
		"(?:high[\\- ]?risk).*(?:fully[\\- ]?autonomous|unsupervised).*(?:without|lacking|no).*(?:human|oversight)",
		"(?:no|without|missing).*(?:stop[\\- ]?button|kill[\\- ]?switch|override[\\- ]?mechanism|intervention[\\- ]?capability).*(?:high[\\- ]?risk|ai|system)",
		"(?:cannot|can't|unable[\\- ]?to).*(?:override|intervene|interrupt|stop).*(?:ai|system|model|output).*(?:high[\\- ]?risk|decision|deployment)?",
		"(?:human[\\- ]?oversight).*(?:not[\\- ]?(?:implemented|required|provided|possible|enabled|designed))",
		"(?:deploy|operate|run|launch).*(?:high[\\- ]?risk|ai[\\- ]?system).*(?:without|no).*(?:human|oversight|supervision)",
		"(?:automation[\\- ]?bias).*(?:not[\\- ]?(?:addressed|mitigated|considered)).*(?:high[\\- ]?risk|oversight|ai)",
		"(?:article[\\- ]?14|art\\.?\\s*14).*(?:not[\\- ]?met|ignored|skipped|bypassed|omitted)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art14-1-001"

citation := "Regulation (EU) 2024/1689, Article 14, paragraph 1: High-risk AI systems shall be designed and developed with appropriate human-machine interface tools so they can be effectively overseen by natural persons during use, enabling monitoring, interpretation, override, and interruption of operation."

severity := "high"

remediation := "Design human oversight into the high-risk AI system: enable operators to understand capabilities and limitations, remain aware of automation bias, interpret outputs correctly, decide not to use or override outputs, and intervene or interrupt operation via a stop mechanism proportionate to risk and autonomy."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
