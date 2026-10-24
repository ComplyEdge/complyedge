# ComplyEdge: EU AI Act Article 50(2): Synthetic Media Watermarking
#
# AI-generated synthetic media must carry embedded watermarks to enable
# detection of artificial origin. Providers must implement robust
# watermarking techniques that survive common transformations.
#
# Layer 1 detects: "synthetic media" (space, hyphen or one word), then the
# word "no", "not", "without" or "lack" (any ending), then watermark; the word "ai"
# followed by "generated" (space, hyphen or one word), then image, video or
# audio, then the word "no", "not" or "without", then watermark; "deepfake", then the
# word "no", "not" or "without", then watermark; generat, then image, video or audio,
# then unwatermark or the word "no" or "not" followed later by watermark; and strip,
# remov or bypass, then watermark, then a word starting with "ai", synthetic
# or generat. Case is ignored, the parts must sit on one line in the order
# given with any words between them, and a part not called a word can start
# inside a longer word. It matches wording, not meaning: it does not inspect
# any output for a watermark, it misses unmarked media told in other words
# ("Export the generated product photos as plain JPEGs so nobody can tell they
# came from the model." does not fire), and it fires on text that only names
# the practice or uses "watermark" in another sense ("We never ship synthetic
# media without a watermark." and "The tool removes the watermark from scanned
# invoices before AI extraction." both fire). Whether synthetic media is left
# without a machine-readable marking is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(2)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 133: same recital as gpai_content_disclosure; this rule specifically targets the technical-effectiveness aspect: machine-readable markers must be robust against common transformations (compression, cropping, format conversion) per Recital 133's "effective, interoperable, robust and reliable" requirement
# Effective: 2026-08-02 (Article 111(4), added by Regulation (EU) 2026/1744: providers of systems placed on the market before 2 August 2026 must comply with Article 50(2) by 2 December 2026; the condition does not read the date)
# Penalty: up to EUR 15 000 000 or, for an undertaking, up to 3 % of total worldwide annual turnover for the preceding financial year, whichever is higher (Article 99(4)); for SMEs, whichever is lower (Article 99(6))
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_50/par_2/oj
# Provision: Regulation (EU) 2024/1689, Article 50(2)

package complyedge.article50.synthetic_media_watermark

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	synthetic_media_watermark_pattern_match
}

synthetic_media_watermark_pattern_match if {
	patterns := [
		"synthetic[\\-\\s]?media.*\\b(?:no|not|without|lack\\w*)\\b.*watermark",
		"\\bai[\\-\\s]?generated.*(?:image|video|audio).*\\b(?:no|not|without)\\b.*watermark",
		"deepfake.*\\b(?:no|not|without)\\b.*watermark",
		"generat.*(?:image|video|audio).*(?:unwatermark|\\b(?:no|not)\\b.*watermark)",
		"(?:strip|remov|bypass).*watermark.*(?:\\bai|synthetic|generat)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-2-002"

citation := "Regulation (EU) 2024/1689, Article 50(2): Providers of AI systems, including general-purpose AI systems, generating synthetic audio, image, video or text content, shall ensure that the outputs of the AI system are marked in a machine-readable format and detectable as artificially generated or manipulated. Providers shall ensure their technical solutions are effective, interoperable, robust and reliable as far as this is technically feasible, taking into account the specificities and limitations of various types of content, the costs of implementation and the generally acknowledged state of the art, as may be reflected in relevant technical standards. This obligation shall not apply to the extent the AI systems perform an assistive function for standard editing or do not substantially alter the input data provided by the deployer or the semantics thereof, or where authorised by law to detect, prevent, investigate or prosecute criminal offences."
severity := "high"

remediation := "Embed robust watermarks into all AI-generated synthetic media (images, video, audio) that survive common transformations such as compression, cropping, and format conversion."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
