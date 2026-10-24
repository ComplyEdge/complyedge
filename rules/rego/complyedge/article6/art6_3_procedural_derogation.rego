# ComplyEdge: EU AI Act Article 6(3): Narrow Procedural-Task Derogation
#
# An Annex III system is not high-risk where it performs a narrow procedural
# task, improves a previously completed human activity, detects decision
# patterns without replacing human assessment, or performs a preparatory task.
# Claiming the derogation while describing substantive automated decisioning
# (replacing human assessment on credit, hiring, benefits, etc.) is a
# misclassification risk.
#
# Layer 1 detects: within one line and in this order, "not high-risk" (also
# "high risk"), "6(3)" or "narrow procedural", then replace (any ending)
# followed by "human", or automated (any ending) followed by credit, loan,
# hiring, recruit, welfare, benefit or insurance and then "decision"; claim,
# assert or invoke, then "6(3)", "narrow procedural task" or "preparatory
# task", then "without human" oversight, review or assessment, or "fully
# automat"; and derogat (any ending), then "annex iii", then "credit scor",
# creditworthiness, "hiring decision" or "insurance pricing". It matches
# wording, not meaning: it misses a misclassification told in other words, and
# it fires on a text that claims the derogation and says the system does not
# replace human assessment ("Our CV parser is not high-risk under Article
# 6(3): it only converts resumes into structured fields and does not replace
# human assessment; recruiters make every decision."). Whether the derogation
# is claimed for a system that does replace human assessment is judged in
# Layer 2.
#
# Legal citation: Regulation (EU) 2024/1689, Article 6(3)
# Recital: 53: high-risk classification should not capture systems that only
#   perform narrow procedural or preparatory tasks
# Effective: 2027-12-02 (Annex III high-risk systems, Article 113, as amended by Regulation (EU) 2026/1744. Until then this is a readiness check, not a binding obligation. The condition does not read the date)
# Penalty: Article 6 itself is not listed in Article 99(3) or (4). A provider that misclassified the system as non-high-risk to circumvent Chapter III, Section 2 is subject to fines in accordance with Article 99 (Article 80(7))
# Condition type: deterministic
# Enforcement layer: layer1
# Status: approved
# Approved by: Leo Celis on 2026-10-22 (via agent review per §5.1 amendment v1.1)
# ELI: http://data.europa.eu/eli/reg/2024/1689/art_6/par_3/oj
# Provision: Regulation (EU) 2024/1689, Article 6(3)

package complyedge.article6.art6_3_procedural_derogation

import rego.v1

import data.complyedge.shared.normalize

default violation := false

violation if {
	input.jurisdiction == "EU"
	pattern_match
}

pattern_match if {
	patterns := [
		"(?:not\\s+high[\\-\\s]?risk|6\\(3\\)|narrow\\s+procedural).*(?:replac\\w*\\s+human|automat\\w*\\s+(?:credit|loan|hiring|recruit|welfare|benefit|insurance)\\s+decision)",
		"(?:claim|assert|invoke).*(?:6\\(3\\)|narrow\\s+procedural\\s+task|preparatory\\s+task).*(?:without\\s+human\\s+(?:oversight|review|assessment)|fully\\s+automat)",
		"derogat\\w*.*annex\\s*iii.*(?:credit\\s+scor|creditworthiness|hiring\\s+decision|insurance\\s+pricing)",
	]

	text := lower(normalize.text)
	some pattern in patterns
	regex.match(pattern, text)
}

rule_id := "rego-art6-3-001"

citation := "Regulation (EU) 2024/1689, Article 6(3), first subparagraph: By derogation from paragraph 2, an AI system referred to in Annex III shall not be considered to be high-risk where it does not pose a significant risk of harm to the health, safety or fundamental rights of natural persons, including by not materially influencing the outcome of decision making. Second subparagraph: The first subparagraph shall apply where any of the following conditions is fulfilled: (a) the AI system is intended to perform a narrow procedural task; (b) the AI system is intended to improve the result of a previously completed human activity; (c) the AI system is intended to detect decision-making patterns or deviations from prior decision-making patterns and is not meant to replace or influence the previously completed human assessment, without proper human review; or (d) the AI system is intended to perform a preparatory task to an assessment relevant for the purposes of the use cases listed in Annex III. Third subparagraph: Notwithstanding the first subparagraph, an AI system referred to in Annex III shall always be considered to be high-risk where the AI system performs profiling of natural persons."

severity := "high"

remediation := "Do not claim the Article 6(3) derogation for systems that replace or substantially automate human assessment in Annex III domains. Document why the task is narrow/procedural if relying on the carve-out. Readiness check, not yet a binding obligation: the Annex III high-risk obligations apply from 2 December 2027 (Article 113, as amended by Regulation (EU) 2026/1744)."

result := {
	"violation": violation,
	"rule_id": rule_id,
	"citation": citation,
	"severity": severity,
	"remediation": remediation,
}
