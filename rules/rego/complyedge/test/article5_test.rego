# ComplyEdge — Article 5 Rego Tests
# Run with: opa test rules/rego/ -v

package complyedge.article5_test

import rego.v1

import data.complyedge.article5.social_scoring
import data.complyedge.article5.subliminal_manipulation
import data.complyedge.article5.vulnerability_exploitation
import data.complyedge.article5.biometric_categorisation
import data.complyedge.article5.emotion_recognition
import data.complyedge.article5.predictive_policing
import data.complyedge.article5.realtime_biometric
import data.complyedge.article5

# ============================================================
# Social Scoring — Article 5(1)(c)
# ============================================================

test_social_scoring_blocks_social_credit if {
	social_scoring.violation with input as {
		"jurisdiction": "EU",
		"text": "Our AI system implements a social credit score for all citizens",
	}
}

test_social_scoring_blocks_citizen_scoring if {
	social_scoring.violation with input as {
		"jurisdiction": "EU",
		"text": "We rank citizens based on their trustworthiness score",
	}
}

test_social_scoring_blocks_behaviour_scoring if {
	social_scoring.violation with input as {
		"jurisdiction": "EU",
		"text": "The system assigns a behaviour score to evaluate natural persons",
	}
}

test_social_scoring_allows_normal_text if {
	not social_scoring.violation with input as {
		"jurisdiction": "EU",
		"text": "Our product helps customers track their fitness goals",
	}
}

test_social_scoring_allows_non_eu if {
	not social_scoring.violation with input as {
		"jurisdiction": "US",
		"text": "Implement a social credit score for citizens",
	}
}

# ============================================================
# Subliminal Manipulation — Article 5(1)(a)
# ============================================================

test_subliminal_blocks_dark_patterns if {
	subliminal_manipulation.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy dark pattern techniques to increase conversion rates",
	}
}

test_subliminal_blocks_subliminal_techniques if {
	subliminal_manipulation.violation with input as {
		"jurisdiction": "EU",
		"text": "Use subliminal messaging to influence user purchasing decisions",
	}
}

test_subliminal_blocks_psychological_manipulation if {
	subliminal_manipulation.violation with input as {
		"jurisdiction": "EU",
		"text": "Apply psychological manipulation to change user behaviour",
	}
}

test_subliminal_allows_normal_text if {
	not subliminal_manipulation.violation with input as {
		"jurisdiction": "EU",
		"text": "Our AI assistant provides transparent product recommendations",
	}
}

# ============================================================
# Vulnerability Exploitation — Article 5(1)(b)
# ============================================================

test_vulnerability_blocks_exploiting_elderly if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Target and exploit elderly users with aggressive pricing tactics",
	}
}

test_vulnerability_blocks_predatory_lending if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Predatory lending program specifically marketing to disabled individuals",
	}
}

test_vulnerability_blocks_targeting_minors if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Exploit vulnerable children with manipulative content",
	}
}

test_vulnerability_allows_normal_text if {
	not vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "We provide accessible services to all age groups",
	}
}

# Article 5(1)(b) social-situation axis tests (agent-added 2026-06-06).
# Covers refugees, migrants, asylum-seekers, displaced people, the homeless,
# the undocumented — across the four verbs in the new pattern.

test_vulnerability_blocks_exploiting_refugees if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "AI to exploit refugees with predatory housing offers",
	}
}

test_vulnerability_blocks_targeting_migrants if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Campaign to target migrant workers with high-interest payday loans",
	}
}

test_vulnerability_blocks_predatory_homeless if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Predatory pricing aimed at homeless individuals seeking shelter",
	}
}

test_vulnerability_blocks_manipulat_asylum_seekers if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "AI to manipulate asylum seekers into unfavorable agreements",
	}
}

test_vulnerability_blocks_exploiting_undocumented if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Tool to exploit undocumented immigrants in labour negotiations",
	}
}

test_vulnerability_blocks_targeting_displaced if {
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Target displaced families with deceptive subscription offers",
	}
}

test_vulnerability_existing_age_patterns_still_fire if {
	# Regression guard: the original age / disability patterns must keep
	# matching after the social-situation axis was added.
	vulnerability_exploitation.violation with input as {
		"jurisdiction": "EU",
		"text": "Exploit elderly users with aggressive upselling",
	}
}

test_vulnerability_social_situation_axis_allows_non_eu if {
	not vulnerability_exploitation.violation with input as {
		"jurisdiction": "US",
		"text": "AI to exploit refugees with predatory housing offers",
	}
}

