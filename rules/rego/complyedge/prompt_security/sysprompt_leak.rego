# ComplyEdge: Prompt-injection / IPI: Exfiltration, system-prompt leak
#
# Text that tries to make an AI reveal its system prompt, hidden instructions
# or configuration.
#
# Layer 1 detects: in any letter case, reveal, print, repeat, show, display,
# output, "tell me", reproduce, echo or recite (optionally followed by "me",
# then optionally "your", "the" or "all of your"), then "system prompt",
# "initial instruction(s)", "initial prompt", hidden, secret, original or
# confidential instruction(s), prompt or rules, or "prompt verbatim"; and
# "what are", "what were" or "what is" "your" (optionally exact, full or
# complete) followed by initial, original, system or hidden, then
# instruction(s), prompt, rules or directive(s). It does not match a request
# for the AI's configuration in other words. It matches wording, not meaning:
# it does not read who is asking, so it fires on the operator's own request
# ("show the system prompt in the settings panel"), and it misses a leak
# request worded any other way. Whether the text tries to extract the AI's
# hidden instructions is judged in Layer 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_EXFIL_SYSTEM_PROMPT_LEAK_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.sysprompt_leak

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?i)\b(?:(?:reveal|print|repeat|show|display|output|tell\s+me|reproduce|echo|recite)\s+(?:me\s+)?(?:your\s+|the\s+|all\s+of\s+your\s+)?(?:system\s+prompt|initial\s+(?:instructions?|prompt)|(?:hidden|secret|original|confidential)\s+(?:instructions?|prompt|rules)|prompt\s+verbatim)|what\s+(?:are|were|is)\s+your\s+(?:exact\s+|full\s+|complete\s+)?(?:initial\s+|original\s+|system\s+|hidden\s+)(?:instructions?|prompt|rules|directives?))\b`, normalize.text)

rule_id := "rego-art15-ipi-005"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems shall be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. The technical solutions aiming to ensure the cybersecurity of high-risk AI systems shall be appropriate to the relevant circumstances and the risks. The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

severity := "high"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content. Article 15(5) applies to high-risk AI systems from 2 December 2027 (Annex III) and 2 August 2028 (Annex I): this finding is readiness tooling, not a currently binding obligation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
