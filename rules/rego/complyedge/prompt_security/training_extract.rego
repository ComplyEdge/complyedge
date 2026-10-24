# ComplyEdge: Prompt-injection / IPI: Exfiltration, training-data extraction
#
# Text that tries to make a model leak its training data, including the
# divergence attack: asking it to repeat a word or phrase forever until its
# output drifts into memorised training text.
#
# Layer 1 detects: in any letter case, "repeat" (optionally "the word")
# followed by one single word, quoted or not, then forever, infinitely,
# endlessly, "(a) thousand times", "(a) million times", "(a) hundred times",
# "(a) billion times", or "until you run out", "until you stop" or "until you
# break"; and output, print, reproduce, recite, dump or leak (optionally
# "your", then optionally "verbatim") followed by "training data", "memorised"
# or "memorized" text, data, content or example(s), or "(the) verbatim
# training" or "verbatim memorised" followed by a word. A phrase of two or
# more words to repeat does not match. It matches wording, not meaning: it
# fires on harmless repetition requests in the same form ("repeat hello a
# hundred times for the typing test"), and it misses an extraction request
# worded any other way. Whether the text tries to make the model leak training
# data is judged in Layer 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_EXFIL_TRAINING_DATA_EXTRACTION_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.training_extract

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?i)(?:repeat\s+(?:the\s+word\s+)?["']?\w+["']?\s+(?:forever|infinitely|endlessly|(?:a\s+)?(?:thousand|million|hundred|billion)\s+times|until\s+you\s+(?:run\s+out|stop|break))|(?:output|print|reproduce|recite|dump|leak)\s+(?:your\s+)?(?:verbatim\s+)?(?:training\s+data|memori[sz]ed\s+(?:text|data|content|examples?)|(?:the\s+)?verbatim\s+(?:training|memori[sz]ed)\s+\w+))`, normalize.text)

rule_id := "rego-art15-ipi-006"

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
