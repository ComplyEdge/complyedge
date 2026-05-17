# ComplyEdge — EU AI Act Article 5(1)(h): Real-time Biometric Identification
#
# Prohibits the use of real-time remote biometric identification systems
# in publicly accessible spaces for law enforcement purposes, subject to
# narrowly defined exceptions.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(h)
# Recital: 32 — prohibits real-time remote biometric identification in publicly accessible spaces for law enforcement; recitals 33-35 cover the narrowly-defined exceptions (targeted search, imminent threat, serious crime) and the judicial/independent-authority authorisation requirement
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)

package complyedge.article5.realtime_biometric

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	realtime_biometric_pattern_match
}

realtime_biometric_pattern_match if {
	patterns := [
		"real[\\- ]?time[\\- ]?biometric",
		"live[\\- ]?facial[\\- ]?recognition",
		"mass[\\- ]?facial[\\- ]?recognition",
		"public[\\- ]?space[\\- ]?biometric",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1h-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(h): Prohibits the use of real-time remote biometric identification systems in publicly accessible spaces for law enforcement purposes, except in narrowly defined circumstances."

severity := "critical"

remediation := "Remove real-time remote biometric identification from publicly accessible spaces. If deployment falls under a narrow exception (e.g., targeted search for missing persons), obtain prior judicial authorisation and document the lawful basis."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
