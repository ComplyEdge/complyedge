# ComplyEdge — EU AI Act Article 5(1)(a): Subliminal Manipulation
#
# Prohibits AI systems that deploy subliminal techniques beyond a person's
# consciousness, or purposefully manipulative or deceptive techniques, to
# materially distort behaviour causing significant harm.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(a)
# Recital: 29 — subliminal, manipulative or deceptive techniques that materially distort behaviour beyond a person's consciousness undermine autonomy and informed decision-making
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-10

package complyedge.article5.subliminal_manipulation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	subliminal_pattern_match
}

subliminal_pattern_match if {
	patterns := [
		"subliminal",
		"dark[\\- ]?pattern",
		"manipulat.*behavio(?:u)?r",
		"covert[\\- ]?influence",
		"deceptive[\\- ]?technique",
		"psychological[\\- ]?manipulation",
		"neuro[\\- ]?linguistic[\\- ]?exploit",
		"beyond.*consciousness.*distort",
		"materially.*distort.*behavio",
		"impair.*informed.*decision",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1a-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(a): Prohibits AI systems that deploy subliminal techniques beyond a person's consciousness or purposefully manipulative or deceptive techniques, with the objective or effect of materially distorting behaviour causing significant harm."

severity := "critical"

remediation := "Remove any subliminal, manipulative, or deceptive techniques designed to distort user behaviour. Ensure AI interactions are transparent and do not impair informed decision-making."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
