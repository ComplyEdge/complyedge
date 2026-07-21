# ComplyEdge — Prompt-injection / IPI: Exfiltration — system-prompt leak
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_EXFIL_SYSTEM_PROMPT_LEAK_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.sysprompt_leak

import rego.v1

default violation := false

violation if regex.match(`(?i)\b(?:(?:reveal|print|repeat|show|display|output|tell\s+me|reproduce|echo|recite)\s+(?:me\s+)?(?:your\s+|the\s+|all\s+of\s+your\s+)?(?:system\s+prompt|initial\s+(?:instructions?|prompt)|(?:hidden|secret|original|confidential)\s+(?:instructions?|prompt|rules)|prompt\s+verbatim)|what\s+(?:are|were|is)\s+your\s+(?:exact\s+|full\s+|complete\s+)?(?:initial\s+|original\s+|system\s+|hidden\s+)(?:instructions?|prompt|rules|directives?))\b`, input.text)

rule_id := "rego-art15-ipi-005"

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
