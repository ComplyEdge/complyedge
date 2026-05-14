# ComplyEdge — EU AI Act Article 50(1): Chatbot Disclosure
#
# Providers shall ensure that AI systems intended to interact directly
# with natural persons are designed and developed such that the natural
# person is informed that they are interacting with an AI system.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(1)
# Effective: 2026-08-02
# Penalty: up to €15M or 3% of global revenue

package complyedge.article50.chatbot_disclosure

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	chatbot_disclosure_pattern_match
}

chatbot_disclosure_pattern_match if {
	patterns := [
		"chatbot.*(?:no|without|lack).*disclos",
		"ai[\\- ]?assistant.*(?:no|without).*(?:disclos|inform)",
		"(?:virtual|conversational)[\\- ]?agent.*(?:no|without).*disclos",
		"(?:impersonat|pretend).*human.*(?:chat|convers)",
		"(?:hide|conceal|mask).*(?:ai|bot).*(?:identity|nature)",
		"chatbot.*(?:pose|posing).*(?:as|human)",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-1-001"

citation := "Regulation (EU) 2024/1689, Article 50(1): Providers shall ensure that AI systems intended to interact directly with natural persons inform the user that they are interacting with an AI system."

severity := "high"

remediation := "Ensure all chatbots and AI-powered conversational agents clearly disclose their AI nature to users at the start of interactions. Do not impersonate or pose as a human."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
