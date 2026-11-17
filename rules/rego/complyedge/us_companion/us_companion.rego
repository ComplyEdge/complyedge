# ComplyEdge: US companion chatbot laws aggregator (CA, NY, WA, OR)
#
# OPA queries this package at: POST /v1/data/complyedge/us_companion/result
# after the companion meaning check (X3). It is NOT in opa_client.PACKAGES:
# it never returns `violation`, only the actions the app must take.
# Aggregator carve-out (RULE_STANDARD.md §5.6): no legal condition of its own.
#
# Imported leaf files (each leaf individually subject to §5 sign-off):
#   - us_companion.ca  (Cal. Bus. & Prof. Code §§ 22602, 21812)
#   - us_companion.ny  (N.Y. Gen. Bus. Law Art. 47, Art. 48)
#   - us_companion.wa  (Washington ch. 168, Laws of 2026)
#   - us_companion.or  (Oregon Laws 2026, ch. 85)
#
# Input (built by the /v1/check handler; spec X1, X6):
#   check_ns, direction, jurisdiction, assessed, labels, context, anchors,
#   ny_notice_today_for_user
# Output:
#   result.required_actions: one entry per (leaf, action) that fired:
#     {action, rule_id, jurisdiction, reason_code, due_ns, counted}
#     The API merges entries of the same action into one, listing every
#     rule_id (X2 "one entry per action").
#   result.rules_evaluated: the leaves of the check's jurisdiction that are
#     inside their date window at check_ns.
#
# Spec: docs/architecture/companion-chatbot-laws-tech-spec.md X2

package complyedge.us_companion

import rego.v1

import data.complyedge.us_companion.ca
import data.complyedge.us_companion.helpers as h
import data.complyedge.us_companion.ny
import data.complyedge.us_companion.or
import data.complyedge.us_companion.wa

state := {
	"US-CA": {"leaves": ca.leaves, "actions": ca.actions},
	"US-NY": {"leaves": ny.leaves, "actions": ny.actions},
	"US-WA": {"leaves": wa.leaves, "actions": wa.actions},
	"US-OR": {"leaves": or.leaves, "actions": or.actions},
}

pack := state[input.jurisdiction]

# A leaf outside its date window never fires (checked again here so no state
# file can bypass the window), and a leaf of another state never fires.
fired contains e if {
	some e in pack.actions
	meta := pack.leaves[e.rule_id]
	meta.jurisdiction == input.jurisdiction
	h.active(meta)
}

evaluated contains rid if {
	some rid, meta in pack.leaves
	h.active(meta)
}

default required_actions := []

required_actions := sort([e | some e in fired]) if pack

default rules_evaluated := []

rules_evaluated := sort([rid | some rid in evaluated]) if pack

result := {
	"required_actions": required_actions,
	"rules_evaluated": rules_evaluated,
}
