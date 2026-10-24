# ComplyEdge: EU AI Act Article 50(1): Chatbot Disclosure
#
# Providers shall ensure that AI systems intended to interact directly
# with natural persons are designed and developed such that the natural
# person is informed that they are interacting with an AI system.
#
# Layer 1 detects: "chatbot", then the word "no", "not", "without" or "lack" (any
# ending), then disclos (any ending); the word "ai" followed by "assistant"
# (with a space, a hyphen or nothing between), then the word "no", "not" or
# "without", then disclos or inform; "virtual agent" or "conversational agent"
# (space, hyphen or one word), then the word "no", "not" or "without", then disclos;
# impersonat or pretend, then "human", then chat or convers; the word hide,
# conceal or mask, then the word "ai" or a word ending in "bot" or "bots",
# then the word "identity" or "nature"; and "chatbot", then the word pose,
# poses, posed or posing, then the word "as" or "human". Case is ignored, the
# parts must sit on one line in the order given with any words between them,
# and a part not called a word can start inside a longer word. It matches
# wording, not meaning: it misses a system that claims to be a person in other
# words ("No, I'm not a bot, I'm a real person here to help you with your
# order." does not fire), and it fires on text that only names the practice,
# such as a refusal ("Our chatbot never poses as a human." fires). Whether a
# text deploys an AI system without telling people they are interacting with
# one is judged in Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 50(1)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 132: AI systems that interact directly with natural persons pose risks of impersonation/deception; providers must ensure users are informed they are interacting with AI, with heightened attention to vulnerable users (age, disability)
# Effective: 2026-08-02
# Penalty: up to EUR 15 000 000 or, for an undertaking, up to 3 % of total worldwide annual turnover for the preceding financial year, whichever is higher (Article 99(4)); for SMEs, whichever is lower (Article 99(6))
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_50/par_1/oj
# Provision: Regulation (EU) 2024/1689, Article 50(1)

package complyedge.article50.chatbot_disclosure

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	chatbot_disclosure_pattern_match
}

chatbot_disclosure_pattern_match if {
	patterns := [
		"chatbot.*\\b(?:no|not|without|lack\\w*)\\b.*disclos",
		"\\bai[\\-\\s]?assistant.*\\b(?:no|not|without)\\b.*(?:disclos|inform)",
		"(?:virtual|conversational)[\\-\\s]?agent.*\\b(?:no|not|without)\\b.*disclos",
		"(?:impersonat|pretend).*human.*(?:chat|convers)",
		# Whole words only. Unbounded, "ai" matched inside an S3 access key
		# (AKIAI... or ASIAI...) and "nature" inside "Signature=", so any agent reply that
		# said "mask" before a presigned image URL was blocked as Art 50(1).
		"\\b(?:hide|conceal|mask).*\\b(?:ai|\\w*bots?)\\b.*\\b(?:identity|nature)\\b",
		# "pose" matched inside "purpose" and "as" inside "has".
		"chatbot.*\\b(?:pose[sd]?|posing)\\b.*\\b(?:as|human)\\b",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art50-1-001"

citation := "Regulation (EU) 2024/1689, Article 50(1): Providers shall ensure that AI systems intended to interact directly with natural persons are designed and developed in such a way that the natural persons concerned are informed that they are interacting with an AI system, unless this is obvious from the point of view of a natural person who is reasonably well-informed, observant and circumspect, taking into account the circumstances and the context of use. This obligation shall not apply to AI systems authorised by law to detect, prevent, investigate or prosecute criminal offences, subject to appropriate safeguards for the rights and freedoms of third parties, unless those systems are available for the public to report a criminal offence."
severity := "high"

remediation := "Ensure all chatbots and AI-powered conversational agents clearly disclose their AI nature to users at the start of interactions. Do not impersonate or pose as a human."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
