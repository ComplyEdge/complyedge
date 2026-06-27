# ComplyEdge — EU AI Act Article 53: GPAI Provider Cooperation with Authorities
#
# Providers of general-purpose AI models shall cooperate as necessary with
# the Commission and national competent authorities in the exercise of their
# competences and powers, including providing documentation and model access
# upon request by the AI Office.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53, paragraph 3
# Recital: 108 — GPAI providers must cooperate with the Commission and national authorities exercising supervisory powers
# Effective: 2025-08-02
# Penalty: up to €15M or 3% of global revenue (Art 101)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Card checklist labels this Art 53(2); adopted Act places
# cooperation at Art 53(3). Art 53(2) is the open-source exemption for
# documentation obligations in paragraph 1(a)-(b). rule_id rego-gpai-53-2-001
# follows card checklist.

package complyedge.gpai.provider_cooperation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	provider_cooperation_pattern_match
}

provider_cooperation_pattern_match if {
	patterns := [
		"(?:refuse|deny|reject|block|withhold|fail[\\- ]?to).*(?:cooperat\\w*|comply).*(?:ai[\\- ]?office|commission|competent[\\- ]?authorit|national[\\- ]?authorit|regulator)",
		"(?:no|without|refuse|deny).*(?:cooperation|cooperat\\w*).*(?:ai[\\- ]?office|commission|competent[\\- ]?authorit|regulator|gpai|authorit\\w*)",
		"(?:refuse|deny|withhold|block|fail[\\- ]?to[\\- ]?provide).*(?:documentation|information|model[\\- ]?access|technical[\\- ]?doc).*(?:ai[\\- ]?office|commission|competent[\\- ]?authorit|upon[\\- ]?request|authority[\\- ]?request)",
		"(?:obstruct|impede|hinder|delay).*(?:ai[\\- ]?office|commission|competent[\\- ]?authorit|authority[\\- ]?investigation|regulatory[\\- ]?investigation)",
		"(?:ignore|dismiss|non[\\- ]?response|no[\\- ]?response).*(?:ai[\\- ]?office|commission|competent[\\- ]?authorit).*(?:request|inquiry|demand|evaluation)",
		"(?:gpai|general[\\- ]?purpose|foundation[\\- ]?model).*(?:provider).*(?:refuse|deny|withhold|block).*(?:cooperat\\w*|documentation|model[\\- ]?access|authority)",
		"(?:will[\\- ]?not|won't|do[\\- ]?not).*(?:grant|provide|allow).*(?:model[\\- ]?access|documentation|information).*(?:ai[\\- ]?office|commission|authorit\\w*)",
		"(?:article[\\- ]?53|art\\.?\\s*53).*(?:cooperat\\w*|authority).*(?:not[\\- ]?met|ignored|refused|denied|withheld)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53-2-001"

citation := "Regulation (EU) 2024/1689, Article 53, paragraph 3: Providers of general-purpose AI models shall cooperate as necessary with the Commission and the national competent authorities in the exercise of their competences and powers pursuant to this Regulation, including providing documentation and model access upon request."

severity := "high"

remediation := "Establish processes to cooperate with the AI Office and national competent authorities upon request: provide technical documentation, training and evaluation information, and necessary model access for supervisory evaluation while protecting confidentiality under Article 78."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
