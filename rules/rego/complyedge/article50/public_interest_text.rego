# ComplyEdge — EU AI Act Article 50(4): Public Interest AI Text Disclosure
#
# Deployers of an AI system that generates or manipulates text published
# with the purpose of informing the public on matters of public interest
# shall disclose that the text has been artificially generated or manipulated.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50, paragraph 4, second subparagraph
# Recital: 134 — deployers must disclose AI-generated public-interest text unless subject to human editorial review with editorial responsibility
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Distinct from deepfake_disclosure.rego (rego-art50-4-001) image/audio/video
# deep fakes and deepfake_audio.rego (rego-art50-4-002). Covers public-interest text.

package complyedge.article50.public_interest_text

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	public_interest_text_pattern_match
}

public_interest_text_pattern_match if {
	patterns := [
		"(?:ai[\\- ]?generated|generated[\\- ]?by[\\- ]?ai).*(?:news|article|report|text).*(?:public[\\- ]?interest|inform[\\- ]?the[\\- ]?public).*(?:without|no|undisclosed).*(?:disclos|label|flag|mark)",
		"(?:publish|release|post).*(?:ai[\\- ]?generated|synthetic).*(?:text|article|news).*(?:public[\\- ]?interest|matters[\\- ]?of[\\- ]?public).*(?:without|no).*(?:disclos|label|flag)",
		"(?:do[\\- ]?not|won't|will[\\- ]?not).*(?:flag|label|disclos|mark).*(?:ai[\\- ]?generated|artificially[\\- ]?generated|artificial)",
		"(?:readers[\\- ]?prefer).*(?:human[\\- ]?written)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-4-003"

citation := "Regulation (EU) 2024/1689, Article 50, paragraph 4, second subparagraph: Deployers of an AI system that generates or manipulates text published with the purpose of informing the public on matters of public interest shall disclose that the text has been artificially generated or manipulated."

severity := "high"

remediation := "Disclose that public-interest text was artificially generated or manipulated at publication. Exception applies only where content underwent human review with editorial responsibility."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
