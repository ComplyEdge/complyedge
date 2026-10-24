# ComplyEdge: SEC Regulation FD, 17 CFR 243.100(a): selective disclosure of material nonpublic information (shipped under the SOX rule ID rego-sox-302-001)
#
# Disclosing material non-public information about a US issuer: forward-
# looking earnings or revenue guidance, an undisclosed merger or acquisition,
# or other insider information, shared selectively or outside the company's
# formal disclosure (Regulation FD).
#
# Layer 1 detects: for US end users only, as whole words in any case and
# across line breaks, expect, expects, expected, forecast, forecasts,
# forecasted, guidance, project, projects, anticipate, anticipates, target or
# targets, then within 80 characters increase, decrease, grow, decline, beat,
# exceed, impact, earnings or revenue; earnings or revenue, then within 40
# characters exceed, beat, increase or decrease; material or significant, then
# within 60 characters acquisition, merger, impact, earnings or disclosure;
# and insider, non-public, confidential or privileged, then within 60
# characters information, knowledge, merger, earnings or acquisition. It
# matches wording, not meaning: it does not read who receives the information
# or whether it is already public, so it fires on a published earnings release
# as readily as on a selective tip, and it misses a disclosure told in other
# words. Whether a text selectively discloses material nonpublic information
# is judged in Layer 2.
#
# Deterministic OPA/Rego leaf so SOX blocks on the /v1/check hot path.
# TrustLint YAML (sox_material_disclosure.yaml) still serves
# /v1/sensitivity/detect. These patterns cover the smoke strings:
# forward-looking earnings guidance, material undisclosed events, insider info.
#
# Source rule: SOX_HYBRID_MATERIAL_DISCLOSURE_001
# Legal basis: 17 CFR 243.100(a) (Regulation FD, selective disclosure)
# Effective: 2000-10-23 (Regulation FD took effect on October 23, 2000, 65 FR 51716; the us_corpus aggregator applies this leaf to US checks only)
# Provision URL: https://www.ecfr.gov/current/title-17/chapter-II/part-243/section-243.100
# Provision: 17 CFR 243.100(a) (Regulation FD)
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)

package complyedge.us_corpus.sox_material_disclosure

import rego.v1

import data.complyedge.shared.normalize

default violation := false

# "We expect revenue to increase by 25% next quarter"
violation if regex.match(`(?i)\b(?:expect(?:s|ed)?|forecast(?:s|ed)?|guidance|projects?|anticipates?|targets?)\b[\s\S]{0,80}\b(?:increase|decrease|grow|decline|beat|exceed|impact|earnings|revenue)\b`, normalize.text)

# "Our earnings will exceed analyst estimates by a significant margin"
violation if regex.match(`(?i)\b(?:earnings|revenue)\b[\s\S]{0,40}\b(?:exceed|beat|increase|decrease)\b`, normalize.text)

# "This material acquisition will significantly impact our earnings"
violation if regex.match(`(?i)\b(?:material|significant)\b[\s\S]{0,60}\b(?:acquisition|merger|impact|earnings|disclosure)\b`, normalize.text)

# "I have insider knowledge about the upcoming merger announcement"
violation if regex.match(`(?i)\b(?:insider|non-public|confidential|privileged)\b[\s\S]{0,60}\b(?:information|knowledge|merger|earnings|acquisition)\b`, normalize.text)

rule_id := "rego-sox-302-001"

citation := "17 CFR 243.100(a) (Regulation FD): Whenever an issuer, or any person acting on its behalf, discloses any material nonpublic information regarding that issuer or its securities to any person described in paragraph (b)(1) of this section, the issuer shall make public disclosure of that information as provided in § 243.101(e): (1) Simultaneously, in the case of an intentional disclosure; and (2) Promptly, in the case of a non-intentional disclosure."

severity := "critical"

remediation := "Do not share material nonpublic information, such as unreleased earnings guidance or an unannounced merger, with analysts, investment professionals or securities holders (17 CFR 243.100(b)(1)) unless the issuer makes it public at the same time, by Form 8-K or another broad, non-exclusionary method (17 CFR 243.101(e)). Route the draft to Legal / IR."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