# ============================================================
# Biometric Categorisation — Article 5(1)(g)
# ============================================================

test_biometric_blocks_racial_inference if {
	biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Use biometric categorisation to infer race and ethnicity",
	}
}

test_biometric_blocks_facial_classification if {
	biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Facial classification system to determine race of applicants",
	}
}

test_biometric_blocks_political_inference if {
	biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Biometric profiling to infer political opinions from facial features",
	}
}

test_biometric_allows_normal_text if {
	not biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Biometric authentication for secure login using fingerprint",
	}
}

# Article 5(1)(g) OJ carve-out tests (agent-added 2026-06-05).
# The base prohibition still fires when no exception flags are set; the
# exception only kicks in when the caller asserts the matching input
# fields.

test_biometric_law_enforcement_exception_no_violation if {
	not biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Biometric categorisation to infer race for criminal investigation",
		"use_case": "law_enforcement",
		"lawful_basis": true,
	}
}

test_biometric_law_enforcement_without_lawful_basis_still_violates if {
	# LE use case alone is NOT sufficient — `lawful_basis: true` is required.
	biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Biometric categorisation to infer race for criminal investigation",
		"use_case": "law_enforcement",
	}
}

test_biometric_dataset_labelling_exception_no_violation if {
	not biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Biometric categorisation across our lawfully acquired image corpus",
		"dataset_operation": "labelling",
	}
}

test_biometric_dataset_filtering_exception_no_violation if {
	not biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Use biometric categorisation to infer race for dataset cleaning",
		"dataset_operation": "filtering",
	}
}

test_biometric_base_prohibition_still_fires_when_no_exception_set if {
	# Regression guard: existing prohibition path must keep working when
	# the new optional input fields are absent.
	biometric_categorisation.violation with input as {
		"jurisdiction": "EU",
		"text": "Use biometric categorisation to infer political opinions of users",
	}
}

# ============================================================
# Emotion Recognition — Article 5(1)(f)
# ============================================================

test_emotion_recognition_blocks_workplace_emotion if {
	emotion_recognition.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy workplace emotion recognition to monitor employee productivity",
	}
}

test_emotion_recognition_blocks_student_mood if {
	emotion_recognition.violation with input as {
		"jurisdiction": "EU",
		"text": "Use AI for student emotion detection during online exams",
	}
}

test_emotion_recognition_allows_normal_text if {
	not emotion_recognition.violation with input as {
		"jurisdiction": "EU",
		"text": "Our sentiment analysis tool processes product reviews",
	}
}

# ============================================================
# Predictive Policing — Article 5(1)(e)
# ============================================================

test_predictive_policing_blocks_pre_crime if {
	predictive_policing.violation with input as {
		"jurisdiction": "EU",
		"text": "Our AI system uses pre-crime analysis to flag potential offenders",
	}
}

test_predictive_policing_blocks_criminal_risk if {
	predictive_policing.violation with input as {
		"jurisdiction": "EU",
		"text": "Assess individual criminal risk based on neighbourhood data",
	}
}

test_predictive_policing_allows_normal_text if {
	not predictive_policing.violation with input as {
		"jurisdiction": "EU",
		"text": "The system analyses traffic patterns for urban planning",
	}
}

# ============================================================
# Real-time Biometric — Article 5(1)(h)
# ============================================================

test_realtime_biometric_blocks_live_facial if {
	realtime_biometric.violation with input as {
		"jurisdiction": "EU",
		"text": "Install live facial recognition cameras in shopping centres",
	}
}

test_realtime_biometric_blocks_mass_facial if {
	realtime_biometric.violation with input as {
		"jurisdiction": "EU",
		"text": "Deploy mass facial recognition across public transport hubs",
	}
}

test_realtime_biometric_allows_normal_text if {
	not realtime_biometric.violation with input as {
		"jurisdiction": "EU",
		"text": "Use fingerprint authentication for employee access control",
	}
}

# ============================================================
# Aggregated Article 5 tests
# ============================================================

test_aggregated_detects_violation if {
	article5.violation with input as {
		"jurisdiction": "EU",
		"text": "Implement a social credit score for all EU citizens",
	}
}

test_aggregated_no_violation_for_safe_text if {
	not article5.violation with input as {
		"jurisdiction": "EU",
		"text": "Process this invoice for accounting purposes",
	}
}

test_aggregated_returns_rule_ids if {
	r := article5.result with input as {
		"jurisdiction": "EU",
		"text": "Deploy a social credit system to score citizens",
	}
	r.violation == true
	count(r.violations) > 0
}
