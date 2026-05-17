# ComplyEdge — EU AI Act Article 51: GPAI Model Classification
#
# Providers of general-purpose AI models must classify their models
# according to the criteria set out in the regulation, including
# whether the model presents systemic risks.
#
# Legal citation: Regulation (EU) 2024/1689, Article 51
# Recital: 110 — defines systemic risks as actual or reasonably foreseeable negative effects on public health/safety, democratic processes, fundamental rights, or critical sectors. Recitals 111-112 operationalise the 10²⁵ FLOPs training-compute threshold and the Commission's designation procedure
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
#
# Scope note: Art 51 classifies GPAI models w/ systemic risk based on high-impact
# capabilities (presumed at >10²⁵ FLOPs cumulative training compute). The related
# notification obligation under Art 52 (notify Commission within 2 weeks of
# crossing the threshold) is a separate procedural obligation not enforced here.

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
