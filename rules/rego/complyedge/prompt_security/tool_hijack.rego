# ComplyEdge — Prompt-injection / IPI: Tool-call hijack / exfiltration
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_TOOL_CALL_HIJACK_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.tool_hijack

import rego.v1

default violation := false

violation if regex.match(`(?i)(?:\b(?:forward|send|post|transmit|exfiltrate|leak|upload|email)\b[^.!?\n]{0,90}?\b(?:system\s+prompt|credentials?|api\s+keys?|secrets?|conversation|chat\s+history|password|the\s+above)\b[^.!?\n]{0,90}?\bto\s+(?:https?://|\S+@)|(?:make|issue|perform|execute)\s+an?\s+(?:http|https|get|post|curl|fetch)\s+request\s+to\s+https?://|(?:call|invoke|use|execute)\s+(?:the\s+)?\w+\s+(?:tool|function|api)\s+(?:to\s+(?:send|forward|exfiltrate|leak|delete|transfer)|with\s+(?:my|the\s+user'?s)\s+(?:credentials?|secrets?)))`, input.text)

rule_id := "rego-art15-ipi-010"

citation := "Regulation (EU) 2024/1689, Article 15(5): high-risk AI systems must be resilient against attempts by unauthorised third parties to alter their use or behaviour by exploiting vulnerabilities — indirect/direct prompt injection (IPI). See docs/security-compliance/ipi-conformity-assessment.md."

severity := "critical"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
