# ComplyEdge: EU AI Act Article 12: Record Keeping
#
# A high-risk AI system that does not log its events automatically, or an
# instruction to disable, skip or turn off its logs or record-keeping.
#
# Layer 1 detects: "no", "without", "bypass", "turn off", or a word starting
# "disable" or "skip", then "logging", "logs", "event log", "audit log" or
# "record-keeping" (with a hyphen, a space or as one word), then "for", "on"
# or "in", then "high-risk AI" or "AI system" with no word between ("disable
# logging for AI system calls"); and "high-risk AI", "system" optional, then
# "without" or "no", then "automatic logging" or "automatic event logging". It
# matches wording, not meaning: it misses the practice told in other words
# ("Turn off the logs on the CV screening tool", and "disable logging for the
# AI system", where "the" sits between), and it fires on text that only names
# the practice, such as a refusal. Whether a text does the practice is judged
# in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 12(1)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_12/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 12(1)

package complyedge.highrisk.art12_record_keeping

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:no|without|disable\\w*|bypass|skip\\w*|turn\\s+off)\\s+(?:logging|logs|event\\s+log|audit\\s+log|record[\\-\\s]?keeping)\\s+(?:for|on|in)\\s+(?:high[\\-\\s]?risk\\s+ai|\\bai\\s+system)",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?\\b(?:without|no)\\s+automatic\\s+(?:event\\s+)?logging",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art12-001"

citation := "Regulation (EU) 2024/1689, Article 12(1): High-risk AI systems shall technically allow for the automatic recording of events (logs) over the lifetime of the system."
severity := "high"

remediation := "Enable automatic event logging over the lifetime of the high-risk AI system. Readiness check, not yet a binding obligation: Article 12 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
