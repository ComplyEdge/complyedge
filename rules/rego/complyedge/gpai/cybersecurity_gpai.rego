# ComplyEdge: EU AI Act Article 55(1)(d): Cybersecurity Protection of GPAI Models with Systemic Risk
#
# A general-purpose AI model with systemic risk, or its physical
# infrastructure, left without adequate cybersecurity protection.
#
# Layer 1 detects: as adjacent words, "systemic risk" (also "systemic-risk"),
# then gpai or model, then without or no, then cybersecurity or "adequate
# security", optionally followed by protection, measure or control; and no,
# without or inadequate, then cybersecurity, then protection or measure
# (singular), optionally "for", optionally "the", then model, gpai or
# "physical infrastructure". It matches wording, not meaning: it misses a gap
# in protection told in other words or in the plural ("no cybersecurity
# measures for the model"), and it fires on text that only names the gap, such
# as a refusal or an audit finding with its fix. Whether a model with systemic
# risk lacks adequate cybersecurity protection is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 55(1)(d)
# Recital: 115: providers of models with systemic risk should ensure an adequate level of cybersecurity protection for the model and its physical infrastructure, including against model leakage, unauthorised access and model theft (also Recital 114)
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. Regulation (EU) 2026/1744 does not amend Articles 51 to 55, 101 or 111(3). The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_55/par_1/pnt_d/oj
# Provision: Regulation (EU) 2024/1689, Article 55(1)(d)

package complyedge.gpai.cybersecurity_gpai

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"systemic[\\-\\s]?risk\\s+(?:gpai|model)\\s+(?:without|no)\\s+(?:cybersecurity|adequate\\s+security)(?:\\s+(?:protection|measure|control))?",
		"\\b(?:no|without|inadequate)\\s+cybersecurity\\s+(?:protection|measure)\\s+(?:for\\s+)?(?:the\\s+)?(?:model|gpai|physical\\s+infrastructure)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art55-1d-001"

citation := "Regulation (EU) 2024/1689, Article 55(1)(d): In addition to the obligations listed in Articles 53 and 54, providers of general-purpose AI models with systemic risk shall: ... (d) ensure an adequate level of cybersecurity protection for the general-purpose AI model with systemic risk and the physical infrastructure of the model."

severity := "high"

remediation := "Ensure an adequate level of cybersecurity protection for the model and its physical infrastructure."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
