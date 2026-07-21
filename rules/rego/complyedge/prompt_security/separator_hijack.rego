# ComplyEdge — Prompt-injection / IPI: Indirect injection — separator/context hijack
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_INDIRECT_INJECTION_SEPARATOR_HIJACK_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.separator_hijack

import rego.v1

default violation := false

violation if regex.match(`(?im)^\s*(?:={3,}|-{3,}|\*{3,}|#{2,}|\[/?(?:user|assistant|system|context|input|prompt)\]|</?(?:user|assistant|system|context|input|prompt)>)\s*(?:end[_\s-]?(?:of[_\s-]?)?(?:user[_\s-]?)?(?:input|prompt|context|message)|new[_\s-]?(?:instructions?|prompt|system[_\s-]?(?:prompt|message))|begin[_\s-]?(?:new|system|assistant)|system[_\s-]?(?:override|prompt)|admin[_\s-]?override|important[_\s-]?(?:instructions?|note))\s*(?:={3,}|-{3,}|\*{3,}|#{2,}|\[/?(?:user|assistant|system|context|input|prompt)\]|</?(?:user|assistant|system|context|input|prompt)>)?`, input.text)

rule_id := "rego-art15-ipi-008"

citation := "Regulation (EU) 2024/1689, Article 15(5): high-risk AI systems must be resilient against attempts by unauthorised third parties to alter their use or behaviour by exploiting vulnerabilities — indirect/direct prompt injection (IPI). See docs/security-compliance/ipi-conformity-assessment.md."

severity := "medium"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
