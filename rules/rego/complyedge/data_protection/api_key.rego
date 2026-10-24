# ComplyEdge - GDPR Article 32(1): API key or bearer token in AI text
#
# The text carries a live credential in a vendor's published key format: AWS
# access key id (AKIA/ASIA + 16), GitHub token (ghp_/gho_/ghu_/ghs_/ghr_ + 36,
# github_pat_), OpenAI (sk- / sk-proj-), Anthropic (sk-ant-), Stripe live keys
# (sk_live_ / rk_live_), Slack (xoxb-/xoxp-/xoxa-/xoxr-/xoxs-), Google API key
# (AIza + 35), a JSON Web Token (three base64url segments starting eyJ), or an
# "Authorization: Bearer" header with a 20+ character token. Stripe TEST keys,
# AWS's documented example key (ending EXAMPLE), the key id inside a presigned
# S3 URL, and a JWT that is a URL query value (a magic link addressed to its
# recipient) do not fire.
#
# Layer 1 detects: AKIA or ASIA then 16 capitals or digits (not after
# AWSAccessKeyId= or Credential=); ghp_, gho_, ghu_, ghs_ or ghr_ then 36
# letters or digits; github_pat_ then 50 or more; sk-, sk-proj- or
# sk-ant-<letters or digits>- then 20 or more letters, digits, _ or -;
# sk_live_ or rk_live_ then 16 or more; xoxb-, xoxp-, xoxa-, xoxr- or xoxs-
# then 10 or more; AIza then 35; three dot-separated segments of at least 8
# base64url characters, the first two starting eyJ, not directly after = (a
# URL query value); and "Authorization: Bearer" in any case then a token of 20
# or more characters. Any match ending EXAMPLE does not fire. It matches
# formats, not purpose: a credential in a format not named here is missed (a
# HubSpot private app token, pat-eu1- and so on), and it does not read why the
# value is in the text. No model reviews a hit: a match keeps the block in
# Layer 2 as well.
#
# Legal citation: Regulation (EU) 2016/679 (GDPR), Article 32(1)(b)
# Recital: 83 - the controller should implement measures to mitigate risks inherent in the processing
# Effective: 2018-05-25
# Penalty: GDPR Article 83(4)(a): up to EUR 10,000,000 or 2% of worldwide annual turnover
# Condition type: deterministic (format match only, no checksum exists for these values; no judgment of meaning)
# Enforcement layer: layer1
# Direction: every check (prompt before the model, output before the user)
# Record: the decision stores the rule, never the matched value or the text
# ELI: http://data.europa.eu/eli/reg/2016/679/art_32/par_1/pnt_b/oj
# Provision: Regulation (EU) 2016/679, Article 32(1)(b)

# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.data_protection.api_key

import rego.v1

import data.complyedge.shared.normalize

default violation := false

_patterns := [
	`(?:^|[^A-Za-z0-9])(?:AWSAccessKeyId=|Credential=)?((?:AKIA|ASIA)[0-9A-Z]{16})(?:$|[^A-Za-z0-9])`,
	`(?:^|[^A-Za-z0-9_])(gh[pousr]_[A-Za-z0-9]{36})(?:$|[^A-Za-z0-9])`,
	`(?:^|[^A-Za-z0-9_])(github_pat_[A-Za-z0-9_]{50,})`,
	`(?:^|[^A-Za-z0-9_-])(sk-(?:proj-|ant-[a-z0-9]+-)?[A-Za-z0-9_-]{20,})`,
	`(?:^|[^A-Za-z0-9_])((?:sk|rk)_live_[A-Za-z0-9]{16,})`,
	`(?:^|[^A-Za-z0-9])(xox[bpars]-[A-Za-z0-9-]{10,})`,
	`(?:^|[^A-Za-z0-9])(AIza[0-9A-Za-z_-]{35})(?:$|[^0-9A-Za-z_-])`,
	`(?:^|[^A-Za-z0-9_=-])(eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})`,
	`(?i)(?:authorization\s*:\s*bearer\s+)([A-Za-z0-9._~+/=-]{20,})`,
]

violation if {
	input.jurisdiction == "EU"
	some p in _patterns
	some m in regex.find_all_string_submatch_n(p, normalize.text, -1)
	not endswith(m[1], "EXAMPLE")
	not _presigned_url_param(m[0])
}

# An access key id in a presigned URL (AWSAccessKeyId= / X-Amz-Credential=) is
# public by design: the URL's signature is the time-limited secret, and the
# id alone grants nothing.
_presigned_url_param(match) if contains(match, "AWSAccessKeyId=")

_presigned_url_param(match) if contains(match, "Credential=")

rule_id := "rego-gdpr32-1-001"

citation := "Regulation (EU) 2016/679 (GDPR), Article 32(1)(b): \"the controller and the processor shall implement appropriate technical and organisational measures to ensure a level of security appropriate to the risk, including inter alia as appropriate: [...] (b) the ability to ensure the ongoing confidentiality, integrity, availability and resilience of processing systems and services\"."

severity := "critical"

remediation := "Block the request: it contains an API key or access token. Revoke and rotate the credential, and never send credentials to an AI model."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
