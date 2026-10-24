# ComplyEdge: Prompt-injection / IPI: Indirect injection, embedded instruction
#
# An instruction hidden in content an AI processes (a document, email, page or
# tool result) that tells it to ignore its user and do something else.
#
# Layer 1 detects: in any letter case, "when you", "when the AI", "when the
# assistant", "when the model" or "when the LLM", followed by read, process,
# summarise, summarize, analyse, analyze or parse (with or without a final
# "s"), then "this", then, within the next 60 characters on the same line,
# ignore, instead, "you must", "do not" or disregard; a line that starts
# (after optional spaces and one to three "#") with "system" or "assistant"
# followed by message, prompt, instruction or note, then a colon or ">"; and
# an opening "<system>", "<important_instruction>" or
# "<important_instructions>" tag, with or without spaces inside the brackets.
# It matches wording, not meaning: it does not read who wrote the text, so it
# fires on the user's own request in the same form ("When you read this, do
# not skip the appendix") and on a document line that begins "System note:"
# for an ordinary reason, and it misses an embedded instruction worded any
# other way. Whether the text carries a third party's instruction is judged in
# Layer 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported from the universal YAML rule named below; that
# rule has since gained alternatives this leaf does not carry, so the two
# patterns no longer match.
#
# Source rule: PROMPT_SECURITY_INDIRECT_INJECTION_EMBEDDED_INSTRUCTION_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.indirect_embedded

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?i)(?:when\s+(?:you|the\s+(?:ai|assistant|model|llm))\s+(?:read|process|summari[sz]e|analy[sz]e|parse)s?\s+this\b.{0,60}?\b(?:ignore|instead|you\s+must|do\s+not|disregard)|(?:^|\n)\s*(?:#{1,3}\s*)?(?:system|assistant)\s+(?:message|prompt|instruction|note)\s*[:>]|<\s*(?:system|important_instructions?)\s*>)`, normalize.text)

rule_id := "rego-art15-ipi-003"

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
