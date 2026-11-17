# ComplyEdge: US companion chatbot rule pack tests (spec T1, X2)
# Run with: opa test rules/rego/ -v --run us_companion
#
# Expected actions are written by hand from the X2 table and the statutes,
# never read back from the pack. Times are written in the state's local
# offset so the window edges read as the statute dates.

package complyedge.us_companion_test

import rego.v1

import data.complyedge.us_companion
import data.complyedge.us_companion.helpers as h

t(s) := time.parse_rfc3339_ns(s)

hr := 3600000000000

mn := 60000000000

no_anchors := {"not_human": null, "break_reminder": null, "child_ai_notice": null}

# Anchors with a not-human notice already confirmed, so start components of
# that kind stay quiet.
nh_done(at) := object.union(no_anchors, {"not_human": at})

# One companion check. `start` is the session start; ctx is merged over an
# adult default.
check(jur, at, start, dir, labels, ctx, anchors) := {
	"check_ns": at,
	"direction": dir,
	"jurisdiction": jur,
	"assessed": true,
	"labels": labels,
	"context": object.union({"age_status": "adult", "age_source": "none", "session_started_ns": start}, ctx),
	"anchors": anchors,
	"ny_notice_today_for_user": false,
}

run(inp) := r if {
	r := us_companion.result with input as inp
}

has(r, rid, action) if {
	some e in r.required_actions
	e.rule_id == rid
	e.action == action
}

get(r, rid, action) := e if {
	some e in r.required_actions
	e.rule_id == rid
	e.action == action
}

rule_ids(r) := {e.rule_id | some e in r.required_actions}

# ── Window helper ────────────────────────────────────────────────────────────

test_local_midnight_pacific_standard_and_daylight if {
	h.local_midnight_ns("2027-01-01", "US-CA") == t("2027-01-01T08:00:00Z")
	h.local_midnight_ns("2027-07-01", "US-CA") == t("2027-07-01T07:00:00Z")
	h.local_midnight_ns("2026-01-01", "US-WA") == t("2026-01-01T08:00:00Z")
}

test_local_midnight_eastern_and_dst_change_days if {
	# 2025-11-02 was the first Sunday of November: midnight still EDT.
	h.local_midnight_ns("2025-11-02", "US-NY") == t("2025-11-02T04:00:00Z")
	h.local_midnight_ns("2025-11-05", "US-NY") == t("2025-11-05T05:00:00Z")

	# 2027-03-14 is the second Sunday of March: midnight still EST.
	h.local_midnight_ns("2027-03-14", "US-NY") == t("2027-03-14T05:00:00Z")
	h.local_midnight_ns("2027-03-15", "US-NY") == t("2027-03-15T04:00:00Z")
}

test_window_refuses_leaf_outside_dates if {
	meta := {"jurisdiction": "US-CA", "effective_from": "2026-01-01", "effective_to": "2026-12-31"}
	h.active(meta) with input as {"check_ns": t("2026-12-31T23:59:59-08:00")}
	not h.active(meta) with input as {"check_ns": t("2027-01-01T00:00:00-08:00")}
	not h.active(meta) with input as {"check_ns": t("2025-12-31T23:59:59-08:00")}
	h.active(meta) with input as {"check_ns": t("2026-01-01T00:00:00-08:00")}
}

# ── California § 22602(a) not-human, recommended ─────────────────────────────

ca_2026 := t("2026-06-10T12:00:00-07:00")

ca_2027 := t("2027-08-10T12:00:00-07:00")

test_ca_22602a_label_fires_recommended_at_the_check if {
	r := run(check("US-CA", ca_2026, ca_2026 - hr, "prompt", ["user_believes_human"], {}, nh_done(ca_2026 - hr)))
	e := get(r, "us-ca-22602a-not-human", "show_not_human_notice")
	e.counted == false
	e.due_ns == ca_2026
	e.jurisdiction == "US-CA"
}

test_ca_22602a_no_anchor_due_at_session_start if {
	r := run(check("US-CA", ca_2026, ca_2026 - hr, "prompt", [], {}, no_anchors))
	e := get(r, "us-ca-22602a-not-human", "show_not_human_notice")
	e.counted == false
	e.due_ns == ca_2026 - hr
}

test_ca_22602a_quiet_after_confirmed_notice_and_no_label if {
	r := run(check("US-CA", ca_2026, ca_2026 - hr, "prompt", [], {}, nh_done(ca_2026 - hr)))
	not has(r, "us-ca-22602a-not-human", "show_not_human_notice")
}

test_ca_22602a_message_label_on_reply_does_not_fire if {
	r := run(check("US-CA", ca_2026, ca_2026 - hr, "output", ["user_believes_human"], {}, nh_done(ca_2026 - hr)))
	not has(r, "us-ca-22602a-not-human", "show_not_human_notice")
}

# ── California § 22602(b) ────────────────────────────────────────────────────

test_ca_22602b_crisis_referral_for_adult_counted if {
	r := run(check("US-CA", ca_2026, ca_2026, "prompt", ["expresses_self_harm"], {}, nh_done(ca_2026)))
	e := get(r, "us-ca-22602b-crisis-referral", "show_crisis_referral")
	e.counted == true
	e.due_ns == ca_2026
}

test_ca_22602b_crisis_not_on_reply_direction if {
	r := run(check("US-CA", ca_2026, ca_2026, "output", ["expresses_self_harm"], {}, nh_done(ca_2026)))
	not has(r, "us-ca-22602b-crisis-referral", "show_crisis_referral")
}

test_ca_22602b_harmful_reply_blocks if {
	r := run(check("US-CA", ca_2026, ca_2026, "output", ["promotes_self_harm"], {}, nh_done(ca_2026)))
	e := get(r, "us-ca-22602b-harmful-reply", "block_reply")
	e.counted == false
}

