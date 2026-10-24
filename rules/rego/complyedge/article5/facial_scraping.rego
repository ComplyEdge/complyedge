# ComplyEdge: EU AI Act Article 5(1)(e): Facial Scraping
#
# Building or expanding a facial recognition database by untargeted scraping
# of facial images from the internet or CCTV footage. Prohibited.
#
# Layer 1 detects: scraping, harvesting, crawling, bulk or mass downloading,
# or mass collecting, directly followed by facial or face images, photos,
# pictures or data ("scrape facial images", "harvesting of face photos");
# "untargeted scraping, collection or harvesting of facial" or "face"
# images; and building, expanding or creating a facial recognition database
# from or by scraping, the internet or CCTV. It matches wording, not meaning:
# it misses the practice told in other words ("pulled 2.3M profile pictures
# and added the face embeddings to our matching index"), and it fires on text
# that only names the practice, such as a refusal. Whether a text does the
# practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(e)
# Recital: 43: the practice adds to the feeling of mass surveillance and can lead to gross violations of fundamental rights, including the right to privacy
# Penalty: up to EUR 35M or 7% of total worldwide annual turnover, whichever is higher (Article 99(3))
# Effective: 2025-02-02
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_5/par_1/pnt_e/oj
# Provision: Regulation (EU) 2024/1689, Article 5(1)(e)

package complyedge.article5.facial_scraping

import rego.v1

import data.complyedge.shared.normalize

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

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1e-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(e): the placing on the market, the putting into service for this specific purpose, or the use of AI systems that create or expand facial recognition databases through the untargeted scraping of facial images from the internet or CCTV footage."
severity := "critical"

remediation := "Do not build or expand facial recognition databases via untargeted scraping of facial images from the internet or CCTV."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
