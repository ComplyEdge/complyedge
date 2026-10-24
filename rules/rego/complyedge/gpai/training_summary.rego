# ComplyEdge: EU AI Act Article 53(1)(d): Training Summary
#
# A general-purpose AI model released without the publicly available,
# sufficiently detailed summary of its training content.
#
# Layer 1 detects: as adjacent words, no, without or missing, then "training
# data summary", "training content summary" or "publicly available summary";
# and gpai, "general purpose ai" (also "general-purpose ai") or foundation,
# then "model", then without or no, then "training data summary", "training
# content summary" or "disclosure of training". It matches wording, not
# meaning: it misses a release without the summary told in other words, and it
# fires on text that only names it, such as a refusal. Whether a provider
# places a model on the market without the public training content summary is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(d)
# Recital: 107: providers should make publicly available a sufficiently detailed summary of the content used for training, generally comprehensive in scope, on the AI Office template (Recital 104: the open-source exception does not reach it)
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_53/par_1/pnt_d/oj
# Provision: Regulation (EU) 2024/1689, Article 53(1)(d)

package complyedge.gpai.training_summary

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:no|without|missing)\\s+(?:training\\s+(?:data|content)\\s+summary|publicly\\s+available\\s+summary)",
		"(?:gpai|general[\\-\\s]purpose\\s+ai|foundation)\\s+model\\s+(?:without|no)\\s+(?:training\\s+(?:data|content)\\s+summary|disclosure\\s+of\\s+training)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art53-1d-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(d): Providers of general-purpose AI models shall: ... (d) draw up and make publicly available a sufficiently detailed summary about the content used for training of the general-purpose AI model, according to a template provided by the AI Office."
severity := "high"

remediation := "Publish a sufficiently detailed summary of the training content per the AI Office template."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
