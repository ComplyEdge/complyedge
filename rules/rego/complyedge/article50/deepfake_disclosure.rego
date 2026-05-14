# ComplyEdge — EU AI Act Article 50(4): Deepfake Disclosure
#
# Deployers of AI systems that generate or manipulate image, audio, or
# video content constituting a deep fake shall disclose that the content
# has been artificially generated or manipulated.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(4)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

package complyedge.article50.deepfake_disclosure

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	deepfake_disclosure_pattern_match
}

deepfake_disclosure_pattern_match if {
	patterns := [
		"deepfake.*(?:no|without|lack).*disclos",
		"deep[\\- ]?fake.*(?:undisclosed|unlabel)",
		"(?:generat|manipulat).*(?:face|likeness|voice).*(?:no|without).*disclos",
		"synthetic[\\- ]?(?:face|voice|likeness).*(?:no|without).*label",
		"face[\\- ]?swap.*(?:no|without).*(?:disclos|consent)",
		"(?:create|produc).*deepfake.*(?:no|without).*(?:disclos|label)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-4-001"

citation := "Regulation (EU) 2024/1689, Article 50(4): Deployers of AI systems generating or manipulating deep fake content shall disclose that the content has been artificially generated or manipulated."

severity := "high"

remediation := "Clearly label all deepfake content as artificially generated or manipulated. Implement prominent disclosure at the point of distribution and embed machine-readable metadata indicating synthetic origin."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
