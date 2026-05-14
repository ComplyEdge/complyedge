# ComplyEdge — EU AI Act Article 53(c): Copyright Transparency
#
# Providers of general-purpose AI models shall put in place a policy
# to comply with Union law on copyright, and make publicly available a
# sufficiently detailed summary of the content used for training.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(c)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

package complyedge.gpai.copyright_transparency

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	copyright_transparency_pattern_match
}

copyright_transparency_pattern_match if {
	patterns := [
		"training[\\- ]?data.*(?:no|without|lack).*copyright[\\- ]?(?:disclos|polic|summar)",
		"(?:no|without|lack).*training[\\- ]?data.*summar",
		"(?:scrape|crawl).*(?:copyrighted|protected).*(?:no|without).*(?:disclos|polic)",
		"(?:undisclosed|opaque).*training.*(?:corpus|dataset|data)",
		"train.*(?:gpai|foundation[\\- ]?model).*(?:no|without).*copyright.*(?:compl|polic)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53c-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(c): Providers of GPAI models shall put in place a copyright compliance policy and make publicly available a sufficiently detailed summary of the training data content."

severity := "high"

remediation := "Publish a sufficiently detailed summary of training data content. Implement a copyright compliance policy that respects Union copyright law, including opt-out mechanisms for rights holders."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
