# ComplyEdge — EU AI Act Article 12: Record-Keeping for High-Risk AI
#
# High-risk AI systems shall technically allow for the automatic recording
# of events (logs) over the lifetime of the system. Logging capabilities
# shall enable traceability appropriate to the intended purpose, including
# identifying risk situations, post-market monitoring, and deployer
# operational monitoring.
#
# Legal citation: Regulation (EU) 2024/1689, Article 12, paragraph 1
# Recital: 68 — high-risk AI must enable automatic event logging and traceability over the system lifetime
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Card checklist mentions "180-day retention"; that obligation is
# Art 26(5) deployer log retention (separate article26 rule). Art 12(1)
# requires automatic event logging over the system lifetime.

package complyedge.article12.record_keeping

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	record_keeping_pattern_match
}

record_keeping_pattern_match if {
	patterns := [
		"(?:no|without|disable|disabled|bypass|skip|turn[\\- ]?off).*(?:logging|logs|event[\\- ]?log|audit[\\- ]?log|record[\\- ]?keeping).*(?:high[\\- ]?risk|ai[\\- ]?system|biometric)",
		"(?:high[\\- ]?risk|ai[\\- ]?system|biometric[\\- ]?system).*(?:without|lacking|no).*(?:automatic[\\- ]?)?(?:logging|logs|event[\\- ]?recording|traceability|audit[\\- ]?trail)",
		"(?:deploy|operate|run|launch).*(?:high[\\- ]?risk|biometric[\\- ]?system).*(?:without|lacking|no).*(?:logs|logging|traceability|audit[\\- ]?trail|record[\\- ]?keeping)",
		"(?:traceability|audit[\\- ]?trail|event[\\- ]?log).*(?:not[\\- ]?(?:provided|implemented|enabled|recorded)|disabled|removed|turned[\\- ]?off)",
		"(?:article[\\- ]?12|art\\.?\\s*12|record[\\- ]?keeping).*(?:not[\\- ]?met|ignored|skipped|bypassed|omitted)",
		"(?:skip|omit|bypass).*(?:record[\\- ]?keeping|automatic[\\- ]?logging|event[\\- ]?logs).*(?:high[\\- ]?risk|ai[\\- ]?system)",
		"(?:high[\\- ]?risk).*(?:ai|system).*(?:no[\\- ]?log|unlogged|not[\\- ]?logged|without[\\- ]?traceability)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art12-1-001"

citation := "Regulation (EU) 2024/1689, Article 12, paragraph 1: High-risk AI systems shall technically allow for the automatic recording of events (logs) over the lifetime of the system, with logging capabilities enabling traceability appropriate to the intended purpose."

severity := "high"

remediation := "Implement automatic event logging over the full lifetime of the high-risk AI system. Ensure logs support traceability for risk identification, post-market monitoring (Art 72), and deployer operational monitoring (Art 26(5)); for Annex III biometric systems, record period of use, reference database, matched input data, and verifying persons."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
