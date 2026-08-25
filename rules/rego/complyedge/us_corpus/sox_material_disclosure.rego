# ComplyEdge — SOX material disclosure / forward-looking earnings
#
# Deterministic OPA/Rego leaf so SOX blocks on the /v1/check hot path.
# TrustLint YAML (sox_material_disclosure.yaml) still serves
# /v1/sensitivity/detect. These patterns cover the smoke strings:
# forward-looking earnings guidance, material undisclosed events, insider info.
#
# Source rule: SOX_HYBRID_MATERIAL_DISCLOSURE_001
# Legal basis: 15 U.S.C. § 7241 (SOX 302), Regulation FD
# Effective: US

package complyedge.us_corpus.sox_material_disclosure

import rego.v1

default violation := false

# "We expect revenue to increase by 25% next quarter"
violation if regex.match(`(?i)\b(?:expect(?:s|ed)?|forecast(?:s|ed)?|guidance|projects?|anticipates?|targets?)\b[\s\S]{0,80}\b(?:increase|decrease|grow|decline|beat|exceed|impact|earnings|revenue)\b`, input.text)

# "Our earnings will exceed analyst estimates by a significant margin"
violation if regex.match(`(?i)\b(?:earnings|revenue)\b[\s\S]{0,40}\b(?:exceed|beat|increase|decrease)\b`, input.text)

# "This material acquisition will significantly impact our earnings"
violation if regex.match(`(?i)\b(?:material|significant)\b[\s\S]{0,60}\b(?:acquisition|merger|impact|earnings|disclosure)\b`, input.text)

# "I have insider knowledge about the upcoming merger announcement"
violation if regex.match(`(?i)\b(?:insider|non-public|confidential|privileged)\b[\s\S]{0,60}\b(?:information|knowledge|merger|earnings|acquisition)\b`, input.text)

rule_id := "rego-sox-302-001"

citation := "15 U.S.C. § 7241 (SOX §302) and Regulation FD: material non-public information and forward-looking earnings guidance must not be disclosed selectively."

severity := "critical"

remediation := "Do not disclose material non-public financial information or forward-looking earnings guidance. Direct the speaker to Legal / IR and to an 8-K if the event is material."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
