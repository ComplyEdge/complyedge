# ComplyEdge — EU AI Act Article 50(2): Synthetic Media Watermarking
#
# AI-generated synthetic media must carry embedded watermarks to enable
# detection of artificial origin. Providers must implement robust
# watermarking techniques that survive common transformations.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(2)
# Recital: 133 — same recital as gpai_content_disclosure; this rule specifically targets the technical-effectiveness aspect: machine-readable markers must be robust against common transformations (compression, cropping, format conversion) per Recital 133's "effective, interoperable, robust and reliable" requirement
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)

package complyedge.article50.synthetic_media_watermark

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	synthetic_media_watermark_pattern_match
}

synthetic_media_watermark_pattern_match if {
	patterns := [
		"synthetic[\\- ]?media.*(?:no|without|lack).*watermark",
		"ai[\\- ]?generated.*(?:image|video|audio).*(?:no|without).*watermark",
		"deepfake.*(?:no|without).*watermark",
		"generat.*(?:image|video|audio).*(?:unwatermark|no.*watermark)",
		"(?:strip|remov|bypass).*watermark.*(?:ai|synthetic|generat)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-2-002"

citation := "Regulation (EU) 2024/1689, Article 50(2): AI-generated synthetic media must carry embedded watermarks to enable detection of artificial origin and be robust against common transformations."

severity := "high"

remediation := "Embed robust watermarks into all AI-generated synthetic media (images, video, audio) that survive common transformations such as compression, cropping, and format conversion."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
