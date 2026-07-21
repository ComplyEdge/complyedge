# ComplyEdge — Prompt-injection / IPI: Indirect injection — embedded instruction
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_INDIRECT_INJECTION_EMBEDDED_INSTRUCTION_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.indirect_embedded

import rego.v1

default violation := false

violation if regex.match(`(?i)(?:when\s+(?:you|the\s+(?:ai|assistant|model|llm))\s+(?:read|process|summari[sz]e|analy[sz]e|parse)s?\s+this\b.{0,60}?\b(?:ignore|instead|you\s+must|do\s+not|disregard)|(?:^|\n)\s*(?:#{1,3}\s*)?(?:system|assistant)\s+(?:message|prompt|instruction|note)\s*[:>]|<\s*(?:system|important_instructions?)\s*>)`, input.text)

rule_id := "rego-art15-ipi-003"

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
