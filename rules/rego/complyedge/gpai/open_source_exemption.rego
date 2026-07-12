# ComplyEdge — EU AI Act Article 53(2): Open-Source GPAI Exemption Boundary
#
# Providers of GPAI models released under a free and open-source licence with
# publicly available parameters (weights, architecture, usage information) are
# exempt from Article 53(1)(a) and (b) only when the model does not present a
# systemic risk. Claiming the carve-out while withholding parameters, or while
# the model is systemic-risk, is a documentation/transparency failure.
#
# Legal citation: Regulation (EU) 2024/1689, Article 53(2)
# Recital: 104–107 — open-source release can reduce documentation burden for
#   non-systemic-risk models; systemic-risk models remain fully obligated
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-11 (via agent review per RULE_STANDARD §5.1; card M3.3-T3)

package complyedge.gpai.open_source_exemption

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"open[\\- ]?source.*(?:gpai|foundation[\\- ]?model).*(?:exempt|exemption|carve[\\- ]?out).*(?:without|no|lack).*(?:weight|parameter|architecture)",
		"(?:claim|assert|invoke).*53\\(2\\).*(?:systemic[\\- ]?risk|sr[\\- ]?model)",
		"open[\\- ]?source.*(?:exempt|exemption).*53.*(?:systemic[\\- ]?risk|without.*public.*weight)",
		"(?:gpai|foundation[\\- ]?model).*closed[\\- ]?weight.*(?:claim|assert).*open[\\- ]?source.*exempt",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-gpai-53-2-001"

citation := "Regulation (EU) 2024/1689, Article 53(2): Open-source GPAI models with publicly available parameters are exempt from Article 53(1)(a)–(b) only if they do not present a systemic risk."

severity := "high"

remediation := "Do not claim the Article 53(2) open-source exemption unless weights, architecture, and usage information are publicly available and the model is not systemic-risk. Systemic-risk GPAI remains fully subject to Article 53(1)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