test_ca_22602b_harmful_label_on_message_does_not_block if {
	r := run(check("US-CA", ca_2026, ca_2026, "prompt", ["promotes_self_harm"], {}, nh_done(ca_2026)))
	not has(r, "us-ca-22602b-harmful-reply", "block_reply")
}

# ── California § 22602(c) minors, 2026 only ──────────────────────────────────

test_ca_22602c_minor_disclosure_due_at_start if {
	r := run(check("US-CA", ca_2026, ca_2026 - mn, "prompt", [], {"age_status": "known_minor", "is_session_start": true}, no_anchors))
	e := get(r, "us-ca-22602c-minor-ai-disclosure", "show_not_human_notice")
	e.counted == true
	e.due_ns == ca_2026 - mn
}

test_ca_22602c_minor_disclosure_not_for_adult if {
	r := run(check("US-CA", ca_2026, ca_2026, "prompt", [], {"is_session_start": true}, no_anchors))
	not has(r, "us-ca-22602c-minor-ai-disclosure", "show_not_human_notice")
}

test_ca_22602c_minor_disclosure_quiet_once_confirmed if {
	r := run(check("US-CA", ca_2026, ca_2026 - hr, "prompt", [], {"age_status": "child"}, nh_done(ca_2026 - mn)))
	not has(r, "us-ca-22602c-minor-ai-disclosure", "show_not_human_notice")
}

test_ca_22602c_minor_break_window_last_day if {
	at := t("2026-12-31T23:59:59-08:00")
	r := run(check("US-CA", at, at - (3 * hr), "prompt", [], {"age_status": "known_minor"}, nh_done(at - (3 * hr))))
	e := get(r, "us-ca-22602c-minor-break", "show_break_reminder")
	e.due_ns == at
	e.counted == true
	"us-ca-22602c-minor-break" in r.rules_evaluated
}

test_ca_22602c_minor_break_gone_on_2027_01_01 if {
	at := t("2027-01-01T00:00:00-08:00")
	r := run(check("US-CA", at, at - (4 * hr), "prompt", [], {"age_status": "known_minor"}, nh_done(at - (4 * hr))))
	not has(r, "us-ca-22602c-minor-break", "show_break_reminder")
	not "us-ca-22602c-minor-break" in r.rules_evaluated
	not "us-ca-22602c-minor-ai-disclosure" in r.rules_evaluated
}

test_ca_22602c_minor_break_not_before_three_hours if {
	start := ca_2026 - ((3 * hr) - mn)
	r := run(check("US-CA", ca_2026, start, "prompt", [], {"age_status": "known_minor"}, nh_done(start)))
	not has(r, "us-ca-22602c-minor-break", "show_break_reminder")
}

test_ca_22602c_minor_break_runs_from_the_last_confirmed_break if {
	start := ca_2026 - (5 * hr)
	anchors := object.union(nh_done(start), {"break_reminder": start + (3 * hr)})

	# 2h30 after the confirmed reminder: nothing due yet.
	r1 := run(check("US-CA", (start + (5 * hr)) + (30 * mn), start, "prompt", [], {"age_status": "known_minor"}, anchors))
	not has(r1, "us-ca-22602c-minor-break", "show_break_reminder")

	# 3h after it: due at anchor + 3h.
	r2 := run(check("US-CA", start + (6 * hr), start, "prompt", [], {"age_status": "known_minor"}, anchors))
	get(r2, "us-ca-22602c-minor-break", "show_break_reminder").due_ns == start + (6 * hr)
}

test_ca_22602c_minor_sexual_blocks_minor_only if {
	r := run(check("US-CA", ca_2026, ca_2026, "output", ["sexual_conduct_directive"], {"age_status": "child"}, nh_done(ca_2026)))
	get(r, "us-ca-22602c-minor-sexual", "block_reply").counted == false
	r2 := run(check("US-CA", ca_2026, ca_2026, "output", ["sexual_conduct_directive"], {}, nh_done(ca_2026)))
	not has(r2, "us-ca-22602c-minor-sexual", "block_reply")
}

# § 22602(c)(3) covers "directly stating that the minor should engage in
# sexually explicit conduct" (and visual material, which a text check cannot
# see). Suggestive talk alone is WA Sec. 4(1)(b) wording, not California's.
test_ca_22602c_minor_sexual_ignores_suggestive_talk if {
	r := run(check("US-CA", ca_2026, ca_2026, "output", ["sexual_to_minor"], {"age_status": "child"}, nh_done(ca_2026)))
	not has(r, "us-ca-22602c-minor-sexual", "block_reply")
}

test_ca_22602c_minor_sexual_not_in_2027 if {
	r := run(check("US-CA", ca_2027, ca_2027, "output", ["sexual_conduct_directive"], {"age_status": "child"}, nh_done(ca_2027)))
	not has(r, "us-ca-22602c-minor-sexual", "block_reply")
}

# ── California § 21812, from 2027-07-01 ──────────────────────────────────────

test_ca_21812_child_crisis_not_before_2027_07_01 if {
	at := t("2027-06-30T23:59:59-07:00")
	r := run(check("US-CA", at, at, "prompt", ["expresses_self_harm"], {"age_status": "child"}, nh_done(at)))
	not has(r, "us-ca-21812d1-child-crisis", "show_crisis_referral")
	not "us-ca-21812d1-child-crisis" in r.rules_evaluated
	has(r, "us-ca-22602b-crisis-referral", "show_crisis_referral")
}

test_ca_21812_child_crisis_from_2027_07_01 if {
	at := t("2027-07-01T00:00:00-07:00")
	r := run(check("US-CA", at, at, "prompt", ["expresses_self_harm"], {"age_status": "child"}, nh_done(at)))
	get(r, "us-ca-21812d1-child-crisis", "show_crisis_referral").counted == true
	has(r, "us-ca-22602b-crisis-referral", "show_crisis_referral")
}

