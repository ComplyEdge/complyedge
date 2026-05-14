# ComplyEdge — EU AI Act Article 51: GPAI Model Classification
#
# Providers of general-purpose AI models must classify their models
# according to the criteria set out in the regulation, including
# whether the model presents systemic risks.
#
# Legal citation: Regulation (EU) 2024/1689, Article 51
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

package complyedge.gpai.model_classification

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	model_classification_pattern_match
}

model_classification_pattern_match if {
	patterns := [
		"gpai.*(?:no|without|lack).*classif",
		"general[\\- ]?purpose.*model.*(?:no|without).*classif",
		"(?:unclassified|unregistered).*(?:gpai|general[\\- ]?purpose.*ai)",
		"deploy.*(?:gpai|foundation[\\- ]?model).*(?:no|without).*(?:classif|categori)",
		"(?:skip|bypass|omit).*model.*classif",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-51-001"

citation := "Regulation (EU) 2024/1689, Article 51: Providers of general-purpose AI models must classify their models according to the regulatory criteria, including assessment of systemic risk."

severity := "high"

remediation := "Classify the general-purpose AI model according to Article 51 criteria. Determine whether the model presents systemic risks and register the classification with the relevant authority."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
