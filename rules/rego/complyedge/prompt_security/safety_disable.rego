# ComplyEdge — Prompt-injection / IPI: Direct injection — safety-filter disable
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_DIRECT_INJECTION_SAFETY_DISABLE_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.safety_disable

import rego.v1

default violation := false

violation if regex.match(`(?i)\b(?:disable|turn\s+off|deactivate|switch\s+off|remove|bypass|circumvent|ignore)\s+(?:your\s+|all\s+|any\s+|the\s+|every\s+)*(?:safety\s+(?:filters?|guidelines?|guardrails?|protocols?|checks?)|content\s+(?:policy|policies|filters?|moderation)|(?:ethical|moral)\s+(?:guidelines?|constraints?)|guardrails?|restrictions?|safeguards?)\b`, input.text)

rule_id := "rego-art15-ipi-002"

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