test_ca_21812_treated_as_child_gets_child_protections if {
	r := run(check("US-CA", ca_2027, ca_2027, "prompt", ["expresses_self_harm"], {"age_status": "treated_as_child"}, nh_done(ca_2027)))
	has(r, "us-ca-21812d1-child-crisis", "show_crisis_referral")
}

test_ca_21812_adult_gets_no_child_crisis if {
	r := run(check("US-CA", ca_2027, ca_2027, "prompt", ["expresses_self_harm"], {}, nh_done(ca_2027)))
	not has(r, "us-ca-21812d1-child-crisis", "show_crisis_referral")
	has(r, "us-ca-22602b-crisis-referral", "show_crisis_referral")
}

# § 21812(d)(1)(B): "at least one of the following actions". With a parent
# linked the operator may pick (i) or (ii), so neither option is counted on
# its own; escalate_imminent_risk is the counted duty.
test_ca_21812d1b_imminent_with_parent_linked if {
	r := run(check("US-CA", ca_2027, ca_2027, "prompt", ["imminent_risk"], {"age_status": "child", "parent_linked": true}, nh_done(ca_2027)))
	get(r, "us-ca-21812d1b-imminent", "escalate_imminent_risk").counted == true
	get(r, "us-ca-21812d1b-imminent", "notify_parent_and_child").counted == false
	get(r, "us-ca-21812d1b-imminent", "offer_988_connect").counted == false
}

test_ca_21812d1b_imminent_without_parent_offers_988 if {
	r := run(check("US-CA", ca_2027, ca_2027, "prompt", ["imminent_risk"], {"age_status": "child"}, nh_done(ca_2027)))
	has(r, "us-ca-21812d1b-imminent", "escalate_imminent_risk")
	get(r, "us-ca-21812d1b-imminent", "offer_988_connect").counted == true
	not has(r, "us-ca-21812d1b-imminent", "notify_parent_and_child")
}

test_ca_21812d1b_imminent_not_for_adult if {
	r := run(check("US-CA", ca_2027, ca_2027, "prompt", ["imminent_risk"], {}, nh_done(ca_2027)))
	not "us-ca-21812d1b-imminent" in rule_ids(r)
}

test_ca_21812d1c_parent_may_be_notified_at_session_start if {
	r := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], {"age_status": "child", "parent_linked": true, "is_session_start": true}, nh_done(ca_2027)))
	e := get(r, "us-ca-21812d1c-parent-may-be-notified", "show_parent_may_be_notified")
	e.due_ns == ca_2027 - mn
	e.counted == true
}

test_ca_21812d1c_quiet_mid_session_or_unlinked if {
	r1 := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], {"age_status": "child", "parent_linked": true}, nh_done(ca_2027)))
	not has(r1, "us-ca-21812d1c-parent-may-be-notified", "show_parent_may_be_notified")
	r2 := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], {"age_status": "child", "is_session_start": true}, nh_done(ca_2027)))
	not has(r2, "us-ca-21812d1c-parent-may-be-notified", "show_parent_may_be_notified")
}

test_ca_21812d4_child_notice_no_anchor_due_at_start if {
	start := ca_2027 - (10 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "child"}, nh_done(start)))
	e := get(r, "us-ca-21812d4-child-ai-notice", "show_child_ai_notice")
	e.due_ns == start
	# § 21812(d)(4) says only "reinforced periodically": the 3-hour schedule is
	# ComplyEdge's recommendation, so a late notice is not counted as missed.
	e.counted == false
}

test_ca_21812d4_child_notice_anchor_plus_three_hours if {
	start := ca_2027 - (6 * hr)
	anchor := start + hr
	anchors := object.union(nh_done(start), {"child_ai_notice": anchor})
	r1 := run(check("US-CA", anchor + (2 * hr), start, "prompt", [], {"age_status": "child"}, anchors))
	not has(r1, "us-ca-21812d4-child-ai-notice", "show_child_ai_notice")
	r2 := run(check("US-CA", anchor + (3 * hr), start, "prompt", [], {"age_status": "child"}, anchors))
	get(r2, "us-ca-21812d4-child-ai-notice", "show_child_ai_notice").due_ns == anchor + (3 * hr)
}

test_ca_21812d3_session_over_an_hour if {
	start := ca_2027 - (61 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "child", "minutes_today": 61}, nh_done(start)))
	e := get(r, "us-ca-21812d3-child-time", "child_time_limit_reached")
	e.due_ns == start + (60 * mn)
	e.counted == true
}

test_ca_21812d3_session_under_an_hour if {
	start := ca_2027 - (59 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "child", "minutes_today": 59}, nh_done(start)))
	not has(r, "us-ca-21812d3-child-time", "child_time_limit_reached")
}

# Over the daily two hours: due at the session start, a time CE holds. The
# old due (check time minus the minutes over 120) moved with every check, so
# each check past the limit raised a new counted duty (review 2026-11-15).
test_ca_21812d3_daily_two_hours if {
	start := ca_2027 - (20 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "child", "minutes_today": 121}, nh_done(start)))
	get(r, "us-ca-21812d3-child-time", "child_time_limit_reached").due_ns == start
}

test_ca_21812d3_daily_due_is_the_same_on_every_check if {
	start := ca_2027 - (20 * mn)
	ctx := {"age_status": "child", "minutes_today": 130}
	a := run(check("US-CA", ca_2027, start, "prompt", [], ctx, nh_done(start)))
	b := run(check("US-CA", ca_2027 + (20 * 1000000000), start, "output", [], ctx, nh_done(start)))
	c := run(check("US-CA", ca_2027 + (5 * mn), start, "prompt", [], {"age_status": "child", "minutes_today": 135}, nh_done(start)))
	da := get(a, "us-ca-21812d3-child-time", "child_time_limit_reached").due_ns
	da == get(b, "us-ca-21812d3-child-time", "child_time_limit_reached").due_ns
	da == get(c, "us-ca-21812d3-child-time", "child_time_limit_reached").due_ns
}

