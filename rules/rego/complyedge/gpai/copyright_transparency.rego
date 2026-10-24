# ComplyEdge: EU AI Act Article 53(1)(c): Copyright Policy
#
# Providers of general-purpose AI models shall put in place a policy to
# comply with Union law on copyright and related rights, including the
# reservation of rights expressed under Article 4(3) of Directive (EU)
# 2019/790.
#
# Layer 1 detects: "training data" (space, hyphen or one word), then the word
# "no", "not", "without" or "lack" (any ending), then "copyright" followed by
# disclos, polic or summar (space, hyphen or one word); the word "no",
# "not",
# "without" or "lack" (any ending), then "training data" written the same way,
# then summar; scrape or crawl, then "copyrighted" or "protected", then the
# word "no", "not" or "without", then disclos or polic; "undisclosed" or "opaque",
# then training, then corpus, dataset or data; and train, then "gpai" or
# "foundation model" (space, hyphen or one word), then the word "no", "not" or
# "without", then copyright, then compl or polic. Case is ignored, the parts
# must sit on one line in the order given with any words between them, and a
# part not called a word can start inside a longer word. It matches wording,
# not meaning: no pattern reads ignoring a reservation of rights ("We scraped
# every book on the shadow library into the training set and ignored the
# robots.txt opt-outs." does not fire), and it fires on text that denies the
# practice ("Our training data has no copyright policy gap: the policy honours
# every TDM opt-out." fires). Whether a provider lacks the Article 53(1)(c)
# policy is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(1)(c)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 105: GPAI providers must respect Union copyright law including the text-and-data-mining opt-out under Art 4(3) of Directive (EU) 2019/790; obligation applies regardless of jurisdiction where training takes place when the model is placed on the Union market (Recital 106)
# Effective: 2025-08-02 (Article 111(3): providers of general-purpose AI models placed on the market before 2 August 2025 must comply by 2 August 2027. Article 113, third paragraph, point (b), excepts Article 101, so the Commission's fines apply from 2 August 2026. The condition does not read either date)
# Penalty: Article 101(1): fines not exceeding 3 % of annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
#
# Scope note: the citation is Article 53(1)(c), the copyright policy. Two
# patterns ("no ... training data ... summar", "undisclosed ... training ...
# dataset") and the first sentence of the remediation address the
# training-content summary, which is Article 53(1)(d) (Recital 107), the duty
# of rego-art53-1d-001. No pattern tests ignoring a reservation of rights.
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_53/par_1/pnt_c/oj
# Provision: Regulation (EU) 2024/1689, Article 53(1)(c)

package complyedge.gpai.copyright_transparency

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	copyright_transparency_pattern_match
}

copyright_transparency_pattern_match if {
	patterns := [
		"training[\\-\\s]?data.*\\b(?:no|not|without|lack\\w*)\\b.*copyright[\\-\\s]?(?:disclos|polic|summar)",
		"\\b(?:no|not|without|lack\\w*)\\b.*training[\\-\\s]?data.*summar",
		"(?:scrape|crawl).*(?:copyrighted|protected).*\\b(?:no|not|without)\\b.*(?:disclos|polic)",
		"(?:undisclosed|opaque).*training.*(?:corpus|dataset|data)",
		"train.*(?:gpai|foundation[\\-\\s]?model).*\\b(?:no|not|without)\\b.*copyright.*(?:compl|polic)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53c-001"

citation := "Regulation (EU) 2024/1689, Article 53(1)(c): put in place a policy to comply with Union law on copyright and related rights, and in particular to identify and comply with, including through state-of-the-art technologies, a reservation of rights expressed pursuant to Article 4(3) of Directive (EU) 2019/790;"
severity := "high"

remediation := "Put in place a policy to comply with Union copyright law, including identifying and honouring reservations of rights expressed under Article 4(3) of Directive (EU) 2019/790."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
