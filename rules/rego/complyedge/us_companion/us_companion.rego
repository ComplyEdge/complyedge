# ComplyEdge: US companion chatbot laws aggregator (CA, NY, WA, OR)
#
# OPA queries this package at: POST /v1/data/complyedge/us_companion/result
# after the companion meaning check. It is NOT in opa_client.PACKAGES:
# it never returns `violation`, only the actions the app must take.
# Aggregator carve-out (RULE_STANDARD.md §5.6): no legal condition of its own.
#
# Imported leaf files (each leaf individually subject to §5 sign-off):
#   - us_companion.ca  (Cal. Bus. & Prof. Code §§ 22602, 21812)
#   - us_companion.ny  (N.Y. Gen. Bus. Law Art. 47, Art. 48)
#   - us_companion.wa  (Washington ch. 168, Laws of 2026)
#   - us_companion.or  (Oregon Laws 2026, ch. 85)
#
# Input (built by the /v1/check handler):
#   check_ns, direction, jurisdiction, assessed, labels, context, anchors,
#   ny_notice_today_for_user
# Output:
#   result.required_actions: one entry per (leaf, action) that fired:
#     {action, rule_id, jurisdiction, reason_code, due_ns, counted}
#     The API merges entries of the same action into one, listing every
#     rule_id (one entry per action).
#   result.upcoming_actions: periodic notices this session will owe and the
#     check has not reached yet, same entry shape with due_ns in the future
#     (helpers.periodic_entry). The app shows each one by its due time.
#   result.rules_evaluated: the leaves of the check's jurisdiction that are
#     inside their date window at check_ns.

package complyedge.us_companion

import rego.v1

import data.complyedge.us_companion.ca
import data.complyedge.us_companion.helpers as h
import data.complyedge.us_companion.ny
import data.complyedge.us_companion.or
import data.complyedge.us_companion.wa

state := {
	"US-CA": {"leaves": ca.leaves, "actions": ca.actions, "upcoming": ca.upcoming},
	"US-NY": {"leaves": ny.leaves, "actions": ny.actions, "upcoming": ny.upcoming},
	"US-WA": {"leaves": wa.leaves, "actions": wa.actions, "upcoming": wa.upcoming},
	"US-OR": {"leaves": or.leaves, "actions": or.actions, "upcoming": or.upcoming},
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

# Same filters for the periodic notices not due yet at check_ns.
pending contains e if {
	some e in pack.upcoming
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

default upcoming_actions := []

upcoming_actions := sort([e | some e in pending]) if pack

default rules_evaluated := []

rules_evaluated := sort([rid | some rid in evaluated]) if pack

result := {
	"required_actions": required_actions,
	"upcoming_actions": upcoming_actions,
	"rules_evaluated": rules_evaluated,
}
