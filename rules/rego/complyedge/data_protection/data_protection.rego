# ComplyEdge - Data protection: aggregated check
#
# Aggregates the data_protection leaves (personal data and credentials in the
# text sent to, or returned from, an AI model) and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/data_protection/result
# Aggregator carve-out (RULE_STANDARD.md 5.6): no legal condition of its own.
#
# Imported rules (each individually subject to §5 sign-off):
#   - data_protection.api_key         (rego-gdpr32-1-001)
#   - data_protection.card_pan        (rego-gdpr5-1c-004)
#   - data_protection.email           (rego-gdpr5-1c-001)
#   - data_protection.iban            (rego-gdpr5-1c-003)
#   - data_protection.national_id_de  (rego-gdpr5-1c-005)
#   - data_protection.national_id_es  (rego-gdpr5-1c-007)
#   - data_protection.national_id_fr  (rego-gdpr5-1c-006)
#   - data_protection.national_id_it  (rego-gdpr5-1c-009)
#   - data_protection.national_id_nl  (rego-gdpr5-1c-008)
#   - data_protection.phone           (rego-gdpr5-1c-002)
#   - data_protection.private_key     (rego-gdpr32-1-002)

package complyedge.data_protection

import rego.v1

import data.complyedge.data_protection.api_key
import data.complyedge.data_protection.card_pan
import data.complyedge.data_protection.email
import data.complyedge.data_protection.iban
import data.complyedge.data_protection.national_id_de
import data.complyedge.data_protection.national_id_es
import data.complyedge.data_protection.national_id_fr
import data.complyedge.data_protection.national_id_it
import data.complyedge.data_protection.national_id_nl
import data.complyedge.data_protection.phone
import data.complyedge.data_protection.private_key

default violation := false

violation if email.violation
violation if phone.violation
violation if iban.violation
violation if card_pan.violation
violation if national_id_de.violation
violation if national_id_fr.violation
violation if national_id_es.violation
violation if national_id_nl.violation
violation if national_id_it.violation
violation if api_key.violation
violation if private_key.violation

violations contains v if {
	email.violation
	v := email.result
}

violations contains v if {
	phone.violation
	v := phone.result
}

violations contains v if {
	iban.violation
	v := iban.result
}

violations contains v if {
	card_pan.violation
	v := card_pan.result
}

violations contains v if {
	national_id_de.violation
	v := national_id_de.result
}

violations contains v if {
	national_id_fr.violation
	v := national_id_fr.result
}

violations contains v if {
	national_id_es.violation
	v := national_id_es.result
}

violations contains v if {
	national_id_nl.violation
	v := national_id_nl.result
}

violations contains v if {
	national_id_it.violation
	v := national_id_it.result
}

violations contains v if {
	api_key.violation
	v := api_key.result
}

violations contains v if {
	private_key.violation
	v := private_key.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		email.rule_id,
		phone.rule_id,
		iban.rule_id,
		card_pan.rule_id,
		national_id_de.rule_id,
		national_id_fr.rule_id,
		national_id_es.rule_id,
		national_id_nl.rule_id,
		national_id_it.rule_id,
		api_key.rule_id,
		private_key.rule_id,
	],
}
