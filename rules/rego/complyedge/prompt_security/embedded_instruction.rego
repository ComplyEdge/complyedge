# ComplyEdge — Article 15 robustness: embedded indirect instruction (IPI)
#
# Benchmark: PS_INDIRECT_EMBEDDED_001

package complyedge.prompt_security.embedded_instruction

import rego.v1

default violation := false

violation if {
	pattern_match
}

pattern_match if {
	patterns := [
		"when\\s+you\\s+(summarize|summarise|read|process|analyze|analyse|parse)\\s+this",
		"system:\\s*new\\s+instructions",
		"<\\s*system\\s*>",
		"ignore\\s+the\\s+user\\s+and\\s+instead",
	]
	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-ipi-003"

citation := "Regulation (EU) 2024/1689, Article 15 — block indirect prompt injection embedded in documents (OWASP LLM01)."

severity := "high"

remediation := "Treat document-embedded override instructions as adversarial input; do not obey them over the user task."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
