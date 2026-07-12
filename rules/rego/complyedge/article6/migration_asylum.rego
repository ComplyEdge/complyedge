# ComplyEdge — EU AI Act Article 6 + Annex III §7: Migration, Asylum, Border Control
#
# Classifies AI systems used by competent authorities for migration, asylum,
# border-control management (visa risk assessment, asylum/migration claims,
# document verification, border controls) as high-risk under Annex III §7.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6 + Annex III(7)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% global revenue (Article 101)
# Condition type: deterministic (regex)
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5)

package complyedge.article6.migration_asylum

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"ai.*(?:visa\\s+(?:application|decision|approv)|visa\\s+processing)",
		"ai.*(?:asylum|migration|refugee)\\s+(?:application|claim|risk|decision)",
		"ai.*(?:border\\s+control|customs|immigration\\s+(?:control|processing))",
		"ai.*(?:travel\\s+document|residence\\s+permit)\\s+(?:verif|authent|decision)",
		"automated\\s+(?:visa|asylum|migration|border)\\s+(?:decision|processing|screening)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-annex3-7-001"

citation := "Regulation (EU) 2024/1689, Article 6 + Annex III(7): AI used in migration, asylum, or border-control management (visa assessment, asylum claims, document verification, border processing) is high-risk."

severity := "high"

remediation := "Complete high-risk classification assessment per Article 6 before deployment. Migration/asylum AI requires fundamental-rights impact assessment (Art 27), strict data governance (Art 10), human oversight (Art 14), and EU-database registration."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
