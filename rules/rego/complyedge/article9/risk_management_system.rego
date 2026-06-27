# ComplyEdge — EU AI Act Article 9: Risk Management System
#
# A risk management system shall be established, implemented, documented and
# maintained in relation to high-risk AI systems. The risk management system
# shall be a continuous iterative process planned and run throughout the entire
# lifecycle of a high-risk AI system, requiring regular systematic review and
# updating — including identification, estimation, evaluation, and mitigation
# of risks to health, safety, or fundamental rights.
#
# Legal citation: Regulation (EU) 2024/1689, Article 9, paragraph 1
# Recital: 65 — high-risk AI providers must establish a continuous iterative risk management process throughout the system lifecycle, with regular review and updating
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article9.risk_management_system

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	risk_management_system_pattern_match
}

risk_management_system_pattern_match if {
	patterns := [
		"(?:without|no|skip|omit|bypass).*(?:risk[\\- ]?management|risk[\\- ]?assessment)",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:without|no|skip).*(?:risk[\\- ]?management|risk[\\- ]?assessment|lifecycle[\\- ]?risk)",
		"(?:deploy|release|launch|place).*(?:high[\\- ]?risk).*(?:without|before).*(?:risk[\\- ]?management|risk[\\- ]?assessment)",
		"(?:risk[\\- ]?management).*(?:not[\\- ]?(?:required|needed|implemented|documented|maintained))",
		"(?:no|without).*(?:continuous|iterative).*(?:risk[\\- ]?management|risk[\\- ]?process|lifecycle[\\- ]?risk)",
		"(?:residual[\\- ]?risk).*(?:not[\\- ]?(?:assessed|evaluated|acceptable|mitigated))",
		"(?:unmitigated|unmanaged).*(?:risk|hazard)",
		"(?:risk|hazard).*(?:unmitigated|unmanaged)",
		"(?:risk[\\- ]?(?:identification|evaluation)).*(?:not[\\- ]?(?:performed|conducted|documented))",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art9-1-001"

citation := "Regulation (EU) 2024/1689, Article 9, paragraph 1: A risk management system shall be established, implemented, documented and maintained in relation to high-risk AI systems, as a continuous iterative process throughout the entire lifecycle of the system, requiring regular systematic review and updating."

severity := "high"

remediation := "Establish, implement, document, and maintain a continuous risk management system for the high-risk AI system. Identify and analyse known and reasonably foreseeable risks, estimate and evaluate risks under intended use and foreseeable misuse, evaluate post-market risks, and adopt targeted mitigation measures with acceptable residual risk."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
