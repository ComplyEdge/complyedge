# ComplyEdge — EU AI Act Article 21: High-Risk Provider Authority Cooperation
#
# Providers of high-risk AI systems shall cooperate with competent authorities
# in any action those authorities take in relation to the high-risk AI system
# to implement this Regulation.
#
# Legal citation: Regulation (EU) 2024/1689, Article 21, paragraph 1
# Recital: 81 — high-risk providers must cooperate with competent authorities implementing the Regulation
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)

package complyedge.article21.authority_cooperation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	authority_cooperation_pattern_match
}

authority_cooperation_pattern_match if {
	patterns := [
		"(?:refuse|deny|reject|block|withhold|fail[\\- ]?to).*(?:cooperat\\w*).*(?:competent[\\- ]?authorit|national[\\- ]?authorit|market[\\- ]?surveillance|regulator).*(?:high[\\- ]?risk|ai[\\- ]?system)?",
		"(?:high[\\- ]?risk).*(?:provider).*(?:refuse|deny|withhold|block).*(?:cooperat\\w*|authorit\\w*|inspection|investigation)",
		"(?:obstruct|impede|hinder).*(?:competent[\\- ]?authorit|national[\\- ]?authorit|market[\\- ]?surveillance).*(?:high[\\- ]?risk|ai[\\- ]?system|inspection|investigation)?",
		"(?:no|without).*(?:cooperation).*(?:competent[\\- ]?authorit|authority[\\- ]?request).*(?:high[\\- ]?risk|provider)?",
		"(?:article[\\- ]?21|art\\.?\\s*21).*(?:not[\\- ]?met|ignored|refused|denied)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art21-1-001"

citation := "Regulation (EU) 2024/1689, Article 21, paragraph 1: Providers of high-risk AI systems shall cooperate with competent authorities in any action those authorities take in relation to the high-risk AI system in order to implement this Regulation."

severity := "high"

remediation := "Cooperate with competent authorities on request: provide documentation, access, and information needed to implement the Regulation for the high-risk AI system."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
