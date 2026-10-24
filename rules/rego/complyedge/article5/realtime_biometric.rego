# ComplyEdge: EU AI Act Article 5(1)(h): Real-time Biometric Identification
#
# Prohibits the use of real-time remote biometric identification systems
# in publicly accessible spaces for law enforcement purposes, subject to
# narrowly defined exceptions.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(h)
# Citation corrected 2026-10-21 to quote the Official Journal word for word; provision and condition unchanged.
# Recital: 32: prohibits real-time remote biometric identification in publicly accessible spaces for law enforcement; recitals 33-35 cover the narrowly-defined exceptions (targeted search, imminent threat, serious crime) and the judicial/independent-authority authorisation requirement
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-05-16 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_5/par_1/pnt_h/oj
# Provision: Regulation (EU) 2024/1689, Article 5(1)(h)

package complyedge.article5.realtime_biometric

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	realtime_biometric_pattern_match
}

realtime_biometric_pattern_match if {
	patterns := [
		"real[\\-\\s]?time[\\-\\s]?biometric",
		"live[\\-\\s]?facial[\\-\\s]?recognition",
		"mass[\\-\\s]?facial[\\-\\s]?recognition",
		"public[\\-\\s]?space[\\-\\s]?biometric",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1h-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(h): the use of 'real-time' remote biometric identification systems in publicly accessible spaces for the purposes of law enforcement, unless and in so far as such use is strictly necessary for one of the following objectives: (i) the targeted search for specific victims of abduction, trafficking in human beings or sexual exploitation of human beings, as well as the search for missing persons; (ii) the prevention of a specific, substantial and imminent threat to the life or physical safety of natural persons or a genuine and present or genuine and foreseeable threat of a terrorist attack; (iii) the localisation or identification of a person suspected of having committed a criminal offence, for the purpose of conducting a criminal investigation or prosecution or executing a criminal penalty for offences referred to in Annex II and punishable in the Member State concerned by a custodial sentence or a detention order for a maximum period of at least four years."
severity := "critical"

remediation := "Remove real-time remote biometric identification from publicly accessible spaces. If the use falls under one of the Article 5(1)(h) objectives, obtain the prior authorisation of a judicial authority or an independent administrative authority that Article 5(3) requires, and document the lawful basis."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
