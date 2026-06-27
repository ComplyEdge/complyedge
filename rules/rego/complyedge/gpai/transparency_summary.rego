# ComplyEdge — EU AI Act Article 52: GPAI Systemic-Risk Notification Procedure
#
# Where a general-purpose AI model meets the condition in Article 51(1)(a),
# the provider shall notify the Commission without delay and in any event
# within two weeks. The notification must include information necessary to
# demonstrate that the requirement has been met. Providers may submit
# substantiated arguments that the model should not be classified as having
# systemic risk despite meeting the threshold.
#
# Legal citation: Regulation (EU) 2024/1689, Article 52, paragraph 1
# Recital: 112 — providers must notify the Commission when a GPAI model meets the Art 51(1)(a) systemic-risk threshold; the Commission may designate models ex officio if not notified
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue (via Art 101 for GPAI provider obligations)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Art 52 is the Commission notification procedure — not a training
# content summary (that is Art 53(1)(d) public summary or Art 53(1)(b) Annex
# XII downstream documentation). Card item label corrected. rule_id rego-gpai-52-001
# maps to Article 52. Art 51 classification is enforced separately in
# model_classification.rego.

package complyedge.gpai.transparency_summary

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	transparency_summary_pattern_match
}

transparency_summary_pattern_match if {
	patterns := [
		"(?:no|without|fail(?:ed|ing|s)?|never).*(?:notif|inform).*(?:commission|ai office|european commission)",
		"(?:skip|omit|bypass).*(?:art(?:icle)?[\\- ]?52|commission[\\- ]?notif|ai office notif)",
		"(?:gpai|general[\\- ]?purpose|foundation[\\- ]?model|frontier[\\- ]?model).*(?:without|no|before).*(?:notif|inform).*(?:commission|ai office)",
		"(?:release|launch|deploy|place).*(?:gpai|foundation|frontier).*(?:without|before).*(?:commission|ai office).*(?:notif|inform)",
		"(?:10\\^25|10\\*{25}|systemic[\\- ]?risk|high[\\- ]?impact).*(?:without|no).*(?:notif|inform).*(?:commission|ai office)",
		"(?:notif|inform).*(?:commission|ai office).*(?:within|after).*(?:more than|over|beyond).*(?:two|2)[\\- ]?weeks",
		"(?:cross|exceed|meet).*(?:51|threshold|10\\^25).*(?:without|no).*(?:commission|ai office).*(?:notif|inform)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-52-001"

citation := "Regulation (EU) 2024/1689, Article 52, paragraph 1: Where a general-purpose AI model meets the condition referred to in Article 51(1), point (a), the relevant provider shall notify the Commission without delay and in any event within two weeks after that requirement is met or it becomes known that it will be met."

severity := "high"

remediation := "Notify the European Commission without delay and within two weeks when the GPAI model meets the Article 51(1)(a) systemic-risk threshold. Include information demonstrating that the requirement has been met. If arguing the model should not be classified as systemic risk, submit sufficiently substantiated arguments with the notification."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
