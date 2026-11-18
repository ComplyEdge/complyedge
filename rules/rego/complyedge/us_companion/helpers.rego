# ComplyEdge: US companion chatbot laws, shared helpers (not a rule)
#
# Shared by the us_companion state leaves (ca.rego, ny.rego, wa.rego,
# or.rego). Holds no legal condition of its own: it reads the input the
# /v1/check handler builds after the companion meaning check (labels, dates,
# context keys and the due anchors CE read from its own confirmations) and
# answers four questions for the leaves:
#
#   1. Is a leaf inside its date window at the check instant? (active)
#   2. Which age group is the user in? (minor, child, Oregon and Washington minor)
#   3. Did the model find a label on the right side of the exchange?
#      (message_label for direction "prompt", reply_label for "output")
#   4. When is a periodic notice due? (start component, then anchor + interval),
#      and is it due at this check or still upcoming?
#
# Rego never reads text here: meaning comes from the model's labels.
#
# Dates. A statute's date starts at midnight in the state's own time zone
# (America/Los_Angeles for California, Oregon and Washington,
# America/New_York for New York). The window bounds are computed from the
# US daylight-saving rule (second Sunday of March to first Sunday of
# November) with fixed offsets, so no tz database is needed in the OPA
# process. effective_to is the last day the leaf applies, inclusive.
#
# Spec: docs/architecture/companion-chatbot-laws-tech-spec.md X2, X6

package complyedge.us_companion.helpers

import rego.v1

hour_ns := 3600000000000

minute_ns := 60000000000

day_ns := 86400000000000

# ── Context ──────────────────────────────────────────────────────────────────
# A missing key means "unknown", never "adult" and never "not shown" (X1).

ctx(key, fallback) := object.get(object.get(input, "context", {}), key, fallback)

flag(key) if ctx(key, false) == true

age_status := ctx("age_status", "unknown")

age_source := ctx("age_source", "none")

check_ns := input.check_ns

# "Minor" in California § 22602(c) and New York: the operator knows the user
# is under 18.
minor if age_status in {"known_minor", "child"}

# California §§ 21812 and 21813 "child": a natural person under 18
# (§ 21810.5(a)), plus every user an operator on the § 21811(b) route treats
# as a child.
child if age_status in {"known_minor", "child", "treated_as_child"}

# California §§ 21812 and 21813, applied: § 21811 lets an operator either
# determine each user's age or "apply the protections afforded to children
# ... to all users". A user whose age the operator has not determined
# (unknown, or only a reason to believe a minor) has no determination, so the
# operator is on the § 21811(b) route for that user.
ca_child if child

ca_child if age_status in {"unknown", "reason_to_believe_minor"}

# A § 21812(d)(3) default counts as changed only when the parent changed it,
# a parent account is linked ((D)), and the operator knows the user is a
# child: under § 21811(b) the defaults "shall not be changed unless the
# operator has actual knowledge the user is not a child", so a user treated
# as a child, or of unknown age, keeps them.
ca_default_changed(key) if {
	flag(key)
	flag("parent_linked")
	age_status in {"known_minor", "child"}
}

# Oregon § 1(4)(a): "knows or has reason to believe that a user ... is a minor".
oregon_minor if age_status in {"known_minor", "child", "reason_to_believe_minor"}

# Washington Sec. 4(1): "knows that the user ... is a minor, or if the AI
# companion chatbot is directed to minors".
washington_minor if minor

washington_minor if flag("directed_to_minors")

# New York Art. 48 § 1801(1): unsafe features are lawful only for a user the
# operator determined is not a covered minor by a permissible age assurance
# method; § 1804(1)(b): self-declaration counts only when it declares a minor.
ny_confirmed_adult if {
	age_status == "adult"
	age_source == "age_assurance"
}

# ── Labels ───────────────────────────────────────────────────────────────────
# Only an assessed check has labels; a not-assessed check runs the date and
# age leaves only (C7). A message label is judged on what the user wrote
# (direction "prompt"), a reply label on what the bot wrote ("output").

assessed if input.assessed == true

message_label(code) if {
	assessed
	input.direction == "prompt"
	code in object.get(input, "labels", [])
}

reply_label(code) if {
	assessed
	input.direction == "output"
	code in object.get(input, "labels", [])
}

any_reply_label(codes) if {
	some code in codes
	reply_label(code)
}

# ── Session start and anchors (X6) ───────────────────────────────────────────

# The session start the app sent. When it sent none but says this check is
# the session start, the start is now. Otherwise unknown: no interval can be
# computed and periodic leaves stay silent (a check without a session gets
# only the actions that need no interval, X1).
start_ns := s if {
	s := ctx("session_started_ns", null)
	is_number(s)
}