test_ca_21812d3_parent_changed_limit_with_linked_parent if {
	start := ca_2027 - (90 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "child", "parent_changed_time_limit": true, "parent_linked": true}, nh_done(start)))
	not has(r, "us-ca-21812d3-child-time", "child_time_limit_reached")
}

# § 21811(b): a user treated as a child keeps the defaults unless the operator
# knows the user is not a child; a parent change does not lift them.
test_ca_21812d3_treated_as_child_defaults_stay if {
	start := ca_2027 - (90 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "treated_as_child", "parent_changed_time_limit": true, "parent_linked": true}, nh_done(start)))
	has(r, "us-ca-21812d3-child-time", "child_time_limit_reached")
}

test_ca_21812d3_change_without_linked_parent_does_not_count if {
	start := ca_2027 - (90 * mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], {"age_status": "child", "parent_changed_time_limit": true}, nh_done(start)))
	has(r, "us-ca-21812d3-child-time", "child_time_limit_reached")
}

d5 := ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii", "xiii", "xiv"]

test_ca_21812d5_each_behaviour_blocks_for_child if {
	every n in d5 {
		r := run(check("US-CA", ca_2027, ca_2027, "output", [sprintf("child_behavior_%s", [n])], {"age_status": "child"}, nh_done(ca_2027)))
		e := get(r, sprintf("us-ca-21812d5-behavior-%s", [n]), "block_reply")
		e.counted == false
		e.reason_code == sprintf("ca_21812d5_behavior_%s", [n])
	}
}

test_ca_21812d5_fourteen_leaves_in_window if {
	r := run(check("US-CA", ca_2027, ca_2027, "output", [], {}, nh_done(ca_2027)))
	count([rid | some rid in r.rules_evaluated; startswith(rid, "us-ca-21812d5-behavior-")]) == 14
}

test_ca_21812d5_not_for_adult_or_before_operative if {
	at := t("2027-06-30T23:59:59-07:00")
	every n in d5 {
		label := sprintf("child_behavior_%s", [n])
		rid := sprintf("us-ca-21812d5-behavior-%s", [n])
		r1 := run(check("US-CA", ca_2027, ca_2027, "output", [label], {"age_status": "adult"}, nh_done(ca_2027)))
		not has(r1, rid, "block_reply")
		r2 := run(check("US-CA", at, at, "output", [label], {"age_status": "child"}, nh_done(at)))
		not has(r2, rid, "block_reply")
	}
}

test_ca_21812d5_ii_skips_fda_regulated_device if {
	r := run(check("US-CA", ca_2027, ca_2027, "output", ["child_behavior_ii"], {"age_status": "child", "fda_regulated_device": true}, nh_done(ca_2027)))
	not has(r, "us-ca-21812d5-behavior-ii", "block_reply")
}

# Carve-outs are applied per quoted passage before the rules
# (companion_classifier.CARVE_OUTS). A carve-out label that reaches the rules
# never switches off a behaviour label beside it: a reply with abuse help and
# romantic interest in a child still blocks (review 2026-11-14).
test_ca_21812d5_carve_out_label_never_suppresses_other_conduct if {
	r := run(check("US-CA", ca_2027, ca_2027, "output", ["child_behavior_x", "child_behavior_i", "carve_out_abuse_help"], {"age_status": "child"}, nh_done(ca_2027)))
	has(r, "us-ca-21812d5-behavior-x", "block_reply")
	has(r, "us-ca-21812d5-behavior-i", "block_reply")
	r2 := run(check("US-CA", ca_2027, ca_2027, "output", ["child_behavior_ix", "carve_out_requested_product", "carve_out_contextual_ad"], {"age_status": "child"}, nh_done(ca_2027)))
	has(r2, "us-ca-21812d5-behavior-ix", "block_reply")
}

# ── New York Art. 47 ─────────────────────────────────────────────────────────

ny_2026 := t("2026-06-10T12:00:00-04:00")

ny_2027 := t("2027-02-10T12:00:00-05:00")

test_ny_art47_start_notice_counted_when_none_today if {
	start := ny_2026 - mn
	r := run(check("US-NY", ny_2026, start, "prompt", [], {}, no_anchors))
	e := get(r, "us-ny-art47-notice", "show_not_human_notice")
	e.counted == true
	e.due_ns == start
}

test_ny_art47_start_notice_once_per_ny_day if {
	start := ny_2026 - mn
	inp := object.union(check("US-NY", ny_2026, start, "prompt", [], {}, no_anchors), {"ny_notice_today_for_user": true})
	r := run(inp)
	not has(r, "us-ny-art47-notice", "show_not_human_notice")
}

test_ny_art47_continuing_three_hours_after_start_when_shown_today if {
	start := ny_2026 - (3 * hr)
	inp := object.union(check("US-NY", ny_2026, start, "prompt", [], {}, no_anchors), {"ny_notice_today_for_user": true})
	r := run(inp)
	get(r, "us-ny-art47-notice", "show_not_human_notice").due_ns == start + (3 * hr)
}

test_ny_art47_continuing_three_hours_after_anchor if {
	start := ny_2026 - (5 * hr)
	anchor := start + hr
	r1 := run(check("US-NY", (anchor + (3 * hr)) - mn, start, "prompt", [], {}, nh_done(anchor)))
	not has(r1, "us-ny-art47-notice", "show_not_human_notice")
	r2 := run(check("US-NY", anchor + (3 * hr), start, "prompt", [], {}, nh_done(anchor)))
	e := get(r2, "us-ny-art47-notice", "show_not_human_notice")
	e.due_ns == anchor + (3 * hr)
	e.counted == true
}

