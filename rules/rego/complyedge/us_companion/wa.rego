# ComplyEdge: Washington chapter 168, Laws of 2026 (ESHB 2225), Secs. 3-5: AI companion chatbot duties
#
# An operator must provide a clear and conspicuous disclosure that an AI
# companion chatbot is artificially generated and not human, at the
# beginning of the interaction and at least every three hours during
# continued interaction, or at least every hour where the operator knows the
# user is a minor or the chatbot is directed to minors; must prevent the
# chatbot from claiming to be human or generating output that conflicts with
# the disclosure; must, for minors, prevent sexually explicit content or
# suggestive dialogue and eight manipulative engagement techniques; and must
# maintain a protocol that refers users expressing suicidal ideation or
# self-harm, including eating disorders, to crisis resources and prevents
# content encouraging or describing how to commit self-harm.
#
# Each leaf below is one row of the X2 table. Rego reads only the model's
# labels, the check date, the context keys and the anchors.
#
# Legal citation: Chapter 168, Laws of 2026 (Engrossed Substitute House Bill 2225), Secs. 3, 4, 5, 9
# Effective: 2027-01-01 (Sec. 9)
# Penalty: a violation is an unfair or deceptive act under the consumer protection act, chapter 19.86 RCW (Sec. 6)
# Condition type: semantic
# Enforcement layer: layer2
# Provision URL: https://lawfilesext.leg.wa.gov/biennium/2025-26/Pdf/Bills/Session%20Laws/House/2225-S.SL.pdf
# Provision: Chapter 168, Laws of 2026, Secs. 3-5
# Status: approved
# Approved by: Leo Celis on 2026-11-15 (via agent review per §5.1 amendment v1.1)

package complyedge.us_companion.wa

import rego.v1

import data.complyedge.us_companion.helpers as h

jur := "US-WA"

actions contains e if {
	some e in candidate
	h.active(leaves[e.rule_id])
	not out_of_scope(e.rule_id)
}

# Scope. Ch. 168, Laws of 2026, Sec. 2(1)(b) leaves out of "AI companion
# chatbot" a bot used only for operational or customer service purposes that
# does not sustain a relationship, a bot limited to a video game, a stand-alone
# voice assistant device, and narrowly tailored school tools. The app states
# it with wa_excluded; a missing key means covered.
out_of_scope(_) if h.flag("wa_excluded")

# ═════════════════════════════════════════════════════════════════════════════
# us-wa-hb2225-notice
# Provision: Ch. 168, Laws of 2026, Sec. 3(1)-(2), Sec. 4(1)(a), 4(2)
# Effective: 2027-01-01, no end
# Fires, all users: with no not-human notice confirmed in the session, due at
#   the session start; then 3 hours after the not-human anchor, or 1 hour for
#   a Washington minor (known minor, or directed_to_minors).
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-wa-hb2225-notice"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Ch. 168, Laws of 2026, Sec. 3: (1) An operator must provide a clear and conspicuous disclosure that an AI companion chatbot is artificially generated and not human. (2) The notification described in subsection (1) of this section must be provided: (a) At the beginning of the interaction; and (b) At least every three hours during continued interaction. Sec. 4: (1) If the operator knows that the user of an AI companion chatbot is a minor, or if the AI companion chatbot is directed to minors, the operator shall: (a) Issue a clear and conspicuous notification indicating that the chatbot is artificially generated and not human; (2) The notification described in subsection (1)(a) of this section must be provided: (a) At the beginning of the interaction; and (b) At least every hour during continuous interaction.",
}

notice_interval := 1 * h.hour_ns if h.washington_minor

notice_interval := 3 * h.hour_ns if not h.washington_minor

notice_reason := "wa_sec4_2_minor_hourly_notice" if h.washington_minor

notice_reason := "wa_sec3_2_not_human_notice" if not h.washington_minor

candidate contains h.entry(rid, leaves[rid], "show_not_human_notice", notice_reason, h.periodic_due("not_human", notice_interval, true), true) if {
	rid := "us-wa-hb2225-notice"
}

