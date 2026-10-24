# ComplyEdge: EU AI Act Article 50(2): GPAI Content Disclosure
#
# Providers of AI systems that generate synthetic audio, image, video,
# or text content shall ensure that the outputs are marked in a
# machine-readable format and detectable as artificially generated.
#
# Layer 1 detects: generat, then content, then the word "no", "not", "without" or
# "lack" (any ending), then disclos (any ending); the word "ai" followed by
# "generated" (space, hyphen or one word), then the word "no", "not", "without" or
# "lack" (any ending), then label; synthetic, then text, audio, image or
# video, then the word "no", "not" or "without", then mark; "machine generated"
# (space, hyphen or one word), then "undisclosed" or unlabel; generat, then
# text or media, then the word "no", "not" or "without", then watermark; "gpai", then
# output, then the word "no", "not" or "without", then disclos; "do not flag" (single
# spaces), then the word "ai" followed by generat (with a hyphen or nothing
# between); generat, then article, news, report or text, then the word "not"
# or the words "do not", then flag, label or disclos; and "readers prefer"
# (single space), then "human written" or "human-written". Case is ignored,
# the parts must sit on one line in the order given with any words between
# them, and a part not called a word can start inside a longer word. It
# matches wording, not meaning: it does not look for a marker in the output,
# it misses unmarked output told in other words ("Send the generated blog
# posts to customers as if a person wrote them." does not fire), and it fires
# on a refusal ("Our AI-generated images never go out without a label."
# fires). Whether outputs are left without a machine-readable marking is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(2)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 133: synthetic AI-generated content is increasingly indistinguishable from human-generated content; providers must ensure outputs (audio, image, video, text) are marked in machine-readable format using effective, interoperable, robust techniques (watermarks, metadata, cryptographic provenance, fingerprints)
# Effective: 2026-08-02 (Article 111(4), added by Regulation (EU) 2026/1744: providers of systems placed on the market before 2 August 2026 must comply with Article 50(2) by 2 December 2026; the condition does not read the date)
# Penalty: up to EUR 15 000 000 or, for an undertaking, up to 3 % of total worldwide annual turnover for the preceding financial year, whichever is higher (Article 99(4)); for SMEs, whichever is lower (Article 99(6))
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_50/par_2/oj
# Provision: Regulation (EU) 2024/1689, Article 50(2)

package complyedge.article50.gpai_content_disclosure

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	gpai_content_disclosure_pattern_match
}

gpai_content_disclosure_pattern_match if {
	patterns := [
		"generat.*content.*\\b(?:no|not|without|lack\\w*)\\b.*disclos",
		"\\bai[\\-\\s]?generated.*\\b(?:no|not|without|lack\\w*)\\b.*label",
		"synthetic.*(?:text|audio|image|video).*\\b(?:no|not|without)\\b.*mark",
		"machine[\\-\\s]?generated.*(?:undisclosed|unlabel)",
		"generat.*(?:text|media).*\\b(?:no|not|without)\\b.*watermark",
		"gpai.*output.*\\b(?:no|not|without)\\b.*disclos",
		# Article 50(2) covers text output too. These patterns match instructions to
		# publish generated text unmarked ("do not flag it as AI-generated"). The
		# deployer duty for published public-interest text is Article 50(4), second
		# subparagraph, enforced by rego-art50-4-002, not by this rule.
		"do\\snot\\sflag.*\\bai[\\-]?generat",
		"generat.*(?:article|news|report|text).*\\b(?:do\\snot|not)\\b.*(?:flag|label|disclos)",
		# Catches "readers prefer human-written" as intent to hide AI origin
		"readers\\sprefer.*human[\\-]?written",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-2-001"

citation := "Regulation (EU) 2024/1689, Article 50(2): Providers of AI systems, including general-purpose AI systems, generating synthetic audio, image, video or text content, shall ensure that the outputs of the AI system are marked in a machine-readable format and detectable as artificially generated or manipulated. Providers shall ensure their technical solutions are effective, interoperable, robust and reliable as far as this is technically feasible, taking into account the specificities and limitations of various types of content, the costs of implementation and the generally acknowledged state of the art, as may be reflected in relevant technical standards. This obligation shall not apply to the extent the AI systems perform an assistive function for standard editing or do not substantially alter the input data provided by the deployer or the semantics thereof, or where authorised by law to detect, prevent, investigate or prosecute criminal offences."
severity := "high"

remediation := "Implement machine-readable markers and disclosure labels on all AI-generated synthetic content (text, audio, image, video) to ensure outputs are detectable as artificially generated."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
