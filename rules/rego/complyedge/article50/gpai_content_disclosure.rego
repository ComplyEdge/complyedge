# ComplyEdge — EU AI Act Article 50(2): GPAI Content Disclosure
#
# Providers of AI systems that generate synthetic audio, image, video,
# or text content shall ensure that the outputs are marked in a
# machine-readable format and detectable as artificially generated.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(2)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

package complyedge.article50.gpai_content_disclosure

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	gpai_content_disclosure_pattern_match
}

gpai_content_disclosure_pattern_match if {
	patterns := [
		"generat.*content.*(?:no|without|lack).*disclos",
		"ai[\\- ]?generated.*(?:no|without|lack).*label",
		"synthetic.*(?:text|audio|image|video).*(?:no|without).*mark",
		"machine[\\- ]?generated.*(?:undisclosed|unlabel)",
		"generat.*(?:text|media).*(?:no|without).*watermark",
		"gpai.*output.*(?:no|without).*disclos",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-2-001"

citation := "Regulation (EU) 2024/1689, Article 50(2): Providers of AI systems generating synthetic content shall ensure outputs are marked in a machine-readable format and detectable as artificially generated or manipulated."

severity := "high"

remediation := "Implement machine-readable markers and disclosure labels on all AI-generated synthetic content (text, audio, image, video) to ensure outputs are detectable as artificially generated."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
