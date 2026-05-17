# ComplyEdge — EU AI Act Article 5(1)(d): Predictive Policing
#
# Prohibits AI systems for making risk assessments of natural persons to
# assess or predict the risk of a natural person committing a criminal
# offence, based solely on the profiling of a natural person or on
# assessing their personality traits and characteristics. Exception:
# AI systems supporting human assessment based on objective, verifiable
# facts directly linked to a criminal activity.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(d)
# Recital: 42 — presumption of innocence; natural persons should be judged on actual behaviour, not on AI-predicted behaviour based solely on profiling/personality traits
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
#
# Citation fix: this rule was previously cited as Art 5(1)(e). In the final
# adopted text of Regulation (EU) 2024/1689, predictive policing is Art 5(1)(d);
# Art 5(1)(e) is untargeted scraping of facial images. Corrected 2026-05-16.

package complyedge.article5.predictive_policing

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	predictive_policing_pattern_match
}

predictive_policing_pattern_match if {
	patterns := [
		"predictive[\\- ]?policing",
		"pre[\\- ]?crime",
		"crime[\\- ]?probability[\\- ]?predict",
		"individual[\\- ]?criminal[\\- ]?risk",
		"profiling[\\- ]?based[\\- ]?crime",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1d-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(d): Prohibits the placing on the market, putting into service, or use of an AI system for making risk assessments of natural persons in order to assess or predict the risk of a natural person committing a criminal offence, based solely on the profiling of a natural person or on assessing their personality traits and characteristics."

severity := "critical"

remediation := "Remove any predictive policing or individual criminal risk assessment functionality that relies solely on profiling or personality traits. Risk assessments must be based on objective, verifiable facts directly linked to criminal activity."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
