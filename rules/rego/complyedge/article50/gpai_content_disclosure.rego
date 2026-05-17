# ComplyEdge — EU AI Act Article 50(2): GPAI Content Disclosure
#
# Providers of AI systems that generate synthetic audio, image, video,
# or text content shall ensure that the outputs are marked in a
# machine-readable format and detectable as artificially generated.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(2)
# Recital: 133 — synthetic AI-generated content is increasingly indistinguishable from human-generated content; providers must ensure outputs (audio, image, video, text) are marked in machine-readable format using effective, interoperable, robust techniques (watermarks, metadata, cryptographic provenance, fingerprints)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)

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
		# Art 50(4): AI-generated text on public-interest matters without disclosure
		# Catches "do not flag it as AI-generated" instruction to suppress required disclosure
		"do not flag.*ai[\\-]?generat",
		"generat.*(?:article|news|report|text).*(?:do not|not).*(?:flag|label|disclos)",
		# Catches "readers prefer human-written" as intent to hide AI origin
		"readers prefer.*human[\\-]?written",
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
