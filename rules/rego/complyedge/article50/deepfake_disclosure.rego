# ComplyEdge — EU AI Act Article 50(4): Deepfake Disclosure
#
# Deployers of AI systems that generate or manipulate image, audio, or
# video content constituting a deep fake shall disclose that the content
# has been artificially generated or manipulated.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(4)
# Recital: 134 — deepfake deployers must clearly and distinguishably disclose artificial origin; creative/satirical/artistic works require only existence-of-manipulation disclosure that does not impede enjoyment of the work; parallel rule for AI-generated text on matters of public interest absent human editorial control
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)

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
		# Art 50(4): celebrity/public-figure likeness AI generation without disclosure
		# Catches prompts that use "match/replicate voice and likeness" without disclosing AI origin
		"(?:creat|match|replicate).*(?:voice|likeness).*without.*disclos",
		# Catches "publish without disclosing that the appearance is AI-generated"
		"publish.*without.*disclos.*ai[\\-]?generat",
		# Catches "AI-generated appearance" disclosed after the fact
		"appearance.*ai[\\-]?generat.*without.*disclos",
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
