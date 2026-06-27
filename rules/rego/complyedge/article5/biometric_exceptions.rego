# ComplyEdge — EU AI Act Article 5(1)(e): Untargeted Facial Image Scraping
#
# Prohibits the placing on the market, putting into service for this specific
# purpose, or the use of AI systems that create or expand facial recognition
# databases through the untargeted scraping of facial images from the internet
# or CCTV footage.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(e)
# Recital: 43 — indiscriminate scraping of facial images from the internet or CCTV to build facial recognition databases is prohibited as a high-risk prohibited practice
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-06-27 (via agent review per §5.5)
#
# Scope note: Card item described "law enforcement exceptions for real-time
# remote biometric ID" — that is Art 5(1)(h) with Arts 5(2)-(7). Adopted
# Art 5(1)(e) is untargeted facial-image scraping to create/expand FR databases.
# Filename biometric_exceptions.rego follows card checklist.

package complyedge.article5.biometric_exceptions

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	biometric_exceptions_pattern_match
}

biometric_exceptions_pattern_match if {
	patterns := [
		"(?:scrape|scraping|harvest|harvesting|crawl|crawling|bulk[\\- ]?download|mass[\\- ]?collect).*(?:facial|face).*(?:image|photo|picture|data|recognition)",
		"(?:facial|face).*(?:image|photo|picture|recognition).*(?:database|dataset).*(?:from|using|via).*(?:scraping|harvesting|crawling|untargeted|internet|cctv)",
		"(?:untargeted|indiscriminate|bulk|mass).*(?:collection|gathering|acquisition).*(?:facial|face).*(?:image|data|recognition)",
		"(?:create|build|expand|grow|populate).*(?:facial|face).*(?:recognition|database|dataset).*(?:from|via|using|by).*(?:scraping|internet|cctv|untargeted|web)",
		"(?:internet|web|cctv).*(?:scrape|scraping|crawl|harvest).*(?:facial|face).*(?:recognition|database|dataset)",
		"(?:clearview|pimeyes)[\\- ]?(?:style|like|approach).*(?:facial|face).*(?:database|recognition)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1e-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(e): Prohibits the placing on the market, putting into service for this specific purpose, or the use of AI systems that create or expand facial recognition databases through the untargeted scraping of facial images from the internet or CCTV footage."

severity := "critical"

remediation := "Do not create or expand facial recognition databases by untargeted scraping of facial images from the internet or CCTV. Use only lawfully obtained, targeted datasets with a valid legal basis and documented provenance."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
