# ComplyEdge: EU AI Act Article 16: Provider Obligations
#
# Placing a high-risk AI system on the EU market or putting it into service
# without CE marking, conformity assessment, an EU declaration of conformity
# or registration.
#
# Layer 1 detects: a word starting "place", "placing", "sell", "deploy",
# "launch" or "release", then "high-risk AI" with no word between, then "on
# the EU market", "on EU market", "in the Union" or "in Union", then "without"
# or "lacking", then "CE marking", "conformity assessment" or "registration";
# and "high-risk AI" then "without" or "no" then "CE marking", "conformity
# assessment" or "EU declaration". It matches wording, not meaning: it misses
# the practice told in other words (a launch plan that never says "high-risk
# AI"), and it fires on text that only names the practice, such as a refusal.
# Whether a text does the practice is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 16, points (f) to (i)
# Effective: 2027-12-02 (Annex III high-risk systems; 2 August 2028 for high-risk systems under Annex I, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read either date)
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_16/oj
# Provision: Regulation (EU) 2024/1689, Article 16, points (f) to (i)

package complyedge.highrisk.art16_provider_obligations

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:place|placing|sell|deploy|launch|release)\\w*\\s+high[\\-\\s]?risk\\s+ai\\s+(?:on\\s+(?:the\\s+)?eu\\s+market|in\\s+(?:the\\s+)?union)\\s+(?:without|lacking)\\s+(?:ce\\s+marking|conformity\\s+assessment|registration)",
		"high[\\-\\s]?risk\\s+ai\\s+(?:without|no)\\s+(?:ce\\s+marking|conformity\\s+assessment|eu\\s+declaration)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art16-001"

citation := "Regulation (EU) 2024/1689, Article 16(f): ensure that the high-risk AI system undergoes the relevant conformity assessment procedure as referred to in Article 43, prior to its being placed on the market or put into service; Article 16(g): draw up an EU declaration of conformity in accordance with Article 47; Article 16(h): affix the CE marking to the high-risk AI system or, where that is not possible, on its packaging or its accompanying documentation, to indicate conformity with this Regulation, in accordance with Article 48; Article 16(i): comply with the registration obligations referred to in Article 49(1);"
severity := "high"

remediation := "Complete conformity assessment, CE marking, and EU registration before market placement. Readiness check, not yet a binding obligation: Article 16 applies from 2 December 2027 for Annex III high-risk systems and from 2 August 2028 for high-risk systems under Annex I (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
