# ComplyEdge - GDPR Article 32(1): private key in AI text
#
# The text carries a PEM private key block header (five dashes, BEGIN, the key type, PRIVATE KEY, five dashes),
# or the RSA / EC / DSA / OPENSSH / ENCRYPTED variants, or a PGP PRIVATE KEY
# BLOCK. Public keys and certificates (BEGIN PUBLIC KEY, BEGIN CERTIFICATE)
# do not fire.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 32(1)
# Recital: 83 - the controller should implement measures to mitigate risks inherent in the processing
# Effective: 2018-05-25
# Penalty: GDPR Article 83(4)(a): up to EUR 10,000,000 or 2% of worldwide annual turnover
# Condition type: deterministic (format match plus checksum; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# Status: review
# Approved by: pending Leo Celis review per RULE_STANDARD 5.5 (authorized 2026-10-10)

package complyedge.data_protection.private_key

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	regex.match(`-----BEGIN (?:(?:RSA|EC|DSA|OPENSSH|ENCRYPTED) )?PRIVATE KEY-----|-----BEGIN PGP PRIVATE KEY BLOCK-----`, input.text)
}

rule_id := "rego-gdpr32-1-002"

citation := "Regulation (EU) 2016/679 (GDPR), Article 32(1): the controller and the processor must implement appropriate technical and organisational measures to ensure security appropriate to the risk. A credential sent to an AI model or returned to a user is a credential disclosed outside the systems it protects."

severity := "critical"

remediation := "Block the request: it contains a private key. Treat the key as exposed, replace it, and never send keys to an AI model."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
