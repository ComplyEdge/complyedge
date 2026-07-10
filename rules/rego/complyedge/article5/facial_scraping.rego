# ComplyEdge — EU AI Act Article 5(1)(e): Facial Scraping
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(e)
# Effective: 2025-02-02 (prohibited) / 2026-08-02 (high-risk & GPAI)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-09 (agent authoring, card M3.3-T2)

package complyedge.article5.facial_scraping

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:scrap|harvest|crawl|bulk[\\-\\s]?download|mass[\\-\\s]?(?:download|collect))\\w*\\s+(?:of\\s+)?(?:facial|face)\\s+(?:image|photo|picture|data)",
		"untargeted\\s+(?:scraping|collection|harvesting)\\s+of\\s+(?:facial|face)",
		"(?:build|expand|create)\\w*\\s+(?:a\\s+)?facial\\s+recognition\\s+database\\s+(?:from|by)\\s+(?:scraping|internet|cctv)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1e-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(e): Prohibits the creation or expansion of facial recognition databases through the untargeted scraping of facial images from the internet or CCTV footage."

severity := "critical"

remediation := "Do not build or expand facial recognition databases via untargeted scraping of facial images from the internet or CCTV."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
