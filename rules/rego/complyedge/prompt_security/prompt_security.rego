# ComplyEdge — Prompt-injection / IPI: aggregated check
#
# Aggregates the prompt_security leaves and returns a unified result.
# OPA queries this package at: POST /v1/data/complyedge/prompt_security
# Aggregator carve-out (RULE_STANDARD.md §5.6): no legal condition of its own.

package complyedge.prompt_security

import rego.v1

import data.complyedge.prompt_security.role_hijack
import data.complyedge.prompt_security.safety_disable
import data.complyedge.prompt_security.indirect_embedded
import data.complyedge.prompt_security.embedded_instruction
import data.complyedge.prompt_security.indirect_injection
import data.complyedge.prompt_security.ai_addressed
import data.complyedge.prompt_security.sysprompt_leak
import data.complyedge.prompt_security.training_extract
import data.complyedge.prompt_security.markdown_exfil
import data.complyedge.prompt_security.separator_hijack
import data.complyedge.prompt_security.instruction_override
import data.complyedge.prompt_security.tool_hijack

default violation := false

violation if role_hijack.violation
violation if safety_disable.violation
violation if indirect_embedded.violation
violation if embedded_instruction.violation
violation if indirect_injection.violation
violation if ai_addressed.violation
violation if sysprompt_leak.violation
violation if training_extract.violation
violation if markdown_exfil.violation
violation if separator_hijack.violation
violation if instruction_override.violation
violation if tool_hijack.violation

violations contains v if {
	role_hijack.violation
	v := role_hijack.result
}

violations contains v if {
	safety_disable.violation
	v := safety_disable.result
}

violations contains v if {
	indirect_embedded.violation
	v := indirect_embedded.result
}

violations contains v if {
	embedded_instruction.violation
	v := embedded_instruction.result
}

violations contains v if {
	indirect_injection.violation
	v := indirect_injection.result
}

violations contains v if {
	ai_addressed.violation
	v := ai_addressed.result
}

violations contains v if {
	sysprompt_leak.violation
	v := sysprompt_leak.result
}

violations contains v if {
	training_extract.violation
	v := training_extract.result
}

violations contains v if {
	markdown_exfil.violation
	v := markdown_exfil.result
}

violations contains v if {
	separator_hijack.violation
	v := separator_hijack.result
}

violations contains v if {
	instruction_override.violation
	v := instruction_override.result
}

violations contains v if {
	tool_hijack.violation
	v := tool_hijack.result
}

result := {
	"violation": violation,
	"violations": violations,
	"rules_evaluated": [
		role_hijack.rule_id,
		safety_disable.rule_id,
		indirect_embedded.rule_id,
		embedded_instruction.rule_id,
		indirect_injection.rule_id,
		ai_addressed.rule_id,
		sysprompt_leak.rule_id,
		training_extract.rule_id,
		markdown_exfil.rule_id,
		separator_hijack.rule_id,
		instruction_override.rule_id,
		tool_hijack.rule_id,
	],
}
