# ComplyEdge — EU AI Act Article 5(1)(g): Biometric Categorisation
#
# Prohibits AI systems that use biometric categorisation to infer race,
# political opinions, trade union membership, religious or philosophical
# beliefs, sex life, or sexual orientation.
#
# Legal citation: Regulation (EU) 2024/1689, Article 5(1)(g)
# Recital: 30 — biometric categorisation inferring race, political opinions, trade union membership, religion, sex life or sexual orientation breaches fundamental rights and the EU Charter
# Effective: 2025-02-02
# Penalty: up to €35M or 7% of global revenue
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-07-03 (via agent review per RULE_STANDARD §5.5; carve-outs + `/v1/check` plumbing)

package complyedge.article5.biometric_categorisation

import rego.v1

default violation := false

violation if {
	input.jurisdiction == "EU"
	biometric_pattern_match
	not law_enforcement_exception
	not dataset_operation_exception
}

# Article 5(1)(g) OJ carve-out: the prohibition does NOT cover categorising of
# biometric data in the area of law enforcement.
#
# THE ACT BINDS THIS CARVE-OUT TO THE ACTOR, NOT TO THE REQUEST. "Law
# enforcement purpose" is defined as activities carried out BY law enforcement
# authorities, or ON THEIR BEHALF. Whether it applies is therefore a property
# of the deployer, and cannot be established by two fields in a request body:
# on the caller assertion alone, anyone able to reach the API could switch off
# a critical Article 5 prohibition by adding `use_case` and `lawful_basis`.
#
# `law_enforcement_authorised` is set by the SERVICE from tenant configuration
# and is never accepted from the request. Absent it the caller's assertion is
# recorded as refused and the prohibition STANDS.
law_enforcement_exception if {
	input.use_case == "law_enforcement"
	input.lawful_basis == true
	input.law_enforcement_authorised == true
}

# Article 5(1)(g) OJ carve-out: dataset *labelling* and
# *filtering* of lawfully acquired biometric datasets is excluded — that
# is data preparation, not categorisation of natural persons.
dataset_operation_exception if {
	input.dataset_operation in {"labelling", "filtering"}
}

# ── Transparency: a suppressed violation is still a decision ──────────────────
# When the pattern matched and a carve-out suppressed it, the record must say
# so. These fields are CALLER-ASSERTED and unverified by this engine, so the
# entry states that explicitly rather than presenting them as established fact.
# Without this, the one place where a prohibition can be switched off leaves no
# trace in the Article 12 record.
# An assertion that was made and REFUSED is evidence too. Without this, a
# caller claiming the carve-out on an unauthorised tenant is indistinguishable
# in the record from one who never claimed it, and the claim is exactly what an
# investigator would want to see.
rejected_exemptions contains e if {
	input.jurisdiction == "EU"
	biometric_pattern_match
	input.use_case == "law_enforcement"
	input.lawful_basis == true
	not input.law_enforcement_authorised == true
	e := {
		"rule_id": rule_id,
		"exemption": "law_enforcement",
		"outcome": "refused",
		"reason": "the tenant is not configured as a law enforcement authority; Regulation (EU) 2024/1689 confines this carve-out to activities carried out by law enforcement authorities or on their behalf",
		"asserted": {
			"use_case": input.use_case,
			"lawful_basis": input.lawful_basis,
		},
		"asserted_by": "caller",
	}
}

exemptions contains e if {
	input.jurisdiction == "EU"
	biometric_pattern_match
	law_enforcement_exception
	e := {
		"rule_id": rule_id,
		"exemption": "law_enforcement",
		"basis": "Regulation (EU) 2024/1689, Article 5(1)(g): this prohibition shall not cover categorising of biometric data in the area of law enforcement.",
		"asserted": {
			"use_case": input.use_case,
			"lawful_basis": input.lawful_basis,
		},
		"asserted_by": "caller",
		"verified": false,
	}
}

exemptions contains e if {
	input.jurisdiction == "EU"
	biometric_pattern_match
	dataset_operation_exception
	e := {
		"rule_id": rule_id,
		"exemption": "dataset_operation",
		"basis": "Regulation (EU) 2024/1689, Article 5(1)(g): this prohibition shall not cover any labelling or filtering of lawfully acquired biometric datasets.",
		"asserted": {"dataset_operation": input.dataset_operation},
		"asserted_by": "caller",
		"verified": false,
	}
}

biometric_pattern_match if {
	patterns := [
		"biometric[\\- ]?categori[sz]",
		"facial[\\- ]?classif.*race",
		"biometric.*infer.*(race|religion|politic|sexual|belief|union)",
		"emotion[\\- ]?recognition.*categori",
		"biometric.*profiling.*(race|religion|politic|sexual)",
		"facial.*recognition.*categoriz",
	]

	text := lower(input.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art5-1g-001"

citation := "Regulation (EU) 2024/1689, Article 5(1)(g): The placing on the market, the putting into service for this specific purpose, or the use of biometric categorisation systems that categorise individually natural persons based on their biometric data to deduce or infer their race, political opinions, trade union membership, religious or philosophical beliefs, sex life or sexual orientation. This prohibition shall not cover any labelling or filtering of lawfully acquired biometric datasets, such as images, based on biometric data or categorising of biometric data in the area of law enforcement."
severity := "critical"

remediation := "Remove any biometric categorisation that infers protected characteristics. If biometric processing is required, ensure it does not deduce race, religion, political views, sex life, or other prohibited categories."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