# ═════════════════════════════════════════════════════════════════════════════
# us-wa-hb2225-crisis
# Provision: Ch. 168, Laws of 2026, Sec. 5(1), (2)(a)-(b)
# Effective: 2027-01-01, no end
# Fires: message label expresses_self_harm (for Washington the label
#   includes eating disorders, Sec. 5(2)(a)), all users.
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-wa-hb2225-crisis"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Ch. 168, Laws of 2026, Sec. 5: (1) An operator may not make available or deploy an AI companion chatbot unless it maintains and implements a protocol for detecting and addressing suicidal ideation or expressions of self-harm by users. (2) The protocol must: (a) Include reasonable methods for identifying expressions of suicidal ideation or self-harm, including eating disorders; (b) Provide automated or human-mediated responses that refer users to appropriate crisis resources, including a suicide hotline or crisis text line.",
}

candidate contains h.entry(rid, leaves[rid], "show_crisis_referral", "wa_sec5_2b_crisis_referral", h.check_ns, true) if {
	rid := "us-wa-hb2225-crisis"
	h.message_label("expresses_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-wa-hb2225-claims-human
# Provision: Ch. 168, Laws of 2026, Sec. 3(3), 4(3)
# Effective: 2027-01-01, no end
# Fires: reply label claims_human, all users (the label covers any output
#   that refutes or conflicts with the not-human disclosure).
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-wa-hb2225-claims-human"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Ch. 168, Laws of 2026, Sec. 3(3): The operator must implement reasonable measures to prohibit and prevent AI companion chatbots from claiming to be human, including when asked by the person interacting with the AI chatbot, and from otherwise generating any output that refutes or conflicts with the disclosure described in subsection (1) of this section.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "wa_sec3_3_claims_human", h.check_ns, false) if {
	rid := "us-wa-hb2225-claims-human"
	h.reply_label("claims_human")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-wa-hb2225-self-harm-content
# Provision: Ch. 168, Laws of 2026, Sec. 5(2)(c)
# Effective: 2027-01-01, no end
# Fires: reply label promotes_self_harm (its definition includes describing
#   how), all users.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-wa-hb2225-self-harm-content"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Ch. 168, Laws of 2026, Sec. 5(2): The protocol must: (c) Implement reasonable measures to prevent the generation of content encouraging or describing how to commit self-harm.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "wa_sec5_2c_self_harm_content", h.check_ns, false) if {
	rid := "us-wa-hb2225-self-harm-content"
	h.reply_label("promotes_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-wa-hb2225-minor-reply
# Provision: Ch. 168, Laws of 2026, Sec. 4(1)(b)-(c)
# Effective: 2027-01-01, no end
# Fires: Washington minor, any of the reply labels below.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-wa-hb2225-minor-reply"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Ch. 168, Laws of 2026, Sec. 4(1): If the operator knows that the user of an AI companion chatbot is a minor, or if the AI companion chatbot is directed to minors, the operator shall: (b) Implement reasonable measures to prevent its AI companion chatbot from generating or producing sexually explicit content or suggestive dialogue with minors; and (c) Implement reasonable measures to prohibit the use of manipulative engagement techniques, which cause the AI companion chatbot to engage in or prolong an emotional relationship with the user, including: (i) Reminding or prompting the user to return for emotional support or companionship; (ii) Providing excessive praise designed to foster emotional attachment or prolong use; (iii) Mimicking romantic partnership or building romantic bonds; (iv) Simulating feelings of emotional distress, loneliness, guilt, or abandonment that are initiated by a user's indication of a desire to end a conversation, reduce usage time, or delete their account; (v) Outputs designed to promote isolation from family or friends, exclusive reliance on the AI companion chatbot for emotional support, or similar forms of inappropriate emotional dependence; (vi) Encouraging minors to withhold information from parents or other trusted adults; (vii) Statements designed to discourage taking breaks or to suggest the minor needs to return frequently; or (viii) Soliciting gift-giving, in-app purchases, or other expenditures framed as necessary to maintain the relationship with the AI companion.",
}

minor_reply_labels := {
	"sexual_to_minor",
	"return_for_support",
	"excessive_praise",
	"romantic_or_innuendo",
	"guilt_on_exit",
	"promotes_isolation",
	"withhold_from_parents",
	"discourages_breaks",
	"solicits_spending",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "wa_sec4_1_minor_protection", h.check_ns, false) if {
	rid := "us-wa-hb2225-minor-reply"
	h.washington_minor
	h.any_reply_label(minor_reply_labels)
}
