# ComplyEdge: EU AI Act Article 53(2): Open-Source GPAI Exemption Boundary
#
# Providers of GPAI models released under a free and open-source licence with
# publicly available parameters (weights, architecture, usage information) are
# exempt from Article 53(1)(a) and (b) only when the model does not present a
# systemic risk. Claiming the carve-out while withholding parameters, or while
# the model is systemic-risk, is a documentation/transparency failure.
#
# Layer 1 detects: within one line and in this order, "open source" (also
# "open-source"), then gpai or "foundation model", then exempt, exemption or
# carve out, then the whole word without, no, not or lack (any ending), then
# weight, parameter or architecture; claim, assert or invoke, then "53(2)", then "systemic risk" or "sr
# model"; "open source", then exempt or exemption, then "53", then "systemic
# risk", or "without" followed by "public" and then "weight"; and gpai or
# "foundation model", then "closed weight", then claim or assert, then "open
# source", then "exempt". It matches wording, not meaning: it misses the claim
# told in other words, and it fires on a lawful statement of the exemption
# ("Our open-source GPAI model is exempt under Article 53(2) because it does
# not present a systemic risk."). Whether the exemption is claimed for a model
# that does not meet its conditions is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(2)
# Recitals: 102 to 104 (open-source release reduces the documentation burden
#   for models without systemic risk; systemic-risk models remain fully obligated)
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_53/par_2/oj
# Provision: Regulation (EU) 2024/1689, Article 53(2)

package complyedge.gpai.open_source_exemption

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"open[\\-\\s]?source.*(?:gpai|foundation[\\-\\s]?model).*(?:exempt|exemption|carve[\\-\\s]?out).*\\b(?:without|no|not|lack\\w*)\\b.*(?:weight|parameter|architecture)",
		"(?:claim|assert|invoke).*53\\(2\\).*(?:systemic[\\-\\s]?risk|sr[\\-\\s]?model)",
		"open[\\-\\s]?source.*(?:exempt|exemption).*53.*(?:systemic[\\-\\s]?risk|without.*public.*weight)",
		"(?:gpai|foundation[\\-\\s]?model).*closed[\\-\\s]?weight.*(?:claim|assert).*open[\\-\\s]?source.*exempt",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53-2-001"

citation := "Regulation (EU) 2024/1689, Article 53(2): The obligations set out in paragraph 1, points (a) and (b), shall not apply to providers of AI models that are released under a free and open-source licence that allows for the access, usage, modification, and distribution of the model, and whose parameters, including the weights, the information on the model architecture, and the information on model usage, are made publicly available. This exception shall not apply to general-purpose AI models with systemic risks."

severity := "high"

remediation := "Do not claim the Article 53(2) open-source exemption unless weights, architecture, and usage information are publicly available and the model is not systemic-risk. Systemic-risk GPAI remains fully subject to Article 53(1)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