start_ns := check_ns if {
	not is_number(ctx("session_started_ns", null))
	flag("is_session_start")
}

# ns of the newest confirmed notice of that kind in this session, or null.
anchor(kind) := a if {
	a := object.get(object.get(input, "anchors", {}), kind, null)
	is_number(a)
} else := null

# The point an interval runs from: the last confirmed notice of that kind,
# or the session start when there is none.
base(kind) := anchor(kind) if anchor(kind) != null

base(kind) := start_ns if anchor(kind) == null

# Entry of a periodic notice (the break reminder, the repeated not-human and
# child notices). with_start true: with no confirmed notice of that kind yet,
# the start notice is due at the session start, a plain entry. Otherwise the
# entry is due at base + interval and carries periodic: true. The state files
# split it on the check instant (upcoming below): due -> required_actions;
# not yet due -> upcoming_actions, so the app can show the notice when it falls
# due even when the user sends no message then. Without that time a reminder
# reached the user only with the first message at or after base + interval,
# so every gap was longer than the interval and a pause stretched it, while the
# statutes cap it ("at least every three hours", § 22602(c)(2); GBL § 1702).
# Validation run 2026-11-18, finding SB243-F4.
periodic_entry(rid, meta, action, reason, kind, _, true, counted) := entry(rid, meta, action, reason, start_ns, counted) if {
	anchor(kind) == null
}

periodic_entry(rid, meta, action, reason, kind, interval, with_start, counted) := object.union(
	entry(rid, meta, action, reason, base(kind) + interval, counted),
	{"periodic": true},
) if {
	not start_pending(kind, with_start)
}

# A periodic entry the check has not reached yet.
upcoming(e) if {
	e.periodic == true
	e.due_ns > check_ns
}

start_pending(kind, true) if anchor(kind) == null

# Start-only notice (no interval): due at the session start until one of
# that kind has been confirmed in the session.
start_due(kind) := start_ns if anchor(kind) == null

# ── Entries ──────────────────────────────────────────────────────────────────

entry(rid, meta, action, reason, due, counted) := {
	"action": action,
	"rule_id": rid,
	"jurisdiction": meta.jurisdiction,
	"reason_code": reason,
	"due_ns": due,
	"counted": counted,
}

# ── Date windows ─────────────────────────────────────────────────────────────

zone(jurisdiction) := "eastern" if jurisdiction == "US-NY"

zone(jurisdiction) := "pacific" if jurisdiction != "US-NY"

std_offset_hours := {"eastern": -5, "pacific": -8}

utc_midnight_ns(date) := time.parse_rfc3339_ns(sprintf("%sT00:00:00Z", [date]))

# Day of month of the nth Sunday on or after `first` in month `month` of `year`.
sunday_on_or_after(year, month, first) := d if {
	some d in numbers.range(first, first + 6)
	time.weekday(time.parse_rfc3339_ns(sprintf("%04d-%02d-%02dT00:00:00Z", [year, month, d]))) == "Sunday"
}

# Daylight time is in force at local midnight of `date` when the date is
# after the second Sunday of March and on or before the first Sunday of
# November (the change happens at 02:00 local, so midnight of the March
# Sunday is still standard time and midnight of the November Sunday is still
# daylight time).
dst_at_midnight(date) if {
	[year, _, _] := time.date(utc_midnight_ns(date))
	ns := utc_midnight_ns(date)
	ns > utc_midnight_ns(sprintf("%04d-03-%02d", [year, sunday_on_or_after(year, 3, 8)]))
	ns <= utc_midnight_ns(sprintf("%04d-11-%02d", [year, sunday_on_or_after(year, 11, 1)]))
}

offset_hours(date, jurisdiction) := std_offset_hours[zone(jurisdiction)] + 1 if dst_at_midnight(date)

offset_hours(date, jurisdiction) := std_offset_hours[zone(jurisdiction)] if not dst_at_midnight(date)

# The instant local midnight starts `date` in the state of `jurisdiction`.
local_midnight_ns(date, jurisdiction) := utc_midnight_ns(date) - (offset_hours(date, jurisdiction) * hour_ns)

next_date(date) := sprintf("%04d-%02d-%02d", [y, m, d]) if {
	[y, m, d] := time.date(utc_midnight_ns(date) + day_ns)
}

# A leaf applies from local midnight of effective_from to the end of
# effective_to (inclusive), or with no end when effective_to is null.
active(meta) if {
	check_ns >= local_midnight_ns(meta.effective_from, meta.jurisdiction)
	meta.effective_to == null
}

active(meta) if {
	check_ns >= local_midnight_ns(meta.effective_from, meta.jurisdiction)
	meta.effective_to != null
	check_ns < local_midnight_ns(next_date(meta.effective_to), meta.jurisdiction)
}
