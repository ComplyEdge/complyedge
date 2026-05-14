# ComplyEdge — EU AI Act Article 50(2): Synthetic Media Watermarking
#
# AI-generated synthetic media must carry embedded watermarks to enable
# detection of artificial origin. Providers must implement robust
# watermarking techniques that survive common transformations.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(2)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

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
