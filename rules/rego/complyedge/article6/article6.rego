# ComplyEdge — EU AI Act Article 6 / Annex III: Aggregated High-Risk Classification
#
# This policy aggregates all Article 6 / Annex III sub-checks and returns a
# unified result. OPA queries this package at: POST /v1/data/complyedge/article6
#
# Aggregator carve-out (RULE_STANDARD.md §5.6): this file imports and combines
# other rules' violation results — it has no legal condition of its own. Exempt
# from §5 approval headers. Correctness derives from the sub-rules, each of
# which is individually subject to §5 sign-off (approved Leo Celis 2026-07-03
# — see sub-rule headers).
#
# Imported rules (each individually subject to §5 sign-off):
#   - article6.biometric_identification  (Annex III §1)
#   - article6.critical_infrastructure   (§2)
#   - article6.education_vocational      (§3)
#   - article6.employment_workers        (§4)
#   - article6.essential_services        (§5)
#   - article6.law_enforcement           (§6)
#   - article6.migration_asylum          (§7)
#   - article6.justice_democracy         (§8)

package complyedge.article6

import rego.v1

import data.complyedge.article6.biometric_identification
import data.complyedge.article6.critical_infrastructure
import data.complyedge.article6.education_vocational
import data.complyedge.article6.employment_workers
import data.complyedge.article6.essential_services
import data.complyedge.article6.law_enforcement
import data.complyedge.article6.migration_asylum
import data.complyedge.article6.justice_democracy

default violation := false

violation if biometric_identification.violation
violation if critical_infrastructure.violation
violation if education_vocational.violation
violation if employment_workers.violation
violation if essential_services.violation
violation if law_enforcement.violation
violation if migration_asylum.violation
violation if justice_democracy.violation

violations contains v if {
	biometric_identification.violation
	v := biometric_identification.result
}

violations contains v if {
	critical_infrastructure.violation
	v := critical_infrastructure.result
}

violations contains v if {
	education_vocational.violation
	v := education_vocational.result
}

violations contains v if {
	employment_workers.violation
	v := employment_workers.result
}

violations contains v if {
	essential_services.violation
	v := essential_services.result
}

violations contains v if {
	law_enforcement.violation
	v := law_enforcement.result
}

violations contains v if {
	migration_asylum.violation
	v := migration_asylum.result
}

violations contains v if {
	justice_democracy.violation
	v := justice_democracy.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		biometric_identification.rule_id,
		critical_infrastructure.rule_id,
		education_vocational.rule_id,
		employment_workers.rule_id,
		essential_services.rule_id,
		law_enforcement.rule_id,
		migration_asylum.rule_id,
		justice_democracy.rule_id,
	],
}
