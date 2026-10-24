# ComplyEdge: Article 15 robustness: embedded indirect instruction (IPI)
#
# An instruction hidden in content an AI processes (a document, email, page or
# tool result) that tells it to ignore its user and do something else.
#
# Layer 1 detects: in any letter case, "when you" followed by summarize,
# summarise, read, process, analyze, analyse or parse, then "this"; "system:"
# followed by "new instructions"; an opening "<system>" tag, with or without
# spaces inside the brackets; and "ignore the user and instead". It matches
# wording, not meaning: it does not read who wrote the text, so it fires on
# the user's own request in the same form ("When you summarize this, keep it
# to three bullets") and on any text that quotes a <system> tag, and it misses
# an embedded instruction worded any other way. Whether the text carries a
# third party's instruction is judged in Layer 2.
#
# Benchmark: PS_INDIRECT_EMBEDDED_001
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.embedded_instruction

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	pattern_match
}

pattern_match if {
	patterns := [
		"when\\s+you\\s+(summarize|summarise|read|process|analyze|analyse|parse)\\s+this",
		"system:\\s*new\\s+instructions",
		"<\\s*system\\s*>",
		"ignore\\s+the\\s+user\\s+and\\s+instead",
	]
	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-ipi-003"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems shall be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. The technical solutions aiming to ensure the cybersecurity of high-risk AI systems shall be appropriate to the relevant circumstances and the risks. The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

severity := "high"

remediation := "Treat document-embedded override instructions as adversarial input; do not obey them over the user task. Article 15(5) applies to high-risk AI systems from 2 December 2027 (Annex III) and 2 August 2028 (Annex I): this finding is readiness tooling, not a currently binding obligation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
