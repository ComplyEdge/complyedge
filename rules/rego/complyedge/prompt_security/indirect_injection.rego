# ComplyEdge: Article 15 robustness: labeled indirect injection / instruction override (IPI)
#
# Fake separators, system markers or role tags inside a text ("<system>", "###
# new instructions") that try to start a new context and take over the AI's
# instructions.
#
# Layer 1 detects: in any letter case, ignore, disregard, forget, override or
# bypass, followed by one or more of "the", "all", "any", "your", "previous",
# "prior" and "above", then instruction(s), prompt(s), directive(s), rule(s),
# constraint(s), guideline(s) or "system prompt" ("ignore all previous
# instructions"); "unrestricted assistant with no guidelines"; and "act as an
# unrestricted assistant". It does not match separators, system markers or
# role tags such as "<system>": the separator form described above is matched
# by the separator/context hijack leaf, which shares this rule_id. It matches
# wording, not meaning: it fires on text that only names the attack ("should
# the bot ignore the previous instructions in a forwarded email?"), and it
# misses an override worded any other way. Whether the text tries to take over
# the AI's instructions is judged in Layer 2.
#
# Benchmark: PS_INDIRECT_INJECTION_002
# Also covers the classic "ignore previous instructions" shape.
#
# Changed 2026-09-30 (agent): removed the bare label pattern
# "indirect prompt injection". It matched the NAME of the attack, so text about
# injection ("a guide on detecting indirect prompt injection in vendor emails")
# was blocked as an injection. The benchmark prompt still blocks on the
# override pattern below. Pending Leo re-sign-off per RULE_STANDARD §5.
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.indirect_injection

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	pattern_match
}

pattern_match if {
	patterns := [
		"(ignore|disregard|forget|override|bypass)\\s+(the\\s+|all\\s+|any\\s+|your\\s+|previous\\s+|prior\\s+|above\\s+)+(instructions?|prompts?|directives?|rules?|constraints?|guidelines?|system\\s+prompt)",
		"unrestricted\\s+assistant\\s+with\\s+no\\s+guidelines",
		"act\\s+as\\s+an\\s+unrestricted\\s+assistant",
	]
	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art15-ipi-008"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems shall be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. The technical solutions aiming to ensure the cybersecurity of high-risk AI systems shall be appropriate to the relevant circumstances and the risks. The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

severity := "high"

remediation := "Refuse instruction-override and unrestricted-assistant jailbreaks, including labeled indirect injections. Article 15(5) applies to high-risk AI systems from 2 December 2027 (Annex III) and 2 August 2028 (Annex I): this finding is readiness tooling, not a currently binding obligation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