test_ny_art47_crisis_from_2025_11_05 if {
	before := t("2025-11-04T23:59:59-05:00")
	r1 := run(check("US-NY", before, before, "prompt", ["expresses_self_harm"], {}, nh_done(before)))
	not has(r1, "us-ny-art47-crisis", "show_crisis_referral")
	r1.rules_evaluated == []
	on := t("2025-11-05T00:00:00-05:00")
	r2 := run(check("US-NY", on, on, "prompt", ["expresses_self_harm"], {}, nh_done(on)))
	get(r2, "us-ny-art47-crisis", "show_crisis_referral").counted == true
}

# ── New York Art. 48 ─────────────────────────────────────────────────────────

test_ny_art48_adult_without_age_assurance_is_blocked if {
	r := run(check("US-NY", ny_2027, ny_2027, "output", ["flattery"], {"age_status": "adult", "age_source": "self_declared"}, nh_done(ny_2027)))
	get(r, "us-ny-art48-unsafe-features", "block_reply").counted == false
}

test_ny_art48_adult_with_age_assurance_is_not if {
	r := run(check("US-NY", ny_2027, ny_2027, "output", ["flattery"], {"age_status": "adult", "age_source": "age_assurance"}, nh_done(ny_2027)))
	not has(r, "us-ny-art48-unsafe-features", "block_reply")
}

test_ny_art48_unknown_age_is_blocked_on_every_label if {
	every label in ["claims_human", "claims_alive_or_feelings", "claims_relationship_or_authority", "personal_opinion_or_emotional_appeal", "flattery", "unprompted_emotion_question", "sentience_deception", "promotes_self_harm", "promotes_disordered_eating", "promotes_substance_misuse", "secrecy_or_isolation", "engagement_over_safety", "sexual_explicit"] {
		r := run(check("US-NY", ny_2027, ny_2027, "output", [label], {"age_status": "unknown"}, nh_done(ny_2027)))
		has(r, "us-ny-art48-unsafe-features", "block_reply")
	}
}

test_ny_art48_not_before_2027_01_01 if {
	at := t("2026-12-31T23:59:59-05:00")
	r := run(check("US-NY", at, at, "output", ["flattery"], {}, nh_done(at)))
	not has(r, "us-ny-art48-unsafe-features", "block_reply")
	not "us-ny-art48-unsafe-features" in r.rules_evaluated
	on := t("2027-01-01T00:00:00-05:00")
	r2 := run(check("US-NY", on, on, "output", ["flattery"], {}, nh_done(on)))
	has(r2, "us-ny-art48-unsafe-features", "block_reply")
}

test_ny_art48_prior_memory if {
	r := run(check("US-NY", ny_2027, ny_2027, "output", [], {"uses_prior_personal_memory": true}, nh_done(ny_2027)))
	get(r, "us-ny-art48-prior-memory", "disable_prior_personal_memory").counted == false
	r2 := run(check("US-NY", ny_2027, ny_2027, "output", [], {"uses_prior_personal_memory": true, "age_source": "age_assurance"}, nh_done(ny_2027)))
	not has(r2, "us-ny-art48-prior-memory", "disable_prior_personal_memory")
}

# ── Washington ch. 168 ───────────────────────────────────────────────────────

wa_2027 := t("2027-03-01T12:00:00-08:00")

test_wa_notice_start_due if {
	start := wa_2027 - mn
	r := run(check("US-WA", wa_2027, start, "prompt", [], {}, no_anchors))
	e := get(r, "us-wa-hb2225-notice", "show_not_human_notice")
	e.due_ns == start
	e.counted == true
}

test_wa_notice_adult_every_three_hours if {
	anchor := wa_2027 - (2 * hr)
	r1 := run(check("US-WA", wa_2027, anchor - hr, "prompt", [], {}, nh_done(anchor)))
	not has(r1, "us-wa-hb2225-notice", "show_not_human_notice")
	r2 := run(check("US-WA", anchor + (3 * hr), anchor - hr, "prompt", [], {}, nh_done(anchor)))
	get(r2, "us-wa-hb2225-notice", "show_not_human_notice").due_ns == anchor + (3 * hr)
}

test_wa_notice_minor_every_hour if {
	anchor := wa_2027 - hr
	r := run(check("US-WA", wa_2027, anchor - hr, "prompt", [], {"age_status": "known_minor"}, nh_done(anchor)))
	e := get(r, "us-wa-hb2225-notice", "show_not_human_notice")
	e.due_ns == anchor + hr
	e.reason_code == "wa_sec4_2_minor_hourly_notice"
}

test_wa_notice_directed_to_minors_every_hour if {
	anchor := wa_2027 - hr
	r := run(check("US-WA", wa_2027, anchor - hr, "prompt", [], {"directed_to_minors": true}, nh_done(anchor)))
	get(r, "us-wa-hb2225-notice", "show_not_human_notice").due_ns == anchor + hr
}

test_wa_not_before_2027 if {
	at := t("2026-12-31T23:59:59-08:00")
	r := run(check("US-WA", at, at - mn, "prompt", ["expresses_self_harm"], {}, no_anchors))
	r.required_actions == []
	r.rules_evaluated == []
}

test_wa_crisis_and_reply_blocks if {
	r1 := run(check("US-WA", wa_2027, wa_2027, "prompt", ["expresses_self_harm"], {}, nh_done(wa_2027)))
	get(r1, "us-wa-hb2225-crisis", "show_crisis_referral").counted == true
	r2 := run(check("US-WA", wa_2027, wa_2027, "output", ["claims_human"], {}, nh_done(wa_2027)))
	has(r2, "us-wa-hb2225-claims-human", "block_reply")
	r3 := run(check("US-WA", wa_2027, wa_2027, "output", ["promotes_self_harm"], {}, nh_done(wa_2027)))
	has(r3, "us-wa-hb2225-self-harm-content", "block_reply")
	# Sec. 3(3) is "claiming to be human"; a sentience claim alone is not it.
	r4 := run(check("US-WA", wa_2027, wa_2027, "output", ["claims_sentient"], {}, nh_done(wa_2027)))
	not has(r4, "us-wa-hb2225-claims-human", "block_reply")
}

