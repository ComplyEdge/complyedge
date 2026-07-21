# ComplyEdge — Article 15 robustness: labeled indirect injection / instruction override (IPI)
#
# Benchmark: PS_INDIRECT_INJECTION_002
# Also covers the classic "ignore previous instructions" shape.

package complyedge.prompt_security.indirect_injection

import rego.v1

default violation := false

violation if {
	pattern_match
}

pattern_match if {
	patterns := [
		"indirect\\s+prompt\\s+injection",
		"(ignore|disregard|forget|override|bypass)\\s+(the\\s+|all\\s+|any\\s+|your\\s+|previous\\s+|prior\\s+|above\\s+)+(instructions?|prompts?|directives?|rules?|constraints?|guidelines?|system\\s+prompt)",
		"unrestricted\\s+assistant\\s+with\\s+no\\s+guidelines",
		"act\\s+as\\s+an\\s+unrestricted\\s+assistant",
	]
	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-ipi-008"

citation := "Regulation (EU) 2024/1689, Article 15 — block indirect prompt injection and instruction-override jailbreaks (OWASP LLM01)."

severity := "high"

remediation := "Refuse instruction-override and unrestricted-assistant jailbreaks, including labeled indirect injections."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
