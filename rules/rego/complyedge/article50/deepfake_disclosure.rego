# ComplyEdge: EU AI Act Article 50(4): Deepfake Disclosure
#
# Deployers of AI systems that generate or manipulate image, audio, or
# video content constituting a deep fake shall disclose that the content
# has been artificially generated or manipulated.
#
# Layer 1 detects: "deepfake", then the word "no", "not", "without" or "lack" (any
# ending), then disclos (any ending); "deepfake" (also "deep fake" or
# "deep-fake"), then "undisclosed" or unlabel; generat or manipulat, then
# face, likeness or voice, then the word "no", "not" or "without", then disclos;
# "synthetic face", "synthetic voice" or "synthetic likeness" (space, hyphen
# or one word), then the word "no", "not" or "without", then label; "face swap"
# (space, hyphen or one word), then the word "no", "not" or "without", then disclos
# or consent; create or produc, then "deepfake", then the word "no", "not" or
# "without", then disclos or label; creat, match or replicate, then voice or
# likeness, then "without", then disclos; publish, then "without", then
# disclos, then the word "ai" followed by generat (with a hyphen or nothing
# between); and appearance, then "ai-generat" written the same way, then
# "without", then disclos. Case is ignored, the parts must sit on one line in
# the order given with any words between them, and a part not called a word
# can start inside a longer word. It matches wording, not meaning: it misses a
# deepfake told in other words ("Post the cloned voice of the mayor tonight
# and do not tell anyone it is synthetic." does not fire), it does not read
# the law-enforcement exception ("Police may use the deepfake without
# disclosure where the use is authorised by law to investigate the offence."
# fires), and it fires on a refusal ("We never publish a deepfake without
# disclosure."). Whether a text deploys a deep fake without the disclosure is
# judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(4), first subparagraph
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 134: deepfake deployers must clearly and distinguishably disclose artificial origin; creative/satirical/artistic works require only existence-of-manipulation disclosure that does not impede enjoyment of the work; parallel rule for AI-generated text on matters of public interest absent human editorial control
# Effective: 2026-08-02
# Penalty: up to EUR 15 000 000 or, for an undertaking, up to 3 % of total worldwide annual turnover for the preceding financial year, whichever is higher (Article 99(4)); for SMEs, whichever is lower (Article 99(6))
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_50/par_4/oj
# Provision: Regulation (EU) 2024/1689, Article 50(4), first subparagraph

package complyedge.article50.deepfake_disclosure

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	deepfake_disclosure_pattern_match
}

deepfake_disclosure_pattern_match if {
	patterns := [
		"deepfake.*\\b(?:no|not|without|lack\\w*)\\b.*disclos",
		"deep[\\-\\s]?fake.*(?:undisclosed|unlabel)",
		"(?:generat|manipulat).*(?:face|likeness|voice).*\\b(?:no|not|without)\\b.*disclos",
		"synthetic[\\-\\s]?(?:face|voice|likeness).*\\b(?:no|not|without)\\b.*label",
		"face[\\-\\s]?swap.*\\b(?:no|not|without)\\b.*(?:disclos|consent)",
		"(?:create|produc).*deepfake.*\\b(?:no|not|without)\\b.*(?:disclos|label)",
		# Art 50(4): celebrity/public-figure likeness AI generation without disclosure
		# Catches prompts that use "match/replicate voice and likeness" without disclosing AI origin
		"(?:creat|match|replicate).*(?:voice|likeness).*without.*disclos",
		# Catches "publish without disclosing that the appearance is AI-generated"
		"publish.*without.*disclos.*\\bai[\\-]?generat",
		# Catches "AI-generated appearance" disclosed after the fact
		"appearance.*\\bai[\\-]?generat.*without.*disclos",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-4-001"

citation := "Regulation (EU) 2024/1689, Article 50(4), first subparagraph: Deployers of an AI system that generates or manipulates image, audio or video content constituting a deep fake, shall disclose that the content has been artificially generated or manipulated. This obligation shall not apply where the use is authorised by law to detect, prevent, investigate or prosecute criminal offence. Where the content forms part of an evidently artistic, creative, satirical, fictional or analogous work or programme, the transparency obligations set out in this paragraph are limited to disclosure of the existence of such generated or manipulated content in an appropriate manner that does not hamper the display or enjoyment of the work."
severity := "high"

remediation := "Clearly label all deepfake content as artificially generated or manipulated. Implement prominent disclosure at the point of distribution and embed machine-readable metadata indicating synthetic origin."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