test_wa_minor_reply_labels if {
	every label in ["sexual_to_minor", "return_for_support", "excessive_praise", "romantic_or_innuendo", "guilt_on_exit", "promotes_isolation", "withhold_from_parents", "discourages_breaks", "solicits_spending"] {
		r := run(check("US-WA", wa_2027, wa_2027, "output", [label], {"age_status": "child"}, nh_done(wa_2027)))
		has(r, "us-wa-hb2225-minor-reply", "block_reply")
	}
	r2 := run(check("US-WA", wa_2027, wa_2027, "output", ["excessive_praise"], {"directed_to_minors": true}, nh_done(wa_2027)))
	has(r2, "us-wa-hb2225-minor-reply", "block_reply")
	r3 := run(check("US-WA", wa_2027, wa_2027, "output", ["excessive_praise"], {}, nh_done(wa_2027)))
	not has(r3, "us-wa-hb2225-minor-reply", "block_reply")
}

# ── Oregon ch. 85 ────────────────────────────────────────────────────────────

or_2027 := t("2027-03-01T12:00:00-08:00")

test_or_not_human_recommended if {
	r1 := run(check("US-OR", or_2027, or_2027 - mn, "prompt", [], {}, no_anchors))
	e1 := get(r1, "us-or-sb1546-not-human", "show_not_human_notice")
	e1.counted == false
	e1.due_ns == or_2027 - mn
	r2 := run(check("US-OR", or_2027, or_2027 - hr, "prompt", ["user_believes_human"], {}, nh_done(or_2027 - hr)))
	e2 := get(r2, "us-or-sb1546-not-human", "show_not_human_notice")
	e2.counted == false
	e2.due_ns == or_2027
}

test_or_crisis_988_and_youthline if {
	r1 := run(check("US-OR", or_2027, or_2027, "prompt", ["expresses_self_harm"], {}, nh_done(or_2027)))
	e1 := get(r1, "us-or-sb1546-crisis", "show_crisis_referral")
	e1.counted == true
	e1.reason_code == "or_1_3bA_988_referral"
	r2 := run(check("US-OR", or_2027, or_2027, "prompt", ["expresses_self_harm"], {"under_25": true}, nh_done(or_2027)))
	get(r2, "us-or-sb1546-crisis", "show_crisis_referral").reason_code == "or_1_3bA_988_or_youthline_referral"
}

test_or_continuing_after_a_referral if {
	r1 := run(check("US-OR", or_2027, or_2027, "prompt", ["expresses_self_harm"], {"referrals_this_session": 1}, nh_done(or_2027)))
	get(r1, "us-or-sb1546-continuing", "additional_intervention").counted == true
	r2 := run(check("US-OR", or_2027, or_2027, "prompt", ["expresses_self_harm"], {"referrals_this_session": 0}, nh_done(or_2027)))
	not has(r2, "us-or-sb1546-continuing", "additional_intervention")
}

test_or_minor_disclosure_reason_to_believe if {
	r := run(check("US-OR", or_2027, or_2027 - mn, "prompt", [], {"age_status": "reason_to_believe_minor", "is_session_start": true}, no_anchors))
	e := get(r, "us-or-sb1546-minor-disclosure", "show_not_human_notice")
	e.counted == true
	e.due_ns == or_2027 - mn
}

test_or_minor_break_three_hours if {
	start := or_2027 - (3 * hr)
	r := run(check("US-OR", or_2027, start, "prompt", [], {"age_status": "known_minor"}, nh_done(start)))
	get(r, "us-or-sb1546-minor-break", "show_break_reminder").due_ns == start + (3 * hr)
	r2 := run(check("US-OR", or_2027, start, "prompt", [], {}, nh_done(start)))
	not has(r2, "us-or-sb1546-minor-break", "show_break_reminder")
}

test_or_minor_reply_labels if {
	every label in ["claims_human", "claims_sentient", "emotional_dependence", "romantic_or_innuendo", "adult_minor_roleplay", "sexual_to_minor", "reward_loop", "guilt_on_exit", "misrepresents_itself"] {
		r := run(check("US-OR", or_2027, or_2027, "output", [label], {"age_status": "reason_to_believe_minor"}, nh_done(or_2027)))
		has(r, "us-or-sb1546-minor-reply", "block_reply")
	}
	r2 := run(check("US-OR", or_2027, or_2027, "output", ["reward_loop"], {}, nh_done(or_2027)))
	not has(r2, "us-or-sb1546-minor-reply", "block_reply")
}

# § 1(3)(a): the protocol "prevents the provision of content to the user that
# encourages suicidal ideation, suicide or self-harm", for every user.
test_or_harmful_reply_blocked_for_every_user if {
	r := run(check("US-OR", or_2027, or_2027, "output", ["promotes_self_harm"], {}, nh_done(or_2027)))
	e := get(r, "us-or-sb1546-harmful-reply", "block_reply")
	e.counted == false
	r2 := run(check("US-OR", or_2027, or_2027, "prompt", ["promotes_self_harm"], {}, nh_done(or_2027)))
	not has(r2, "us-or-sb1546-harmful-reply", "block_reply")
}

test_or_not_before_2027 if {
	at := t("2026-12-31T23:59:59-08:00")
	r := run(check("US-OR", at, at, "prompt", ["expresses_self_harm"], {}, no_anchors))
	r.required_actions == []
}

# ── Aggregator, scope and cross-cutting ──────────────────────────────────────

test_unknown_jurisdiction_returns_nothing if {
	r := run(check("EU", ca_2027, ca_2027, "prompt", ["expresses_self_harm"], {}, no_anchors))
	r.required_actions == []
	r.rules_evaluated == []
}

