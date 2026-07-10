# ComplyEdge — article5 new-rule tests (card M3.3-T2)
# Run with: opa test rules/rego/ -v

package complyedge.article5_m33_test

import rego.v1

import data.complyedge.article5.facial_scraping
import data.complyedge.article5

test_facial_scraping_blocks if {
	facial_scraping.violation with input as {"jurisdiction": "EU", "text": "We scrape facial images from the internet to build a facial recognition database"}
}

test_facial_scraping_allows_clean if {
	not facial_scraping.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}

test_facial_scraping_allows_non_eu if {
	not facial_scraping.violation with input as {"jurisdiction": "US", "text": "We scrape facial images from the internet to build a facial recognition database"}
}

test_article5_aggregator_fires if {
	article5.violation with input as {"jurisdiction": "EU", "text": "We scrape facial images from the internet to build a facial recognition database"}
}

test_article5_aggregator_clean if {
	not article5.violation with input as {"jurisdiction": "EU", "text": "Our assistant summarises customer support tickets and drafts helpful replies."}
}
