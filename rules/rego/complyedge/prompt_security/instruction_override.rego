# ComplyEdge — Prompt-injection / IPI: Direct injection — instruction override
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_DIRECT_INJECTION_OVERRIDE_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.instruction_override

import rego.v1

default violation := false

violation if regex.match(`(?i)\b(?:ignore|disregard|forget|override|bypass)\b\s+(?:the\s+|all\s+|any\s+|your\s+|previous\s+|prior\s+|above\s+|earlier\s+|preceding\s+|system\s+|original\s+|initial\s+)+(?:instructions?|prompts?|directives?|rules?|constraints?|guidelines?|system\s+prompt|safety\s+(?:rules?|guidelines?))\b`, input.text)

rule_id := "rego-art15-ipi-009"

citation := "Regulation (EU) 2024/1689, Article 15(5): high-risk AI systems must be resilient against attempts by unauthorised third parties to alter their use or behaviour by exploiting vulnerabilities — indirect/direct prompt injection (IPI). See docs/security-compliance/ipi-conformity-assessment.md."

severity := "high"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
