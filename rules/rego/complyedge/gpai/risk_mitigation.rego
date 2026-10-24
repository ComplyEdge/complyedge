# ComplyEdge: EU AI Act Article 55(1)(b): Risk Mitigation
#
# A general-purpose AI model with systemic risk released or run without
# assessing and mitigating its systemic risks.
#
# Layer 1 detects: as adjacent words, "systemic risk" (also "systemic-risk"),
# then gpai or model, then without or no, then "risk assessment", "risk
# mitigation" or "mitigation measure"; and fail, neglect or omit (any ending),
# then "to", then assess or mitigate, then "systemic risk". It matches
# wording, not meaning: it misses a release without risk assessment told in
# other words, and it fires on text that only names it, such as a refusal.
# Whether a provider fails to assess and mitigate systemic risks is judged in
# Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(b)
# Recital: 114 and 115: providers of models with systemic risk should continuously assess and mitigate systemic risks along the model's lifecycle (Recital 110 describes the risks)
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_55/par_1/pnt_b/oj
# Provision: Regulation (EU) 2024/1689, Article 55(1)(b)

package complyedge.gpai.risk_mitigation

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"systemic[\\-\\s]?risk\\s+(?:gpai|model)\\s+(?:without|no)\\s+(?:risk\\s+(?:assessment|mitigation)|mitigation\\s+measure)",
		"(?:fail|neglect|omit)\\w*\\s+to\\s+(?:assess|mitigate)\\s+systemic\\s+risk",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1b-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(b): In addition to the obligations listed in Articles 53 and 54, providers of general-purpose AI models with systemic risk shall: ... (b) assess and mitigate possible systemic risks at Union level, including their sources, that may stem from the development, the placing on the market, or the use of general-purpose AI models with systemic risk;"

severity := "high"

remediation := "Assess and mitigate systemic risks stemming from the GPAI model at Union level."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