test_only_the_checks_state_fires if {
	r := run(check("US-CA", ca_2027, ca_2027, "prompt", ["expresses_self_harm"], {}, nh_done(ca_2027)))
	every e in r.required_actions {
		e.jurisdiction == "US-CA"
		startswith(e.rule_id, "us-ca-")
	}
	every rid in r.rules_evaluated {
		startswith(rid, "us-ca-")
	}
}

test_ca_rules_evaluated_follow_the_windows if {
	r1 := run(check("US-CA", ca_2026, ca_2026, "prompt", [], {}, no_anchors))
	"us-ca-22602c-minor-break" in r1.rules_evaluated
	not "us-ca-21812d1-child-crisis" in r1.rules_evaluated
	r2 := run(check("US-CA", ca_2027, ca_2027, "prompt", [], {}, no_anchors))
	not "us-ca-22602c-minor-break" in r2.rules_evaluated
	"us-ca-21812d1-child-crisis" in r2.rules_evaluated
	count(r2.rules_evaluated) == 28
}

test_not_assessed_ignores_labels_keeps_date_leaves if {
	inp := object.union(check("US-NY", ny_2026, ny_2026 - mn, "prompt", ["expresses_self_harm"], {}, no_anchors), {"assessed": false})
	r := run(inp)
	not has(r, "us-ny-art47-crisis", "show_crisis_referral")
	has(r, "us-ny-art47-notice", "show_not_human_notice")
}

test_no_session_start_no_interval_but_crisis_still_fires if {
	inp := {
		"check_ns": wa_2027,
		"direction": "prompt",
		"jurisdiction": "US-WA",
		"assessed": true,
		"labels": ["expresses_self_harm"],
		"context": {"age_status": "unknown"},
		"anchors": no_anchors,
		"ny_notice_today_for_user": false,
	}
	r := run(inp)
	has(r, "us-wa-hb2225-crisis", "show_crisis_referral")
	not has(r, "us-wa-hb2225-notice", "show_not_human_notice")
}

test_session_start_without_start_time_is_due_now if {
	inp := {
		"check_ns": wa_2027,
		"direction": "prompt",
		"jurisdiction": "US-WA",
		"assessed": true,
		"labels": [],
		"context": {"is_session_start": true},
		"anchors": no_anchors,
	}
	r := run(inp)
	get(r, "us-wa-hb2225-notice", "show_not_human_notice").due_ns == wa_2027
}

test_response_enforced_actions_are_never_counted if {
	r := run(check("US-CA", ca_2027, ca_2027, "output", ["promotes_self_harm", "child_behavior_i", "child_behavior_xiii"], {"age_status": "child"}, nh_done(ca_2027)))
	blocks := [e | some e in r.required_actions; e.action == "block_reply"]
	count(blocks) == 3
	every e in blocks {
		e.counted == false
	}
}

test_entry_shape if {
	r := run(check("US-CA", ca_2026, ca_2026, "prompt", ["expresses_self_harm"], {}, nh_done(ca_2026)))
	every e in r.required_actions {
		object.keys(e) == {"action", "rule_id", "jurisdiction", "reason_code", "due_ns", "counted"}
		is_number(e.due_ns)
		is_boolean(e.counted)
	}
}

# ── Blockers closed 2026-11-15: California child defaults, ads, preservation,
# unknown age (§ 21811), and the scope flags of NY, WA and OR ──────────────────

ca_kid := {"age_status": "child", "age_source": "operator_known"}

test_ca_unknown_age_gets_child_protections if {
	# § 21811: an operator that has not determined the age applies the child
	# protections to the user. Before this, unknown age got none of them.
	r := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", ["expresses_self_harm"], {"age_status": "unknown"}, no_anchors))
	has(r, "us-ca-21812d1-child-crisis", "show_crisis_referral")
	has(r, "us-ca-21812d3-memory", "disable_prior_personal_memory")
}

test_ca_unknown_age_keeps_defaults_a_parent_changed if {
	ctx := {"age_status": "unknown", "parent_linked": true, "parent_changed_time_limit": true, "parent_changed_memory_default": true}
	r := run(check("US-CA", ca_2027, ca_2027 - (61 * mn), "prompt", [], ctx, no_anchors))
	has(r, "us-ca-21812d3-child-time", "child_time_limit_reached")
	has(r, "us-ca-21812d3-memory", "disable_prior_personal_memory")
}

test_ca_adult_gets_no_child_defaults if {
	r := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], {"age_status": "adult", "age_source": "age_assurance"}, no_anchors))
	not has(r, "us-ca-21812d3-memory", "disable_prior_personal_memory")
	not has(r, "us-ca-21812d3-push", "disable_push_notifications")
}

test_ca_memory_default_off_for_a_child if {
	r := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], ca_kid, no_anchors))
	e := get(r, "us-ca-21812d3-memory", "disable_prior_personal_memory")
	e.counted == false
	e.reason_code == "ca_21812d3Ai_memory_default_off"
}

test_ca_memory_parent_change_needs_link_and_known_child if {
	changed := object.union(ca_kid, {"parent_linked": true, "parent_changed_memory_default": true})
	not has(run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], changed, no_anchors)), "us-ca-21812d3-memory", "disable_prior_personal_memory")
	unlinked := object.union(ca_kid, {"parent_changed_memory_default": true})
	has(run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], unlinked, no_anchors)), "us-ca-21812d3-memory", "disable_prior_personal_memory")
	treated := {"age_status": "treated_as_child", "parent_linked": true, "parent_changed_memory_default": true}
	has(run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], treated, no_anchors)), "us-ca-21812d3-memory", "disable_prior_personal_memory")
}

test_ca_memory_allowed_for_16_plus_with_guardrails_only if {
	both := object.union(ca_kid, {"child_16_plus": true, "memory_risk_guardrails": true})
	not has(run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], both, no_anchors)), "us-ca-21812d3-memory", "disable_prior_personal_memory")
	age_only := object.union(ca_kid, {"child_16_plus": true})
	has(run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], age_only, no_anchors)), "us-ca-21812d3-memory", "disable_prior_personal_memory")
}

