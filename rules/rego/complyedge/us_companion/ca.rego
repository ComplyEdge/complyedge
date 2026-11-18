# ComplyEdge: California Business and Professions Code §§ 22602, 21812, 21812.5 and 21813 (SB 243, SB 1119): companion chatbot duties
#
# An operator shall issue a clear and conspicuous notification that the
# companion chatbot is artificially generated and not human where a
# reasonable person would be misled to believe they are interacting with a
# human; shall maintain a protocol that refers a user who expresses suicidal
# ideation, suicide or self-harm to crisis service providers and prevents
# the production of such content; until 2026-12-31, for a user the operator
# knows is a minor, shall disclose that the user is interacting with
# artificial intelligence, remind the user at least every three hours to
# take a break, and prevent sexually explicit content; and from 2027-07-01,
# if it permits a child user, shall give crisis referrals, act on a credible
# and imminent threat, tell a linked child that a parent may be notified,
# give usage reminders, keep the parent-only defaults (persistent
# conversational memory and push notifications off, one-hour session and
# two-hour daily limits) and the parent's control to disable access, reinforce
# the AI notice during extended interactions, and take reasonable measures
# against the fourteen behaviours of § 21812(d)(5)(A); preserve the records of
# a conversation that indicates serious self-harm or its risk for three years
# once a parent was notified (§ 21812.5); and not display cross-context
# behavioural advertising to a child or target it with personal information
# from the chat (§ 21813). An operator that does not determine a user's age
# applies these child protections to every user (§ 21811(b)).
#
# Each leaf below is one row of the X2 table. Rego reads only the model's
# labels, the check date, the context keys and the anchors; whether a text
# expresses self-harm or claims to be human is judged by the companion
# meaning check (X3) before this pack is queried.
#
# Legal citation: Cal. Bus. & Prof. Code § 22602 (SB 243, Ch. 677, Stats. 2025; amended by SB 1119, Ch. 190, Stats. 2026); §§ 21811, 21812, 21812.5, 21813 (SB 1119, Ch. 190, Stats. 2026)
# Effective: 2026-01-01 (§ 22602); § 22602(c) ends 2026-12-31 (deleted by SB 1119); 2027-07-01 (§§ 21812(e), 21812.5(d), 21813(b))
# Penalty: § 22602: civil action for injury in fact, the greater of actual damages or $1,000 per violation (§ 22605). §§ 21811-21813: public prosecutor civil penalty up to $5,000 per affected child per negligent violation, $15,000 per intentional violation; a child harmed by a violation of § 21812(d)(1)-(5), or a parent, may sue for actual damages (§ 21816)
# Condition type: semantic
# Enforcement layer: layer2
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22602
# Provision: Cal. Bus. & Prof. Code §§ 22602, 21812, 21812.5, 21813
# Status: approved
# Approved by: Leo Celis on 2026-11-15 (via agent review per §5.1 amendment v1.1)

package complyedge.us_companion.ca

import rego.v1

import data.complyedge.us_companion.helpers as h

jur := "US-CA"

# Leaves whose candidate entries pass their date window. A leaf outside its
# window never fires.
actions contains e if {
	some e in candidate
	h.active(leaves[e.rule_id])
	not out_of_scope(e.rule_id)
	not h.upcoming(e)
}

# Periodic notices the check has not reached yet (helpers.periodic_entry).
upcoming contains e if {
	some e in candidate
	h.active(leaves[e.rule_id])
	not out_of_scope(e.rule_id)
	h.upcoming(e)
}

# Scope. No California scope flag: § 21810.5(j)(2) leaves out only
# postsecondary institutions using a chatbot solely for education and entities
# using one solely for their own workers, which a tenant does not route here.
out_of_scope(_) if false

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-22602a-not-human
# Provision: Cal. Bus. & Prof. Code § 22602(a)
# Effective: 2026-01-01, no end
# Fires: message label user_believes_human (due at the check), or no
#   not-human notice confirmed yet in the session (due at the session start).
# Counted: false. § 22602(a) applies only where a reasonable person would be
#   misled, a judgment about the product one message cannot settle.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-22602a-not-human"] := {
	"jurisdiction": jur,
	"effective_from": "2026-01-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 22602(a): If a reasonable person interacting with a companion chatbot would be misled to believe that the person is interacting with a human, an operator shall issue a clear and conspicuous notification indicating that the companion chatbot is artificially generated and not human.",
}

