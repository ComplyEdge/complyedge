# ComplyEdge: Prompt-injection / IPI: Exfiltration, markdown-image channel
#
# Text that makes an AI emit a markdown image or link whose URL carries data
# (a token, key or conversation content) to an outside server when the reply
# renders.
#
# Layer 1 detects: in any letter case, a markdown image "![...](", an HTML
# "<img ... src=" (the quote optional) or a markdown link "](", directly
# followed by an http or https URL whose query string (before any ")", quote
# or space) contains a parameter named data, leak, exfil, prompt, sys, system,
# content, payload, q, c, s, secret or token ("?q=" or "&token="). It matches
# the shape of the link, not what it carries: it does not read whether the URL
# holds conversation or secret data or who put it there, so it fires on an
# ordinary search link the user asked for
# ("[results](https://www.example.com/search?q=opa)"), and it misses a URL
# that carries data under any other parameter name or in its path. Whether the
# link exfiltrates data is judged in Layer 2.
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_EXFIL_MARKDOWN_IMAGE_CHANNEL_001
# Legal basis: Regulation (EU) 2024/1689, Article 15(5) (resilience against attempts to alter use, outputs or performance)
# Effective: universal (prompt injection is jurisdiction-independent; the rule blocks the pattern as a security control now. The Article 15(5) obligation it cites applies to high-risk AI systems from 2 December 2027 under Annex III and 2 August 2028 under Annex I, Article 113, as amended by Regulation (EU) 2026/1744)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_15/par_5/oj
# Provision: Regulation (EU) 2024/1689, Article 15(5)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.prompt_security.markdown_exfil

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if regex.match(`(?i)(?:!\[[^\]]*\]\(|<img[^>]+src=["']?|\]\()https?://[^)"'\s]*[?&](?:data|leak|exfil|prompt|sys(?:tem)?|content|payload|q|c|s|secret|token)=`, normalize.text)

rule_id := "rego-art15-ipi-007"

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
