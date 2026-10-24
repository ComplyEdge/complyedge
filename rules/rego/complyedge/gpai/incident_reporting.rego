# ComplyEdge: EU AI Act Article 55(1)(c): Incident Reporting
#
# A provider of a general-purpose AI model with systemic risk failing to
# track, document or report serious incidents to the AI Office.
#
# Layer 1 detects: as adjacent words, no, without, disable (any ending) or
# skip, then "serious incident" or "incident", then tracking, reporting or
# report, then for or to, then gpai, "ai office" or model with no word in
# between ("reporting to the AI Office" does not match); and fail, neglect or
# omit (any ending), then "to", then track, report or document, then "serious
# incident". It matches wording, not meaning: it misses a failure to track or
# report told in other words, and it fires on text that only names it, such as
# a refusal. Whether a provider fails to keep track of, document or report
# serious incidents is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(c)
# Recital: 115: if the development or use of a model with systemic risk causes a serious incident, the provider should without undue delay keep track of it and report relevant information and possible corrective measures
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_55/par_1/pnt_c/oj
# Provision: Regulation (EU) 2024/1689, Article 55(1)(c)

package complyedge.gpai.incident_reporting

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"\\b(?:no|without|disable\\w*|skip)\\s+(?:serious\\s+incident|incident)\\s+(?:tracking|reporting|report)\\s+(?:for|to)\\s+(?:gpai|\\bai\\s+office|model)",
		"(?:fail|neglect|omit)\\w*\\s+to\\s+(?:track|report|document)\\s+serious\\s+incident",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1c-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(c): In addition to the obligations listed in Articles 53 and 54, providers of general-purpose AI models with systemic risk shall: ... (c) keep track of, document, and report, without undue delay, to the AI Office and, as appropriate, to national competent authorities, relevant information about serious incidents and possible corrective measures to address them;"

severity := "high"

remediation := "Track, document, and report serious incidents to the AI Office without undue delay."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
