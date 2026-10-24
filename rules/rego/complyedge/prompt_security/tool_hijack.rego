# ComplyEdge: Prompt-injection / IPI: Tool-call hijack / exfiltration
#
# Text that tries to make an AI call a tool (http, email, file, payment) to
# send data out or take an action its user did not ask for.
#
# Layer 1 detects: in any letter case, forward, send, post, transmit,
# exfiltrate, leak, upload or email, then within 90 characters (no ".", "!",
# "?" or line break between) "system prompt", credential(s), "API key(s)",
# secret(s), conversation, "chat history", password or "the above", then
# within 90 more such characters "to" followed by an http or https URL or by
# an address containing "@"; make, issue, perform or execute "a" or "an" HTTP,
# HTTPS, GET, POST, curl or fetch "request to" an http or https URL; and call,
# invoke, use or execute (optionally "the") one word followed by tool,
# function or API, then "to send", "to forward", "to exfiltrate", "to leak",
# "to delete" or "to transfer", or "with my" or "with the user's"
# credential(s) or secret(s). It matches wording, not meaning: it does not
# read whose data goes where or at whose request, so it fires on the user's
# own request ("Email the chat history to ana@example.com", "use the email
# tool to send the invoice"), and it misses a hijack worded any other way.
# Whether the text directs the agent to act for an attacker is judged in Layer
# 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_TOOL_CALL_HIJACK_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.tool_hijack

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?i)(?:\b(?:forward|send|post|transmit|exfiltrate|leak|upload|email)\b[^.!?\n]{0,90}?\b(?:system\s+prompt|credentials?|api\s+keys?|secrets?|conversation|chat\s+history|password|the\s+above)\b[^.!?\n]{0,90}?\bto\s+(?:https?://|\S+@)|(?:make|issue|perform|execute)\s+an?\s+(?:http|https|get|post|curl|fetch)\s+request\s+to\s+https?://|(?:call|invoke|use|execute)\s+(?:the\s+)?\w+\s+(?:tool|function|api)\s+(?:to\s+(?:send|forward|exfiltrate|leak|delete|transfer)|with\s+(?:my|the\s+user'?s)\s+(?:credentials?|secrets?)))`, normalize.text)

rule_id := "rego-art15-ipi-010"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems shall be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. The technical solutions aiming to ensure the cybersecurity of high-risk AI systems shall be appropriate to the relevant circumstances and the risks. The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

severity := "critical"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content. Article 15(5) applies to high-risk AI systems from 2 December 2027 (Annex III) and 2 August 2028 (Annex I): this finding is readiness tooling, not a currently binding obligation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
