# ComplyEdge — EU AI Act Article 50(5): Transparency Information at First Exposure
#
# The information required under Article 50 paragraphs 1 to 4 shall be
# provided to natural persons in a clear and distinguishable manner at
# the latest at the time of first interaction or exposure, conforming to
# applicable accessibility requirements. For marked synthetic content,
# detection methods must be available when persons are first exposed.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50, paragraph 5
# Recital: 136 — transparency information must be clear, distinguishable, and accessible at first interaction or exposure
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Card checklist describes Art 50(2) GPAI machine-detectable
# marking (see gpai_content_disclosure.rego rego-art50-2-001). Art 50(5)
# requires Art 50(1)-(4) information — including detection means for
# marked content — be delivered clearly at first interaction/exposure.

package complyedge.article50.provider_transparency_tools

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	provider_transparency_tools_pattern_match
}

provider_transparency_tools_pattern_match if {
	patterns := [
		"(?:without|no|delay|defer|hide|after).*(?:first[\\- ]?(?:interaction|exposure|contact|use)).*(?:disclos|inform|transparency|notice|label)",
		"(?:disclos|inform|transparency|notice|label).*(?:after|later|delayed|deferred).*(?:first[\\- ]?(?:interaction|exposure|use)|user[\\- ]?sees|playback)",
		"(?:not|without)[\\- ]+(?:clear|distinguish|accessible).*(?:disclos|inform|transparency|notice).*(?:first[\\- ]?(?:interaction|exposure)|ai[\\- ]?system|users?|persons?)?",
		"(?:unclear|hidden|inaccessible|buried).*(?:transparency|disclos|ai[\\- ]?(?:notice|label|generated)).*(?:first[\\- ]?(?:interaction|exposure)|users?|persons?)?",
		"(?:without|no|fail(?:ing|ure)?[\\- ]?to)[\\- ]+(?:provide|offer|make[\\- ]?available).*(?:detection[\\- ]?(?:tool|method|means)|marking[\\- ]?(?:tool|solution)|transparency[\\- ]?tool).*(?:gpai|general[\\- ]?purpose|synthetic|ai[\\- ]?generated|first[\\- ]?exposure)?",
		"(?:gpai|general[\\- ]?purpose).*(?:without|no).*(?:detection[\\- ]?(?:tool|method)|marking[\\- ]?solution|machine[\\- ]?readable).*(?:downstream|provider|exposure|content)?",
		"(?:machine[\\- ]?readable|ai[\\- ]?generated).*(?:not[\\- ]?detectable|undetectable).*(?:without|no).*(?:detection[\\- ]?(?:tool|method)|transparency[\\- ]?tool)",
		"(?:skip|omit|bypass).*(?:first[\\- ]?(?:interaction|exposure)).*(?:disclos|inform|transparency|accessibility)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-5-001"

citation := "Regulation (EU) 2024/1689, Article 50, paragraph 5: The information referred to in paragraphs 1 to 4 shall be provided to natural persons in a clear and distinguishable manner at the latest at the time of first interaction or exposure, and shall conform to applicable accessibility requirements."

severity := "high"

remediation := "Provide Art 50(1)-(4) transparency information clearly and distinguishably at first interaction or content exposure. Make detection methods for machine-readable marks available when content is exposed; ensure notices meet accessibility requirements."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
