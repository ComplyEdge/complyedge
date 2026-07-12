# ComplyEdge — EU AI Act Article 6(3): Narrow Procedural-Task Derogation
#
# An Annex III system is not high-risk where it performs a narrow procedural
# task, improves a previously completed human activity, detects decision
# patterns without replacing human assessment, or performs a preparatory task.
# Claiming the derogation while describing substantive automated decisioning
# (replacing human assessment on credit, hiring, benefits, etc.) is a
# misclassification risk.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(3)
# Recital: 53 — high-risk classification should not capture systems that only
#   perform narrow procedural or preparatory tasks
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue (misclassification / Art 6 duties)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-11 (via agent review per RULE_STANDARD §5.1; card M3.3-T3)

package complyedge.article6.art6_3_procedural_derogation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:not\\s+high[\\- ]?risk|6\\(3\\)|narrow\\s+procedural).*(?:replac\\w*\\s+human|automat\\w*\\s+(?:credit|loan|hiring|recruit|welfare|benefit|insurance)\\s+decision)",
		"(?:claim|assert|invoke).*(?:6\\(3\\)|narrow\\s+procedural\\s+task|preparatory\\s+task).*(?:without\\s+human\\s+(?:oversight|review|assessment)|fully\\s+automat)",
		"derogat\\w*.*annex\\s*iii.*(?:credit\\s+scor|creditworthiness|hiring\\s+decision|insurance\\s+pricing)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-3-001"

citation := "Regulation (EU) 2024/1689, Article 6(3): An Annex III AI system is not high-risk where it only performs a narrow procedural or preparatory task and does not replace human assessment."

severity := "high"

remediation := "Do not claim the Article 6(3) derogation for systems that replace or substantially automate human assessment in Annex III domains. Document why the task is narrow/procedural if relying on the carve-out."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
