# ComplyEdge: EU AI Act Article 50(3): Emotion Notification
#
# Deploying an emotion recognition or biometric categorisation system without
# informing the people exposed to it.
#
# Layer 1 detects: as adjacent words, "emotion recognition" or "biometric
# categorisation" (or "categorization"), optionally followed by "system", then
# without, lacking or no, then a word beginning notice, notif, disclosure or
# inform ("emotion recognition without notice"); and deploy, use or run (any
# ending) then "emotion recognition", optionally "on", then users, people or
# persons, then "without" informing, telling or notice. It matches wording,
# not meaning: it misses the practice told in other words, it fires on text
# that only names it, and it fires even where the Article 50(3) exception for
# systems permitted by law to detect, prevent or investigate criminal offences
# applies ("Under the warrant and national criminal procedure law,
# investigators may run the biometric categorisation without notice to the
# suspect."). Whether a text deploys the system without informing the people
# exposed, and whether the exception applies, is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(3)
# Recital: 132: natural persons should be notified when they are exposed to AI systems that, by processing their biometric data, can identify or infer their emotions or intentions or assign them to specific categories
# Penalty: up to EUR 15M or 3% of total worldwide annual turnover, whichever is higher (Article 99(4), point (g))
# Effective: 2026-08-02
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_50/par_3/oj
# Provision: Regulation (EU) 2024/1689, Article 50(3)

package complyedge.article50.emotion_notification

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:emotion\\s+recognition|biometric\\s+categori[sz]ation)\\s+(?:system\\s+)?\\b(?:without|lacking|no)\\s+(?:notice|notif|disclosure|inform)",
		"(?:deploy|use|run)\\w*\\s+emotion\\s+recognition\\s+(?:on\\s+)?(?:users|people|persons)\\s+without\\s+(?:informing|telling|notice)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-3-001"

citation := "Regulation (EU) 2024/1689, Article 50(3): Deployers of an emotion recognition system or a biometric categorisation system shall inform the natural persons exposed thereto of the operation of the system, and shall process the personal data in accordance with Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680, as applicable. This obligation shall not apply to AI systems used for biometric categorisation and emotion recognition, which are permitted by law to detect, prevent or investigate criminal offences, subject to appropriate safeguards for the rights and freedoms of third parties, and in accordance with Union law."
severity := "high"

remediation := "Inform natural persons when they are subject to emotion recognition or biometric categorisation."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
