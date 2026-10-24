# ComplyEdge: EU AI Act Article 51: GPAI Model Classification
#
# Article 51(1) classifies a general-purpose AI model as a model with
# systemic risk when it meets either condition; Article 51(2) presumes high
# impact capabilities above 10^25 FLOPs of cumulative training compute. The
# classification follows from the Regulation and the Commission; Article 51
# puts no classification duty on providers. The provider duty is the Article
# 52(1) notification to the Commission within two weeks.
#
# Layer 1 detects: "gpai", then the word "no", "not", "without" or "lack" (any
# ending), then classif; "general purpose" (space, hyphen or one word), then
# model, then the word "no", "not" or "without", then classif; "unclassified" or
# "unregistered", then "gpai" or "general purpose" followed later by the word
# starting "ai"; deploy, then "gpai" or "foundation model" (space, hyphen or
# one word), then the word "no", "not" or "without", then classif or categori; and
# skip, bypass or omit, then model, then classif. Case is ignored, the parts
# must sit on one line in the order given with any words between them, and a
# part not called a word can start inside a longer word. It matches wording,
# not meaning: it does not read the Article 52(1) notification ("Our model
# crossed 10^25 FLOPs last month and we have not told the Commission." does
# not fire), and it fires on text that says no classification applies ("Our
# GPAI model is not a systemic-risk model, so no classification as such
# applies." fires). Whether a provider failed to notify a model that meets
# Article 51(1) is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 51(1) and Article 52(1)
# Recital: 110: defines systemic risks as actual or reasonably foreseeable negative effects on public health/safety, democratic processes, fundamental rights, or critical sectors. Recitals 111-112 operationalise the 10²⁵ FLOPs training-compute threshold and the Commission's designation procedure
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
#
# Scope note: the condition matches text about a GPAI model released without a
# classification. It does not test the Article 52(1) breach itself (a model
# that crossed the threshold and was not notified to the Commission), and it
# does not read the Article 52(2) arguments a provider may present.
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_51/oj
# Provision: Regulation (EU) 2024/1689, Article 51(1) and Article 52(1)

package complyedge.gpai.model_classification

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	model_classification_pattern_match
}

model_classification_pattern_match if {
	patterns := [
		"gpai.*\\b(?:no|not|without|lack\\w*)\\b.*classif",
		"general[\\-\\s]?purpose.*model.*\\b(?:no|not|without)\\b.*classif",
		"(?:unclassified|unregistered).*(?:gpai|general[\\-\\s]?purpose.*\\bai)",
		"deploy.*(?:gpai|foundation[\\-\\s]?model).*\\b(?:no|not|without)\\b.*(?:classif|categori)",
		"(?:skip|bypass|omit).*model.*classif",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-51-001"

citation := "Regulation (EU) 2024/1689, Article 51(1): A general-purpose AI model shall be classified as a general-purpose AI model with systemic risk if it meets any of the following conditions: (a) it has high impact capabilities evaluated on the basis of appropriate technical tools and methodologies, including indicators and benchmarks; Article 52(1): Where a general-purpose AI model meets the condition referred to in Article 51(1), point (a), the relevant provider shall notify the Commission without delay and in any event within two weeks after that requirement is met or it becomes known that it will be met."
severity := "high"

remediation := "Assess whether the general-purpose AI model meets the Article 51(1) conditions for systemic risk. If it does, notify the Commission without delay and in any event within two weeks, as Article 52(1) requires."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
