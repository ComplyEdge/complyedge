# ComplyEdge: Prompt-injection / IPI: Indirect injection, separator/context hijack
#
# Fake separators, system markers or role tags inside a text ("<system>", "###
# new instructions") that try to start a new context and take over the AI's
# instructions.
#
# Layer 1 detects: in any letter case, at the start of a line (after optional
# spaces): a separator (three or more "=", "-" or "*", two or more "#", or a
# [user], [assistant], [system], [context], [input] or [prompt] tag or the
# same names as <tag> or </tag>), followed directly (spaces allowed) by a
# marker: "end of input", "end of user input", "end of prompt", "end of
# context" or "end of message" (the words joined by spaces, hyphens or
# underscores, "of" and "user" optional); "new instructions", "new prompt",
# "new system prompt" or "new system message"; "begin new", "begin system" or
# "begin assistant"; "system override" or "system prompt"; "admin override";
# or "important instruction(s)" or "important note". A tag or separator on its
# own, such as a bare "<system>", does not match. It matches wording, not
# meaning: it fires on ordinary formatting in the same form, such as a
# markdown heading "## Important note", and it misses a context hijack built
# any other way. Whether the text tries to start a new context and take over
# the AI's instructions is judged in Layer 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_INDIRECT_INJECTION_SEPARATOR_HIJACK_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.separator_hijack

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?im)^\s*(?:={3,}|-{3,}|\*{3,}|#{2,}|\[/?(?:user|assistant|system|context|input|prompt)\]|</?(?:user|assistant|system|context|input|prompt)>)\s*(?:end[_\s-]?(?:of[_\s-]?)?(?:user[_\s-]?)?(?:input|prompt|context|message)|new[_\s-]?(?:instructions?|prompt|system[_\s-]?(?:prompt|message))|begin[_\s-]?(?:new|system|assistant)|system[_\s-]?(?:override|prompt)|admin[_\s-]?override|important[_\s-]?(?:instructions?|note))\s*(?:={3,}|-{3,}|\*{3,}|#{2,}|\[/?(?:user|assistant|system|context|input|prompt)\]|</?(?:user|assistant|system|context|input|prompt)>)?`, normalize.text)

rule_id := "rego-art15-ipi-008"

citation := "Regulation (EU) 2024/1689, Article 15(5): High-risk AI systems shall be resilient against attempts by unauthorised third parties to alter their use, outputs or performance by exploiting system vulnerabilities. The technical solutions aiming to ensure the cybersecurity of high-risk AI systems shall be appropriate to the relevant circumstances and the risks. The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

severity := "medium"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content. Article 15(5) applies to high-risk AI systems from 2 December 2027 (Annex III) and 2 August 2028 (Annex I): this finding is readiness tooling, not a currently binding obligation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
