# ComplyEdge — Article 6 / Annex III Rego Tests
# Run with: opa test rules/rego/ -v
#
# Covers each of the 8 Annex III sub-rules + the aggregator. Per sub-rule:
# one positive case that should trip the regex, one positive case that
# proves coverage of a second pattern variant, and one negative case
# (non-EU jurisdiction or innocuous text) that should NOT trip.

package complyedge.article6_test

import rego.v1

import data.complyedge.article6
import data.complyedge.article6.biometric_identification
import data.complyedge.article6.critical_infrastructure
import data.complyedge.article6.education_vocational
import data.complyedge.article6.employment_workers
import data.complyedge.article6.essential_services
import data.complyedge.article6.justice_democracy
import data.complyedge.article6.law_enforcement
import data.complyedge.article6.migration_asylum

# ============================================================
# Annex III §1 — Biometric Identification
# ============================================================

test_biometric_identification_blocks_facial_recognition_system if {
	biometric_identification.violation with input as {
		"jurisdiction": "EU",
		"text": "Our product is a facial recognition system for airport gates",
	}
}

test_biometric_identification_blocks_gait_analysis if {
	biometric_identification.violation with input as {
		"jurisdiction": "EU",
		"text": "We deploy a gait analysis AI for identity verification",
	}
}

test_biometric_identification_allows_non_eu if {
	not biometric_identification.violation with input as {
		"jurisdiction": "US",
		"text": "Our product is a facial recognition system",
	}
}

# ============================================================
# Annex III §2 — Critical Infrastructure
# ============================================================

test_critical_infrastructure_blocks_power_grid_ai if {
	critical_infrastructure.violation with input as {
		"jurisdiction": "EU",
		"text": "AI system manages the national power grid load balancing",
	}
}

test_critical_infrastructure_blocks_smart_grid_ai if {
	critical_infrastructure.violation with input as {
		"jurisdiction": "EU",
		"text": "Our smart grid AI control optimization platform",
	}
}

test_critical_infrastructure_allows_unrelated if {
	not critical_infrastructure.violation with input as {
		"jurisdiction": "EU",
		"text": "Our SaaS platform helps companies track invoices",
	}
}

# ============================================================
# Annex III §3 — Education and Vocational Training
# ============================================================

test_education_blocks_admissions_ai if {
	education_vocational.violation with input as {
		"jurisdiction": "EU",
		"text": "AI determines student admission decisions for our university",
	}
}

test_education_blocks_automated_grading if {
	education_vocational.violation with input as {
		"jurisdiction": "EU",
		"text": "Our automated grading system assesses exam scoring",
	}
}

test_education_allows_unrelated if {
	not education_vocational.violation with input as {
		"jurisdiction": "EU",
		"text": "Customer support chatbot",
	}
}

# ============================================================
# Annex III §4 — Employment and Workers
# ============================================================

test_employment_blocks_cv_screening if {
	employment_workers.violation with input as {
		"jurisdiction": "EU",
		"text": "AI for resume screening to filter job candidates",
	}
}

test_employment_blocks_performance_evaluation if {
	employment_workers.violation with input as {
		"jurisdiction": "EU",
		"text": "AI handles performance evaluation and promotion decision",
	}
}

test_employment_allows_non_eu if {
	not employment_workers.violation with input as {
		"jurisdiction": "US",
		"text": "AI for recruitment and hiring",
	}
}

# ============================================================
# Annex III §5 — Essential Services
# ============================================================

test_essential_services_blocks_credit_scoring if {
	essential_services.violation with input as {
		"jurisdiction": "EU",
		"text": "AI based credit scoring system for loan decision",
	}
}

test_essential_services_blocks_insurance_underwriting if {
	essential_services.violation with input as {
		"jurisdiction": "EU",
		"text": "Automated insurance pricing AI underwriting",
	}
}

test_essential_services_allows_unrelated if {
	not essential_services.violation with input as {
		"jurisdiction": "EU",
		"text": "Marketing analytics dashboard",
	}
}

# ============================================================
# Annex III §6 — Law Enforcement
# ============================================================

test_law_enforcement_blocks_predictive_policing if {
	law_enforcement.violation with input as {
		"jurisdiction": "EU",
		"text": "Our AI does predictive policing for European city forces",
	}
}

test_law_enforcement_blocks_lie_detection if {
	law_enforcement.violation with input as {
		"jurisdiction": "EU",
		"text": "AI polygraph and lie detect interrogation assistant",
	}
}

test_law_enforcement_allows_unrelated if {
	not law_enforcement.violation with input as {
		"jurisdiction": "EU",
		"text": "Movie recommendation system",
	}
}

# ============================================================
# Annex III §7 — Migration, Asylum, Border Control
# ============================================================

test_migration_blocks_visa_decision if {
	migration_asylum.violation with input as {
		"jurisdiction": "EU",
		"text": "AI handles visa decision approval workflow",
	}
}

test_migration_blocks_asylum_screening if {
	migration_asylum.violation with input as {
		"jurisdiction": "EU",
		"text": "Automated asylum decision screening at the border",
	}
}

test_migration_allows_unrelated if {
	not migration_asylum.violation with input as {
		"jurisdiction": "EU",
		"text": "Music streaming recommendation",
	}
}

# ============================================================
# Annex III §8 — Justice and Democratic Processes
# ============================================================

test_justice_blocks_sentencing_ai if {
	justice_democracy.violation with input as {
		"jurisdiction": "EU",
		"text": "AI assists sentencing recommendations for judicial decision",
	}
}

test_justice_blocks_voter_microtargeting if {
	justice_democracy.violation with input as {
		"jurisdiction": "EU",
		"text": "AI voter micro-target campaign for the election",
	}
}

test_justice_allows_unrelated if {
	not justice_democracy.violation with input as {
		"jurisdiction": "EU",
		"text": "Inventory management AI",
	}
}

# ============================================================
# Aggregator — article6 package
# ============================================================

test_aggregator_violation_when_any_subrule_trips if {
	article6.violation with input as {
		"jurisdiction": "EU",
		"text": "AI for resume screening of candidates",
	}
}

test_aggregator_no_violation_on_innocuous_text if {
	not article6.violation with input as {
		"jurisdiction": "EU",
		"text": "Plain text with no AI deployment language",
	}
}

test_aggregator_no_violation_outside_eu if {
	not article6.violation with input as {
		"jurisdiction": "US",
		"text": "AI for recruitment and predictive policing",
	}
}

test_aggregator_collects_violation_into_violations_array if {
	count(article6.violations) > 0 with input as {
		"jurisdiction": "EU",
		"text": "Automated credit scoring AI for loan decision",
	}
}

test_aggregator_rules_evaluated_lists_all_eight if {
	count(article6.result.rules_evaluated) == 8 with input as {
		"jurisdiction": "EU",
		"text": "harmless text",
	}
}
