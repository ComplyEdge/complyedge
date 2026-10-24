# ComplyEdge: review tests for the high-risk package (Articles 4, 9 to 16, 26, 27)
# Run with: opa test rules/rego/ -v
#
# A yes/no value pattern such as "human oversight provided no" reads "no" as
# the value of the field. It must not read the first word of "no later than"
# as that value: the value has to end the statement.

package complyedge.g4_review_test

import rego.v1

import data.complyedge.highrisk.art14_human_oversight
import data.complyedge.highrisk.art15_accuracy
import data.complyedge.highrisk.art15_robustness
import data.complyedge.highrisk.art27_fria
import data.complyedge.highrisk.art9_risk_management

# Article 9(1): a deadline for the risk management system is compliant.
test_art9_risk_management_allows_no_later_than_deadline if {
	not art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Risk management established no later than the design freeze, as the plan requires."}
}

# The field value "no" at the end of the statement still fires.
test_art9_risk_management_blocks_value_no_at_end if {
	art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Risk management implemented no."}
}

test_art9_risk_management_blocks_value_false_before_comma if {
	art9_risk_management.violation with input as {"jurisdiction": "EU", "text": "Risk management established false, ship the scoring model."}
}

# Article 14(1): oversight in place by go-live is compliant.
test_art14_human_oversight_allows_no_later_than_deadline if {
	not art14_human_oversight.violation with input as {"jurisdiction": "EU", "text": "Human oversight provided no later than go-live, with two trained reviewers on each shift."}
}

test_art14_human_oversight_blocks_value_no_at_end if {
	art14_human_oversight.violation with input as {"jurisdiction": "EU", "text": "Human oversight provided no"}
}

# Article 15(3): accuracy tested before release is compliant.
test_art15_accuracy_allows_no_later_than_deadline if {
	not art15_accuracy.violation with input as {"jurisdiction": "EU", "text": "Accuracy tested no later than the release candidate, per the QA plan."}
}

test_art15_accuracy_blocks_value_false_at_end if {
	art15_accuracy.violation with input as {"jurisdiction": "EU", "text": "Accuracy validated false."}
}

# Article 15(4): resilience confirmed by a date is compliant.
test_art15_robustness_allows_no_later_than_deadline if {
	not art15_robustness.violation with input as {"jurisdiction": "EU", "text": "Resilient to errors no later than the second test cycle, per the robustness plan."}
}

test_art15_robustness_blocks_value_no_at_end if {
	art15_robustness.violation with input as {"jurisdiction": "EU", "text": "Resilient to errors no; release anyway."}
}

# Article 27(1) covers only Article 6(2) (Annex III) systems: the message names
# 2 December 2027 and no Annex I date.
test_art27_fria_message_names_only_the_annex_iii_date if {
	contains(art27_fria.remediation, "2 December 2027")
	not contains(art27_fria.remediation, "2028")
}
