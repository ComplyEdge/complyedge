# ComplyEdge: EU AI Act Article 5(1)(a): Subliminal Manipulation
#
# Prohibits AI systems that deploy subliminal techniques beyond a person's
# consciousness, or purposefully manipulative or deceptive techniques, to
# materially distort behaviour causing significant harm.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(a)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 29: subliminal, manipulative or deceptive techniques that materially distort behaviour beyond a person's consciousness undermine autonomy and informed decision-making
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-10
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_5/par_1/pnt_a/oj
# Provision: Regulation (EU) 2024/1689, Article 5(1)(a)

package complyedge.article5.subliminal_manipulation

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	subliminal_pattern_match
}

subliminal_pattern_match if {
	patterns := [
		"subliminal",
		"dark[\\-\\s]?pattern",
		"manipulat.*behavio(?:u)?r",
		"covert[\\-\\s]?influence",
		"deceptive[\\-\\s]?technique",
		"psychological[\\-\\s]?manipulation",
		"neuro[\\-\\s]?linguistic[\\-\\s]?exploit",
		"beyond.*consciousness.*distort",
		"materially.*distort.*behavio",
		"impair.*informed.*decision",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1a-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(a): the placing on the market, the putting into service or the use of an AI system that deploys subliminal techniques beyond a person's consciousness or purposefully manipulative or deceptive techniques, with the objective, or the effect of materially distorting the behaviour of a person or a group of persons by appreciably impairing their ability to make an informed decision, thereby causing them to take a decision that they would not have otherwise taken in a manner that causes or is reasonably likely to cause that person, another person or group of persons significant harm;"
severity := "critical"

remediation := "Remove any subliminal, manipulative, or deceptive techniques designed to distort user behaviour. Ensure AI interactions are transparent and do not impair informed decision-making."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
