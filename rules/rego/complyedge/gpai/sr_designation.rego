# ComplyEdge: EU AI Act Article 52(1): Notification of a GPAI Model Meeting the Systemic-Risk Condition
#
# A provider of a general-purpose AI model that meets the systemic-risk
# threshold failing to notify the Commission or the AI Office.
#
# Layer 1 detects: as adjacent words, gpai, "general purpose ai" (also
# "general-purpose ai") or foundation, then "model", optionally "with", then
# "systemic risk", then without or no, then a word beginning notif or inform,
# optionally "the", then "ai office" or commission; and fail, omit or neglect
# (any ending), then "to notify", optionally "the", then "ai office" or
# commission, optionally "of", then "systemic risk". It matches wording, not
# meaning: it misses a failure to notify told in other words, and it fires on
# text that only names it, such as a refusal. Whether a provider fails to
# notify the Commission that its model meets the systemic-risk condition is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 52(1)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 112: a provider whose model meets the high-impact threshold should notify at the latest two weeks after the requirements are met or it becomes known they will be met (Recital 111 sets the classification method)
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_52/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 52(1)

package complyedge.gpai.sr_designation

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:gpai|general[\\-\\s]purpose\\s+ai|foundation)\\s+model\\s+(?:with\\s+)?systemic\\s+risk\\s+(?:without|no)\\s+(?:notif|inform)\\w*\\s+(?:the\\s+)?(?:\\bai\\s+office|commission)",
		"(?:fail|omit|neglect)\\w*\\s+to\\s+notify\\s+(?:the\\s+)?(?:\\bai\\s+office|commission)\\s+(?:of\\s+)?systemic\\s+risk",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art52-001"

citation := "Regulation (EU) 2024/1689, Article 51(1): A general-purpose AI model shall be classified as a general-purpose AI model with systemic risk if it meets any of the following conditions: (a) it has high impact capabilities evaluated on the basis of appropriate technical tools and methodologies, including indicators and benchmarks; Article 52(1): Where a general-purpose AI model meets the condition referred to in Article 51(1), point (a), the relevant provider shall notify the Commission without delay and in any event within two weeks after that requirement is met or it becomes known that it will be met."
severity := "high"

remediation := "Notify the Commission without delay and in any event within two weeks after the GPAI model meets the high-impact-capabilities condition of Article 51(1)(a), or it becomes known that it will meet it."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
