# ComplyEdge — Prompt-injection / IPI: Exfiltration — training-data extraction
#
# Deterministic OPA/Rego leaf so this indirect/direct prompt-injection pattern
# blocks on the /v1/check hot path (previously YAML/TrustLint only, retired from
# /v1/check). Pattern ported verbatim from the vetted universal YAML corpus.
#
# Source rule: PROMPT_SECURITY_EXFIL_TRAINING_DATA_EXTRACTION_001
# Legal basis: EU AI Act Art 15(5) — adversarial resilience
# Effective: universal (prompt injection is jurisdiction-independent)
# Approved by: Leo Celis on 2026-07-17 (agent authoring)

package complyedge.prompt_security.training_extract

import rego.v1

default violation := false

violation if regex.match(`(?i)(?:repeat\s+(?:the\s+word\s+)?["']?\w+["']?\s+(?:forever|infinitely|endlessly|(?:a\s+)?(?:thousand|million|hundred|billion)\s+times|until\s+you\s+(?:run\s+out|stop|break))|(?:output|print|reproduce|recite|dump|leak)\s+(?:your\s+)?(?:verbatim\s+)?(?:training\s+data|memori[sz]ed\s+(?:text|data|content|examples?)|(?:the\s+)?verbatim\s+(?:training|memori[sz]ed)\s+\w+))`, input.text)

rule_id := "rego-art15-ipi-006"

citation := "Regulation (EU) 2024/1689, Article 15(5): high-risk AI systems must be resilient against attempts by unauthorised third parties to alter their use or behaviour by exploiting vulnerabilities — indirect/direct prompt injection (IPI). See docs/security-compliance/ipi-conformity-assessment.md."

severity := "high"

remediation := "Block the request: it exhibits a prompt-injection / instruction-override / exfiltration pattern. Do not act on instructions embedded in user or third-party content."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
