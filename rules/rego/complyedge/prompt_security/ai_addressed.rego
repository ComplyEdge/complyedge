# ComplyEdge: Prompt-injection / IPI: Indirect injection, AI-addressed directive
#
# Content that addresses any AI reading it ("if you are an AI processing this
# page") and tells it to follow the content's directions instead of its
# user's.
#
# Layer 1 detects: in any letter case, "attention" (optionally followed by a
# comma or colon) followed by AI, language model, assistant, LLM or chatbot;
# "note to" (optionally "any" or "the") followed by AI, language model,
# assistant or LLM; "message", "instruction" or "instructions" for or to
# (optionally "the") AI, assistant, language model or LLM, followed by
# "reading" or "processing"; "if you are", "if you're" or "if youre" followed
# by "a" or "an", then AI, language model, assistant or LLM, then reading,
# processing, parsing, summarising or summarizing; and "dear" followed by AI,
# assistant, language model or chatbot. It matches wording, not meaning: it
# does not read who wrote the text, so it fires on the operator's or user's
# own words in the same form ("Note to the assistant: keep answers short"),
# and it misses a directive to an AI worded any other way. Whether the text is
# a third party's attempt to redirect the AI is judged in Layer 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported from the universal YAML rule named below; that
# rule has since gained alternatives this leaf does not carry, so the two
# patterns no longer match.
#
# Source rule: PROMPT_SECURITY_INDIRECT_INJECTION_AI_ADDRESSED_DIRECTIVE_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.ai_addressed

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?i)\b(?:attention[,:]?\s+(?:ai|language\s+model|assistant|llm|chatbot)|note\s+to\s+(?:any\s+|the\s+)?(?:ai|language\s+model|assistant|llm)|(?:message|instructions?)\s+(?:for|to)\s+(?:the\s+)?(?:ai|assistant|language\s+model|llm)\s+(?:reading|processing)|if\s+you(?:'?re|\s+are)\s+an?\s+(?:ai|language\s+model|assistant|llm)\s+(?:reading|processing|parsing|summari[sz]ing)|dear\s+(?:ai|assistant|language\s+model|chatbot))\b`, normalize.text)

rule_id := "rego-art15-ipi-004"

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
