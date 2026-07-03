# ComplyEdge — EU AI Act Article 6 + Annex III §8: Justice and Democratic Processes
#
# Classifies AI systems used by judicial authorities for case research, fact
# interpretation, dispute resolution, or by election authorities for influencing
# voter behaviour (where not prohibited by Art 5) as high-risk under Annex III §8.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(8)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5; card 197 / WGlhJpPN)

package complyedge.article6.justice_democracy

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:sentencing|judicial\\s+decision|bail\\s+decision|parole\\s+decision)",
		"ai.*(?:court|case)\\s+(?:dispos|outcome|prediction)",
		"ai.*(?:election|voting|ballot)\\s+(?:influence|target|micro[\\- ]target)",
		"ai.*(?:democratic|referendum)\\s+(?:process|interference)",
		"ai\\s+(?:voter|electorate)\\s+(?:profil|target|micro[\\- ]target)",
		"judicial\\s+ai\\s+(?:assist|aid|research)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-8-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(8): AI used by judicial authorities (case research, sentencing assistance, dispute resolution) or to influence elections/democratic processes (where not prohibited by Art 5) is high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Justice/democracy AI requires fundamental-rights impact assessment (Art 27), transparency, human oversight (Art 14), and EU-database registration."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