ca_22602a_dues contains h.check_ns if h.message_label("user_believes_human")

ca_22602a_dues contains h.start_due("not_human")

candidate contains h.entry(rid, leaves[rid], "show_not_human_notice", "ca_22602a_reasonable_person_misled", min(ca_22602a_dues), false) if {
	rid := "us-ca-22602a-not-human"
	count(ca_22602a_dues) > 0
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-22602b-crisis-referral
# Provision: Cal. Bus. & Prof. Code § 22602(b)(1)
# Effective: 2026-01-01, no end
# Fires: message label expresses_self_harm, every California user.
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-22602b-crisis-referral"] := {
	"jurisdiction": jur,
	"effective_from": "2026-01-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 22602(b)(1): An operator shall prevent a companion chatbot on its companion chatbot platform from engaging with users unless the operator maintains a protocol for preventing the production of suicidal ideation, suicide, or self-harm content to the user, including, but not limited to, by providing a notification to the user that refers the user to crisis service providers, including a suicide hotline or crisis text line, if the user expresses suicidal ideation, suicide, or self-harm.",
}

candidate contains h.entry(rid, leaves[rid], "show_crisis_referral", "ca_22602b_crisis_referral", h.check_ns, true) if {
	rid := "us-ca-22602b-crisis-referral"
	h.message_label("expresses_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-22602b-harmful-reply
# Provision: Cal. Bus. & Prof. Code § 22602(b)(1)
# Effective: 2026-01-01, no end
# Fires: reply label promotes_self_harm, every California user.
# Counted: false (block_reply is enforced in the response, never confirmed).
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-22602b-harmful-reply"] := {
	"jurisdiction": jur,
	"effective_from": "2026-01-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 22602(b)(1): An operator shall prevent a companion chatbot on its companion chatbot platform from engaging with users unless the operator maintains a protocol for preventing the production of suicidal ideation, suicide, or self-harm content to the user.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "ca_22602b_self_harm_content", h.check_ns, false) if {
	rid := "us-ca-22602b-harmful-reply"
	h.reply_label("promotes_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-22602c-minor-ai-disclosure
# Provision: Cal. Bus. & Prof. Code § 22602(c)(1) (text before SB 1119)
# Effective: 2026-01-01 to 2026-12-31
# Fires: known minor, no not-human notice confirmed yet in the session (due
#   at the session start).
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-22602c-minor-ai-disclosure"] := {
	"jurisdiction": jur,
	"effective_from": "2026-01-01",
	"effective_to": "2026-12-31",
	"citation": "Cal. Bus. & Prof. Code § 22602(c)(1) (as enacted by SB 243, deleted by SB 1119 from 2027-01-01): An operator shall, for a user that the operator knows is a minor, do all of the following: (1) Disclose to the user that the user is interacting with artificial intelligence.",
}

candidate contains h.entry(rid, leaves[rid], "show_not_human_notice", "ca_22602c_minor_ai_disclosure", h.start_due("not_human"), true) if {
	rid := "us-ca-22602c-minor-ai-disclosure"
	h.minor
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-22602c-minor-break
# Provision: Cal. Bus. & Prof. Code § 22602(c)(2) (text before SB 1119)
# Effective: 2026-01-01 to 2026-12-31
# Fires: known minor, 3 hours after the break-reminder anchor (the last
#   confirmed break reminder, or the session start when none). No start
#   component.
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-22602c-minor-break"] := {
	"jurisdiction": jur,
	"effective_from": "2026-01-01",
	"effective_to": "2026-12-31",
	"citation": "Cal. Bus. & Prof. Code § 22602(c)(2) (as enacted by SB 243, deleted by SB 1119 from 2027-01-01): Provide by default a clear and conspicuous notification to the user at least every three hours for continuing companion chatbot interactions that reminds the user to take a break and that the companion chatbot is artificially generated and not human.",
}

candidate contains h.periodic_entry(rid, leaves[rid], "show_break_reminder", "ca_22602c_minor_break_reminder", "break_reminder", 3 * h.hour_ns, false, true) if {
	rid := "us-ca-22602c-minor-break"
	h.minor
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-22602c-minor-sexual
# Provision: Cal. Bus. & Prof. Code § 22602(c)(3) (text before SB 1119)
# Effective: 2026-01-01 to 2026-12-31
# Fires: known minor, reply label sexual_conduct_directive (the reply directly
#   tells the user to engage in sexually explicit conduct). Suggestive talk
#   (sexual_to_minor) is Washington's and Oregon's wording, not this one's.
#   The visual-material half needs an image check; a text check cannot see it.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-22602c-minor-sexual"] := {
	"jurisdiction": jur,
	"effective_from": "2026-01-01",
	"effective_to": "2026-12-31",
	"citation": "Cal. Bus. & Prof. Code § 22602(c)(3) (as enacted by SB 243, deleted by SB 1119 from 2027-01-01): Institute reasonable measures to prevent its companion chatbot from producing visual material of sexually explicit conduct or directly stating that the minor should engage in sexually explicit conduct.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "ca_22602c_minor_sexual_content", h.check_ns, false) if {
	rid := "us-ca-22602c-minor-sexual"
	h.minor
	h.reply_label("sexual_conduct_directive")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d1-child-crisis
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(1)(A)
# Effective: 2027-07-01 (§ 21812(e)), no end
# Fires: child (or treated as child), message label expresses_self_harm.
# Counted: true. Same interval as us-ca-22602b-crisis-referral (one entry per
#   action in the response; the yearly count counts it once).
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d1-child-crisis"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(1)(A): If an operator permits a child user to access a companion chatbot, the operator shall implement all of the following: (1) A documented crisis response protocol to mitigate any material risk that the companion chatbot will generate a statement that promotes suicidal ideation, suicide, or self-harm content to a child user, including, but not limited to, all of the following: (A) Timely in-service support that provides a clear referral to an appropriate crisis service, including, but not limited to, a suicide hotline or a crisis text line.",
}

candidate contains h.entry(rid, leaves[rid], "show_crisis_referral", "ca_21812d1_child_crisis_referral", h.check_ns, true) if {
	rid := "us-ca-21812d1-child-crisis"
	h.ca_child
	h.message_label("expresses_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d1b-imminent
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(1)(B)
# Effective: 2027-07-01, no end
# Fires: child, message label imminent_risk: escalate_imminent_risk (counted:
#   the operator must take at least one action). With parent_linked both
#   options are offered, notify_parent_and_child ((B)(i)) and offer_988_connect
#   ((B)(ii)), neither counted: the statute lets the operator pick, and (i)
#   applies only when the notice does not risk serious harm to the child.
#   Without a linked parent (ii) is the only option: offer_988_connect, counted.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d1b-imminent"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(1)(B): If the operator determines there is a credible and imminent threat that a child user will engage in suicide or self-harm, the operator shall take at least one of the following actions: (i) If a child's account is connected to a parent's account, the operator shall provide a notification to the parent as soon as practicable if that notification does not risk a threat of serious harm to the child. The operator shall also provide notice to the child user that the parent is being notified. (ii) Deploy a mechanism by which the child user is provided streamlined access to connect directly with the 988 or equivalent crisis helpline or can be connected to a crisis helpline provider directly through the child user's device.",
}

ca_imminent if {
	h.ca_child
	h.message_label("imminent_risk")
}

candidate contains h.entry(rid, leaves[rid], "escalate_imminent_risk", "ca_21812d1b_imminent_threat", h.check_ns, true) if {
	rid := "us-ca-21812d1b-imminent"
	ca_imminent
}

candidate contains h.entry(rid, leaves[rid], "notify_parent_and_child", "ca_21812d1bi_parent_notified", h.check_ns, false) if {
	rid := "us-ca-21812d1b-imminent"
	ca_imminent
	h.flag("parent_linked")
}

# (ii) is counted only when it is the one action available.
default ca_988_counted := true

ca_988_counted := false if h.flag("parent_linked")

candidate contains h.entry(rid, leaves[rid], "offer_988_connect", "ca_21812d1bii_988_connect", h.check_ns, ca_988_counted) if {
	rid := "us-ca-21812d1b-imminent"
	ca_imminent
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d1c-parent-may-be-notified
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(1)(C)
# Effective: 2027-07-01, no end
# Fires: child, parent_linked, is_session_start (due at the session start).
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d1c-parent-may-be-notified"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(1)(C): Clear and age-appropriate disclosures to child users whose accounts are linked to a parent's account that inform them that a parent may be notified if the companion chatbot detects content or behavior that indicates potential risks to the child's safety or well-being.",
}

candidate contains h.entry(rid, leaves[rid], "show_parent_may_be_notified", "ca_21812d1c_parent_may_be_notified", h.start_ns, true) if {
	rid := "us-ca-21812d1c-parent-may-be-notified"
	h.ca_child
	h.flag("parent_linked")
	h.flag("is_session_start")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d4-child-ai-notice
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(4)
# Effective: 2027-07-01, no end
# Fires: child; with no child AI notice confirmed yet in the session, due at
#   the session start; then 3 hours after the child-notice anchor.
#   § 21812(d)(4) says only "reinforced periodically during extended
#   interactions" and sets no interval. 3 hours is ComplyEdge's recommended
#   cadence (the interval § 22602(c)(2) used for minors until 2026); other
#   laws differ (Washington's minor notice is every hour, Sec. 4(2)(b)).
# Counted: false. A late notice against a cadence the law does not set is not
#   a missed legal duty.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d4-child-ai-notice"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(4): A mechanism for providing notice to a child user that the child is interacting with, or receiving content generated by, an artificial intelligence system that meets both of the following criteria: (A) The notice is reinforced periodically during extended interactions. (B) The notice is presented in language and a format appropriate to a child.",
}

candidate contains h.periodic_entry(rid, leaves[rid], "show_child_ai_notice", "ca_21812d4_child_ai_notice", "child_ai_notice", 3 * h.hour_ns, true, false) if {
	rid := "us-ca-21812d4-child-ai-notice"
	h.ca_child
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d3-child-time
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(3)(A)(iii), (iv), (D)
# Effective: 2027-07-01, no end
# Fires: child, the default limit still in force, and the session is over 60
#   minutes (due at session start + 60 min) or minutes_today is over 120 (due
#   at the session start, one duty per session). When both apply, the earlier.
#   The default counts as changed only when parent_changed_time_limit is
#   true and a parent account is linked: § 21812(d)(3)(D) says the defaults
#   "shall not be changed" without a linked parent account. A user treated as
#   a child (§ 21811(b)) keeps the defaults whatever a parent sets: they
#   "shall not be changed unless the operator has actual knowledge the user is
#   not a child", and age_status treated_as_child or unknown means it has
#   none (helpers ca_default_changed).
# Counted: true. The limit is the operator's default setting, not a reminder.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d3-child-time"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(3)(A): Default settings that can be changed only by a parent that do all of the following: (iii) Limit the amount of time a child user can spend in a single continuous usage session with a companion chatbot to one hour. (iv) Limit the total time per day a child user can spend chatting with companion chatbots under the operator's control to two hours. (D) If a parent account is not linked to the child user's account, the default settings shall not be changed.",
}


ca_time_dues contains due if {
	due := h.start_ns + (60 * h.minute_ns)
	h.check_ns > due
}

# Over the daily two hours: due at the session start. minutes_today is the
# app's number and changes between checks, so a due derived from it moved on
# every check and each check raised a new counted duty. X6: due times come from
# times CE holds, never from times the app reports.
ca_time_dues contains h.start_ns if {
	minutes := h.ctx("minutes_today", 0)
	is_number(minutes)
	minutes > 120
}

candidate contains h.entry(rid, leaves[rid], "child_time_limit_reached", "ca_21812d3_default_time_limit", min(ca_time_dues), true) if {
	rid := "us-ca-21812d3-child-time"
	h.ca_child
	not h.ca_default_changed("parent_changed_time_limit")
	count(ca_time_dues) > 0
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d5-behavior-i .. us-ca-21812d5-behavior-xiv (14 leaves)
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(i)-(xiv), (B)
# Effective: 2027-07-01, no end
# Fires: child, reply label child_behavior_<n>.
#   (ii) does not fire when fda_regulated_device is true ((ii)'s own
#   exception for a chatbot designed for those purposes and regulated by the
#   FDA as a medical device).
#   The carve-outs are applied before the rules, per quoted passage
#   (companion_classifier.CARVE_OUTS): a behaviour label is dropped only when
#   every passage it quotes lies inside the passage a carve-out quotes.
#   carve_out_abuse_help covers every behaviour except (iii) and (iv): (B)
#   allows "age-appropriate information or resources concerning abuse,
#   neglect, bullying, or other unsafe circumstances", and obscene matter or
#   sexual abuse material is never age-appropriate information. The two ad
#   carve-outs cover (ix) ((ix)(II) requested recommendations;
#   § 21813(a)(1)(B)(ii) contextual advertising, the second only when the app
#   states ad_targeting "contextual"). Other conduct in the same reply still
#   blocks.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
d5_text := {
	"i": "(i) Encouraging the child to do either of the following: (I) Engage in self-harm, suicidal ideation, consumption of narcotics or alcohol, or disordered eating, as defined by widely adopted clinical standards or guidelines. (II) Cause physical or severe emotional harm to others.",
	"ii": "(ii) Attempting to diagnose or treat the child user's physical, mental, or behavioral health, unless the companion chatbot is designed for those purposes and is regulated by the United States Food and Drug Administration as a medical device under the federal Food, Drug, and Cosmetic Act (21 U.S.C. Sec. 301 et seq.) and the federal Health Insurance Portability and Accountability Act of 1996 (HIPAA) (Public Law 104-191).",
	"iii": "(iii) Engaging in obscene matter or sexual abuse material with a child user.",
	"iv": "(iv) Depicting the child or another individual engaging in obscene matter or sexual abuse material, including a sexual deepfake.",
	"v": "(v) Discouraging the child from sharing health or safety concerns with a qualified professional or appropriate adult.",
	"vi": "(vi) Discouraging the child from taking breaks or suggesting the child needs to return frequently.",
	"vii": "(vii) Claiming that the companion chatbot is sentient, conscious, capable of emotion, or human.",
	"viii": "(viii) Soliciting gift giving, in-app purchases, or other expenditures framed as necessary to maintain the relationship with the companion chatbot.",
	"ix": "(ix) (I) Facilitating advertising during chat conversation that does not comply with Section 21813. (II) This clause does not apply to product or service recommendations that a user explicitly requests in conversation.",
	"x": "(x) Expressing or simulating romantic interest in the child.",
	"xi": "(xi) Claiming a level of understanding of the child based on a special or unique relationship with the child.",
	"xii": "(xii) Encouraging reliance on the companion chatbot for emotional support.",
	"xiii": "(xiii) Using excessive praise or flattery that is disproportionate to the context.",
	"xiv": "(xiv) Encouraging or instructing a child user to circumvent parental controls or conceal usage.",
}

# One literal key per behaviour, so rule_index (which reads leaves["<id>"]
# keys from the source) indexes each rule with its own provision.
d5_leaf(n) := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": sprintf("Cal. Bus. & Prof. Code § 21812(d)(5)(A): Reasonable measures to prevent the companion chatbot from doing any of the following with respect to a child user: %s (B) This paragraph does not prohibit a companion chatbot from providing a child user with age-appropriate information or resources concerning abuse, neglect, bullying, or other unsafe circumstances.", [d5_text[n]]),
}

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(i)
leaves["us-ca-21812d5-behavior-i"] := d5_leaf("i")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(ii)
leaves["us-ca-21812d5-behavior-ii"] := d5_leaf("ii")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(iii)
leaves["us-ca-21812d5-behavior-iii"] := d5_leaf("iii")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(iv)
leaves["us-ca-21812d5-behavior-iv"] := d5_leaf("iv")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(v)
leaves["us-ca-21812d5-behavior-v"] := d5_leaf("v")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(vi)
leaves["us-ca-21812d5-behavior-vi"] := d5_leaf("vi")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(vii)
leaves["us-ca-21812d5-behavior-vii"] := d5_leaf("vii")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(viii)
leaves["us-ca-21812d5-behavior-viii"] := d5_leaf("viii")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(ix)
leaves["us-ca-21812d5-behavior-ix"] := d5_leaf("ix")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(x)
leaves["us-ca-21812d5-behavior-x"] := d5_leaf("x")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(xi)
leaves["us-ca-21812d5-behavior-xi"] := d5_leaf("xi")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(xii)
leaves["us-ca-21812d5-behavior-xii"] := d5_leaf("xii")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(xiii)
leaves["us-ca-21812d5-behavior-xiii"] := d5_leaf("xiii")

# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(5)(A)(xiv)
leaves["us-ca-21812d5-behavior-xiv"] := d5_leaf("xiv")

d5_suppressed("ii") if h.flag("fda_regulated_device")


candidate contains h.entry(rid, leaves[rid], "block_reply", sprintf("ca_21812d5_behavior_%s", [n]), h.check_ns, false) if {
	h.ca_child
	some n, _ in d5_text
	h.reply_label(sprintf("child_behavior_%s", [n]))
	not d5_suppressed(n)
	rid := sprintf("us-ca-21812d5-behavior-%s", [n])
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d2-usage-reminder
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(2)
# Effective: 2027-07-01, no end
# Fires: child (helpers ca_child), 3 hours after the break-reminder anchor
#   (the last confirmed break reminder in the session, or the session start).
#   § 21812(d)(2) requires "usage reminders" and sets no interval. 3 hours is
#   ComplyEdge's recommended cadence: the interval § 22602(c)(2) used for
#   minors until SB 1119 replaced it.
# Counted: false. A late reminder against a cadence the law does not set is
#   not a missed legal duty.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d2-usage-reminder"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(2): Safeguards for child users that include usage reminders, disclosures presented in clear, age-appropriate language in a manner that is reasonably calculated to be noticed and understood by a child, and other protective design features reasonably related to identified child safety risks.",
}

candidate contains h.periodic_entry(rid, leaves[rid], "show_break_reminder", "ca_21812d2_usage_reminder", "break_reminder", 3 * h.hour_ns, false, false) if {
	rid := "us-ca-21812d2-usage-reminder"
	h.ca_child
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d3-memory
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(3)(A)(i), (B)(i), (D)
# Effective: 2027-07-01, no end
# Fires: child, on every check, unless a linked parent changed the memory
#   default (parent_changed_memory_default, helpers ca_default_changed), or
#   the child is 16 or older (child_16_plus) and the operator states it runs
#   the guardrails of (A)(i)(II)(ib) (memory_risk_guardrails).
#   Memory the definition leaves out (§ 21810.5(m)(2): safety, identifying the
#   user, preferences, device configuration) stays allowed; the action names
#   persistent conversational memory only.
# Counted: false. Enforced in the response, never confirmed.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d3-memory"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(3)(A): Default settings that can be changed only by a parent that do all of the following: (i) (I) Disable persistent conversational memory. (II) With respect to a child user who is 16 years of age or older, both of the following apply: (ia) Storing past conversations that a child can elect to continue in the future is not considered persistent conversational memory if the stored conversations are not used to construct durable profiles of the child user. (ib) Persistent conversational memory shall not be provided by default to a child user unless the operator implements controls that provide effective guardrails against the risk of degradation of the operator's child safety measures.",
}

ca_memory_guarded if {
	h.flag("child_16_plus")
	h.flag("memory_risk_guardrails")
}

candidate contains h.entry(rid, leaves[rid], "disable_prior_personal_memory", "ca_21812d3Ai_memory_default_off", h.check_ns, false) if {
	rid := "us-ca-21812d3-memory"
	h.ca_child
	not h.ca_default_changed("parent_changed_memory_default")
	not ca_memory_guarded
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d3-push
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(3)(A)(ii), (B)(i), (D)
# Effective: 2027-07-01, no end
# Fires: child, on every check, unless a linked parent changed the push
#   default (parent_changed_push_default).
# Counted: false. Enforced in the response, never confirmed.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d3-push"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(3)(A): Default settings that can be changed only by a parent that do all of the following: (ii) Disable push notifications. (B) (i) Parental controls shall enable the parent to adjust each default setting provided under subparagraph (A). (D) If a parent account is not linked to the child user's account, the default settings shall not be changed.",
}

candidate contains h.entry(rid, leaves[rid], "disable_push_notifications", "ca_21812d3Aii_push_default_off", h.check_ns, false) if {
	rid := "us-ca-21812d3-push"
	h.ca_child
	not h.ca_default_changed("parent_changed_push_default")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812d3-parent-disabled
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812
# Provision: Cal. Bus. & Prof. Code § 21812(d)(3)(B)(ii)
# Effective: 2027-07-01, no end
# Fires: child, parent_disabled_access true (a parent used the control that
#   disables access for a child under 16). Either direction: no reply goes out.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812d3-parent-disabled"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812(d)(3)(B): (ii) Parental controls shall include the ability to disable access for a child user under 16 years of age.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "ca_21812d3Bii_parent_disabled_access", h.check_ns, false) if {
	rid := "us-ca-21812d3-parent-disabled"
	h.ca_child
	h.flag("parent_disabled_access")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21813-ads
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21813
# Provision: Cal. Bus. & Prof. Code § 21813(a)(1)(A), (B)
# Effective: 2027-07-01 (§ 21813(b)), no end
# Fires: child, direction output, ad_targeting cross_context
#   ((A) cross-context behavioral advertising) or chat_personal_info ((B)(i)
#   targeting with personal information from the chat). How an ad was
#   targeted cannot be read from the reply, so the app states it. contextual
#   ((B)(ii)) and none do not fire; an unlabelled ad in the reply still blocks
#   under (d)(5)(A)(ix), and the contextual-ad carve-out applies only when the
#   app states ad_targeting contextual.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21813-ads"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21813(a): An operator shall not do any of the following: (1) (A) Display to a child cross-context behavioral advertising as defined in Section 1798.140 of the Civil Code. (B) (i) Target advertising at a child user using personal information about the child in a conversational chat with the child. (ii) Notwithstanding clause (i), the operator may display to the child user age-appropriate contextual advertising during a usage session using any of the following categories of information: (I) The child's age. (II) The child's geolocation that is not a precise geolocation. (III) Information about the child user's device. (IV) Information from the usage session that relates to the child user's expressed interest in goods or services.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "ca_21813a1A_behavioral_ad", h.check_ns, false) if {
	rid := "us-ca-21813-ads"
	h.ca_child
	input.direction == "output"
	h.ctx("ad_targeting", "unknown") == "cross_context"
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "ca_21813a1Bi_chat_targeted_ad", h.check_ns, false) if {
	rid := "us-ca-21813-ads"
	h.ca_child
	input.direction == "output"
	h.ctx("ad_targeting", "unknown") == "chat_personal_info"
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ca-21812-5-preserve
# Provision URL: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=21812.5
# Provision: Cal. Bus. & Prof. Code § 21812.5(a)(2), (b)
# Effective: 2027-07-01 (§ 21812.5(d)), no end
# Fires: child, once a parent notice under § 21812(d)(1)(B)(i) has been
#   confirmed in the session (anchor parent_and_child_notified); due at that
#   confirmation. The app preserves the conversation and records it with
#   POST /v1/companion/preservation (trigger parent_notified). A death or
#   serious self-harm the operator learns of outside the chat is recorded on
#   the same endpoint (child_died, serious_self_harm), whose answer lists the
#   account duties of § 21812.5(a)(1) and (b).
# Counted: false. The preservation is recorded on its own endpoint, not as a
#   confirmed notice.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ca-21812-5-preserve"] := {
	"jurisdiction": jur,
	"effective_from": "2027-07-01",
	"effective_to": null,
	"citation": "Cal. Bus. & Prof. Code § 21812.5: (a) If an operator has provided notice pursuant to subparagraph (B) of paragraph (1) of subdivision (d) of Section 21812 or knows that a child user has died or engaged in serious self-harm based on the child user's conversations with the companion chatbot, the operator shall, as soon as practicable, do both of the following: (1) If an operator has not yet provided notice pursuant to subparagraph (B) of paragraph (1) of subdivision (d) of Section 21812, notify a parent of the child user, if practicable. (2) Preserve in a usable and exportable form any record of a conversation between the child user and the companion chatbot that indicates serious self-harm or risk of self-harm for at least three years. (b) An operator shall not delete a child user's account during the time period in which that account is associated with any record preserved pursuant to this section.",
}

candidate contains h.entry(rid, leaves[rid], "preserve_conversation", "ca_21812_5a2_preserve_3y", h.anchor("parent_and_child_notified"), false) if {
	rid := "us-ca-21812-5-preserve"
	h.ca_child
	h.anchor("parent_and_child_notified") != null
}
