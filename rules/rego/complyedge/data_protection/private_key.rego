# ComplyEdge - GDPR Article 32(1): private key in AI text
#
# The text carries a PEM private key block header (five dashes, BEGIN, the key type, PRIVATE KEY, five dashes),
# or the RSA / EC / DSA / OPENSSH / ENCRYPTED variants, or a PGP PRIVATE KEY
# BLOCK. Public keys and certificates (BEGIN PUBLIC KEY, BEGIN CERTIFICATE)
# do not fire.
#
# Layer 1 detects: the line BEGIN PRIVATE KEY with five dashes on each side, the same with RSA,
# EC, DSA, OPENSSH or ENCRYPTED before PRIVATE KEY, or -----BEGIN PGP PRIVATE
# KEY BLOCK-----, in capitals as written. It matches formats, not purpose: a
# credential in a format not named here is missed (a PuTTY key file,
# PuTTY-User-Key-File-3 with its Private-Lines), and it does not read why the
# value is in the text. No model reviews a hit: a match keeps the block in
# Layer 2 as well.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 32(1)(b)
# Recital: 83 - the controller should implement measures to mitigate risks inherent in the processing
# Effective: 2018-05-25
# Penalty: GDPR Article 83(4)(a): up to EUR 10,000,000 or 2% of worldwide annual turnover
# Condition type: deterministic (format match only, no checksum exists for this value; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# ELI: http://data.europa.eu/eli/reg/2016/679/art_32/par_1/pnt_b/oj
# Provision: Regulation (EU) 2016/679, Article 32(1)(b)
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.data_protection.private_key

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	regex.match(`-----BEGIN (?:(?:RSA|EC|DSA|OPENSSH|ENCRYPTED) )?PRIVATE KEY-----|-----BEGIN PGP PRIVATE KEY BLOCK-----`, normalize.text)
}

rule_id := "rego-gdpr32-1-002"

citation := "Regulation (EU) 2016/679 (GDPR), Article 32(1)(b): \"the controller and the processor shall implement appropriate technical and organisational measures to ensure a level of security appropriate to the risk, including inter alia as appropriate: [...] (b) the ability to ensure the ongoing confidentiality, integrity, availability and resilience of processing systems and services\"."

severity := "critical"

remediation := "Block the request: it contains a private key. Treat the key as exposed, replace it, and never send keys to an AI model."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
