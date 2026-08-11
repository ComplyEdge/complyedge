# ComplyEdge — EU AI Act Article 12: Record Keeping
#
# Legal citation: Regulation (EU) 2024/1689, Article 12
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring)

package complyedge.highrisk.art12_record_keeping

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:no|without|disable\\w*|bypass|skip\\w*|turn\\s+off)\\s+(?:logging|logs|event\\s+log|audit\\s+log|record[\\-\\s]?keeping)\\s+(?:for|on|in)\\s+(?:high[\\-\\s]?risk\\s+ai|ai\\s+system)",
		"high[\\-\\s]?risk\\s+ai\\s+(?:system\\s+)?(?:without|no)\\s+automatic\\s+(?:event\\s+)?logging",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art12-001"

citation := "Regulation (EU) 2024/1689, Article 12 (Record-keeping): 1. High-risk AI systems shall technically allow for the automatic recording of events (logs) over the lifetime of the system. 2. In order to ensure a level of traceability of the functioning of a high-risk AI system that is appropriate to the intended purpose of the system, logging capabilities shall enable the recording of events relevant for: (a) identifying situations that may result in the high-risk AI system presenting a risk within the meaning of Article 79(1) or in a substantial modification; (b) facilitating the post-market monitoring referred to in Article 72; and (c) monitoring the operation of high-risk AI systems referred to in Article 26(5). 3. For high-risk AI systems referred to in point 1(a) of Annex III, the logging capabilities shall provide, at a minimum: (a) recording of the period of each use of the system (start date and time and end date and time of each use); (b) the reference database against which input data has been checked by the system; (c) the input data for which the search has led to a match; (d) the identification of the natural persons involved in the verification of the results, as referred to in Article 14(5)."
severity := "high"

remediation := "Enable automatic event logging over the lifetime of the high-risk AI system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