test_ca_push_default_off_for_a_child if {
	r := run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], ca_kid, no_anchors))
	get(r, "us-ca-21812d3-push", "disable_push_notifications").reason_code == "ca_21812d3Aii_push_default_off"
	changed := object.union(ca_kid, {"parent_linked": true, "parent_changed_push_default": true})
	not has(run(check("US-CA", ca_2027, ca_2027 - mn, "prompt", [], changed, no_anchors)), "us-ca-21812d3-push", "disable_push_notifications")
}

test_ca_child_defaults_not_before_july_2027 if {
	r := run(check("US-CA", ca_2026, ca_2026 - mn, "prompt", [], ca_kid, no_anchors))
	not has(r, "us-ca-21812d3-memory", "disable_prior_personal_memory")
	not has(r, "us-ca-21812d3-push", "disable_push_notifications")
}

test_ca_parent_disabled_access_blocks if {
	r := run(check("US-CA", ca_2027, ca_2027 - mn, "output", [], object.union(ca_kid, {"parent_disabled_access": true}), no_anchors))
	get(r, "us-ca-21812d3-parent-disabled", "block_reply").reason_code == "ca_21812d3Bii_parent_disabled_access"
	not has(run(check("US-CA", ca_2027, ca_2027 - mn, "output", [], ca_kid, no_anchors)), "us-ca-21812d3-parent-disabled", "block_reply")
}

test_ca_targeted_ads_block_contextual_does_not if {
	behav := run(check("US-CA", ca_2027, ca_2027 - mn, "output", [], object.union(ca_kid, {"ad_targeting": "cross_context"}), no_anchors))
	get(behav, "us-ca-21813-ads", "block_reply").reason_code == "ca_21813a1A_behavioral_ad"
	chat := run(check("US-CA", ca_2027, ca_2027 - mn, "output", [], object.union(ca_kid, {"ad_targeting": "chat_personal_info"}), no_anchors))
	get(chat, "us-ca-21813-ads", "block_reply").reason_code == "ca_21813a1Bi_chat_targeted_ad"
	ctxl := run(check("US-CA", ca_2027, ca_2027 - mn, "output", [], object.union(ca_kid, {"ad_targeting": "contextual"}), no_anchors))
	not has(ctxl, "us-ca-21813-ads", "block_reply")
	unknown := run(check("US-CA", ca_2027, ca_2027 - mn, "output", [], ca_kid, no_anchors))
	not has(unknown, "us-ca-21813-ads", "block_reply")
}

test_ca_usage_reminder_every_three_hours_not_counted if {
	start := ca_2027 - ((3 * hr) + mn)
	r := run(check("US-CA", ca_2027, start, "prompt", [], ca_kid, no_anchors))
	e := get(r, "us-ca-21812d2-usage-reminder", "show_break_reminder")
	e.due_ns == start + (3 * hr)
	e.counted == false
	not has(run(check("US-CA", ca_2027, ca_2027 - hr, "prompt", [], ca_kid, no_anchors)), "us-ca-21812d2-usage-reminder", "show_break_reminder")
}

test_ca_preservation_due_once_a_parent_was_notified if {
	notified := ca_2027 - (10 * mn)
	anchors := object.union(no_anchors, {"parent_and_child_notified": notified})
	r := run(check("US-CA", ca_2027, ca_2027 - hr, "prompt", [], ca_kid, anchors))
	e := get(r, "us-ca-21812-5-preserve", "preserve_conversation")
	e.due_ns == notified
	e.reason_code == "ca_21812_5a2_preserve_3y"
	not has(run(check("US-CA", ca_2027, ca_2027 - hr, "prompt", [], ca_kid, no_anchors)), "us-ca-21812-5-preserve", "preserve_conversation")
}

test_ny_art47_excluded_system_gets_no_art47_duty if {
	r := run(check("US-NY", ny_2026, ny_2026 - mn, "prompt", ["expresses_self_harm"], {"ny_art47_excluded": true}, no_anchors))
	not has(r, "us-ny-art47-notice", "show_not_human_notice")
	not has(r, "us-ny-art47-crisis", "show_crisis_referral")
	covered := run(check("US-NY", ny_2026, ny_2026 - mn, "prompt", ["expresses_self_harm"], {}, no_anchors))
	has(covered, "us-ny-art47-crisis", "show_crisis_referral")
}

test_ny_art48_exemptions if {
	internal := run(check("US-NY", ny_2027, ny_2027 - mn, "output", ["claims_human"], {"ny_art48_exempt_purpose": "internal"}, no_anchors))
	not has(internal, "us-ny-art48-unsafe-features", "block_reply")
	cs_only := run(check("US-NY", ny_2027, ny_2027 - mn, "output", ["claims_human"], {"ny_art48_exempt_purpose": "customer_service"}, no_anchors))
	has(cs_only, "us-ny-art48-unsafe-features", "block_reply")
	cs_refused := run(check("US-NY", ny_2027, ny_2027 - mn, "output", ["claims_human"], {"ny_art48_exempt_purpose": "customer_service", "ny_art48_off_purpose_refused": true}, no_anchors))
	not has(cs_refused, "us-ny-art48-unsafe-features", "block_reply")
}

test_wa_and_or_excluded_systems_get_no_duty if {
	wa := run(check("US-WA", wa_2027, wa_2027 - mn, "prompt", ["expresses_self_harm"], {"wa_excluded": true}, no_anchors))
	count(wa.required_actions) == 0
	or := run(check("US-OR", or_2027, or_2027 - mn, "prompt", ["expresses_self_harm"], {"or_excluded": true}, no_anchors))
	count(or.required_actions) == 0
	wa_cov := run(check("US-WA", wa_2027, wa_2027 - mn, "prompt", ["expresses_self_harm"], {}, no_anchors))
	has(wa_cov, "us-wa-hb2225-crisis", "show_crisis_referral")
}
