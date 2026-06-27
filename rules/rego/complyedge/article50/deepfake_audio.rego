# ComplyEdge — EU AI Act Article 50(4): Audio Deepfake Disclosure
#
# Deployers of AI systems that generate or manipulate audio content
# constituting a deep fake shall disclose that the audio has been
# artificially generated or manipulated. This rule targets audio-specific
# synthetic speech, voice cloning, and voice synthesis workflows.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(4)
# Recital: 134 — deepfake deployers must disclose artificial origin; audio deepfakes require clear labelling distinct from source media
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Distinct from deepfake_disclosure.rego (rego-art50-4-001) which
# covers image/video deepfakes and general likeness workflows. This rule
# focuses on audio-only synthetic speech, voice clone, and audio deepfake
# marking obligations under the same Art 50(4) paragraph.

package complyedge.article50.deepfake_audio

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	deepfake_audio_pattern_match
}

deepfake_audio_pattern_match if {
	patterns := [
		"(?:voice[\\- ]?clone|voice[\\- ]?synth|voice[\\- ]?deepfake|audio[\\- ]?deepfake).*(?:without|no|undisclosed|unlabel).*(?:disclos|label|marker|watermark|notice)",
		"(?:clone|synth(?:esi[sz]e|etic)|replicat\\w*|imitat\\w*).*(?:voice|speech|audio).*(?:without|no|undisclosed).*(?:disclos|label|marker|watermark|notice)",
		"(?:synthetic|ai[\\- ]?generated).*(?:speech|voice|audio|podcast|radio).*(?:without|no|undisclosed).*(?:disclos|label|marker|watermark|notice)",
		"(?:audio|voice|speech|podcast|radio).*(?:deepfake|clone|synth(?:esi[sz]e|etic)|ai[\\- ]?generated).*(?:without|no|undisclosed).*(?:disclos|label|marker|watermark|notice)",
		"(?:impersonat\\w*|mimic\\w*).*(?:voice|speech|audio).*(?:without|no).*(?:disclos|label|consent|notice)",
		"(?:generate|produce|create|publish).*(?:audio|voice|speech|podcast).*(?:deepfake|clone|synth(?:esi[sz]e|etic)).*(?:without|no).*(?:disclos|label|marker)",
		"(?:undisclosed|unlabel(?:led|ed)?).*(?:voice[\\- ]?clone|audio[\\- ]?deepfake|synthetic[\\- ]?speech|ai[\\- ]?voice)",
		"(?:strip|remove|bypass).*(?:audio[\\- ]?)?(?:watermark|disclosure|marker).*(?:voice|speech|audio|podcast)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-4-002"

citation := "Regulation (EU) 2024/1689, Article 50(4): Deployers of an AI system that generates or manipulates audio content constituting a deep fake shall disclose that the content has been artificially generated or manipulated."

severity := "high"

remediation := "Label all synthetic audio, voice clones, and AI-generated speech as artificially generated or manipulated at distribution. Embed machine-readable audio markers or watermarks and provide audible or accompanying disclosure before playback."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
