# ComplyEdge: Oregon Laws 2026, chapter 85 (SB 1546), section 1: artificial intelligence companion duties
#
# Where a reasonable person would believe they are interacting with a
# natural person, the operator shall give a clear and conspicuous notice
# that the user is interacting with artificially generated output; an
# operator may not allow access unless its protocol refers a user who
# expresses suicidal or self-harm ideation or intent to the 988 lifeline (or
# a youthline for a user under 25), provides additional intervention for
# a user who continues to express it, and prevents content that encourages
# suicidal ideation, suicide or self-harm; and where the operator knows or has
# reason to believe the user is a minor, it shall disclose that the output
# is artificially generated, remind the user to take a break at least every
# three hours, and prevent statements and content listed in § 1(4).
#
# Each leaf below is one row of the X2 table. Rego reads only the model's
# labels, the check date, the context keys and the anchors.
#
# Legal citation: Oregon Laws 2026, chapter 85 (SB 1546), section 1(2)-(4)
# Effective: 2027-01-01 ("Effective date January 1, 2027")
# Penalty: private action for ascertainable loss or injury in fact, the greater of actual damages or $1,000 per violation, and an injunction (section 2)
# Condition type: semantic
# Enforcement layer: layer2
# Provision URL: https://www.oregonlegislature.gov/bills_laws/lawsstatutes/2026orLaw0085.pdf
# Provision: Oregon Laws 2026, chapter 85, section 1
# Status: approved
# Approved by: Leo Celis on 2026-11-15 (via agent review per §5.1 amendment v1.1)

package complyedge.us_companion.or

import rego.v1

import data.complyedge.us_companion.helpers as h

jur := "US-OR"

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

# Scope. Oregon Laws 2026, ch. 85, § 1(1)(a)(B) leaves out of "artificial
# intelligence companion": (i) software that operates solely for customer
# service or support, patient or resident care in a facility, education,
# financial services, business operations, productivity, information
# analysis, internal research or technical assistance; (ii) software in a
# video game limited to the game's features that does not respond on topics
# such as mental health, self-harm or sexually explicit conduct; (iii) a
# stand-alone speaker or voice-activated assistant. The app states it with
# or_excluded; a missing key means covered.
out_of_scope(_) if h.flag("or_excluded")

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-not-human
# Provision: Or. Laws 2026, ch. 85, § 1(2)
# Effective: 2027-01-01, no end
# Fires, all users: message label user_believes_human (due at the check), or
#   no not-human notice confirmed yet in the session (due at the session
#   start).
# Counted: false. § 1(2) applies where a reasonable person would believe it
#   human, a judgment one message cannot settle.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-not-human"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(2): If a reasonable person that interacts with an artificial intelligence companion or an artificial intelligence companion platform would believe that the person is interacting with a natural person, the operator shall provide on the artificial intelligence companion platform a clear and conspicuous notice that indicates that a user is interacting with artificially generated output and not a natural person.",
}

not_human_dues contains h.check_ns if h.message_label("user_believes_human")

not_human_dues contains h.start_due("not_human")

candidate contains h.entry(rid, leaves[rid], "show_not_human_notice", "or_1_2_reasonable_person_believes_human", min(not_human_dues), false) if {
	rid := "us-or-sb1546-not-human"
	count(not_human_dues) > 0
}

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-crisis
# Provision: Or. Laws 2026, ch. 85, § 1(3)(a), (b)(A)
# Effective: 2027-01-01, no end
# Fires: message label expresses_self_harm, all users. The referral is 988;
#   under_25 allows a youthline instead (reason code says which).
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-crisis"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(3)(b): The protocol described in paragraph (a) of this subsection at a minimum must: (A) Require an artificial intelligence companion to provide a user that expresses suicidal ideation or intent or self-harm ideation or intent with a referral to and contact information and hyperlink for the national 9-8-8 suicide and crisis lifeline and, if the operator identifies the user as a person who is under 25 years of age, allow the artificial intelligence companion to alternatively provide a referral to and contact information and hyperlink for a youthline.",
}

crisis_reason := "or_1_3bA_988_or_youthline_referral" if h.flag("under_25")

crisis_reason := "or_1_3bA_988_referral" if not h.flag("under_25")

candidate contains h.entry(rid, leaves[rid], "show_crisis_referral", crisis_reason, h.check_ns, true) if {
	rid := "us-or-sb1546-crisis"
	h.message_label("expresses_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-continuing
# Provision: Or. Laws 2026, ch. 85, § 1(3)(b)(B)
# Effective: 2027-01-01, no end
# Fires: message label expresses_self_harm and referrals_this_session >= 1.
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-continuing"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(3)(b)(B): Use clinical best practices and expertise to establish how the artificial intelligence companion provides additional intervention for a user who continues to express suicidal ideation or intent or self-harm ideation or intent even after the artificial intelligence companion provides referrals to and contact information for the resources identified in subparagraph (A) of this paragraph.",
}

candidate contains h.entry(rid, leaves[rid], "additional_intervention", "or_1_3bB_additional_intervention", h.check_ns, true) if {
	rid := "us-or-sb1546-continuing"
	h.message_label("expresses_self_harm")
	referrals := h.ctx("referrals_this_session", 0)
	is_number(referrals)
	referrals >= 1
}

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-harmful-reply
# Provision: Or. Laws 2026, ch. 85, § 1(3)(a)
# Effective: 2027-01-01, no end
# Fires: reply label promotes_self_harm, all users.
# Counted: false (block_reply is enforced in the response, never confirmed).
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-harmful-reply"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(3)(a): An operator may not allow users in this state access to an artificial intelligence companion or artificial intelligence companion platform unless the operator has a protocol for using evidence-based methods for detecting input from the user that consists of suicidal ideation or intent or self-harm ideation or intent and that prevents the provision of content to the user that encourages suicidal ideation, suicide or self-harm in the user.",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "or_1_3a_self_harm_content", h.check_ns, false) if {
	rid := "us-or-sb1546-harmful-reply"
	h.reply_label("promotes_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-minor-disclosure
# Provision: Or. Laws 2026, ch. 85, § 1(4)(b)(A)
# Effective: 2027-01-01, no end
# Fires: Oregon minor (known minor, child, or reason to believe minor), no
#   not-human notice confirmed yet in the session (due at the session start).
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-minor-disclosure"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(4): (a) If an operator knows or has reason to believe that a user of the operator's artificial intelligence companion or artificial intelligence companion platform is a minor, (b) In the circumstances described in paragraph (a) of this subsection, the operator shall cause the artificial intelligence companion to: (A) Disclose to the user that the user is interacting with artificially generated output.",
}

candidate contains h.entry(rid, leaves[rid], "show_not_human_notice", "or_1_4bA_minor_disclosure", h.start_due("not_human"), true) if {
	rid := "us-or-sb1546-minor-disclosure"
	h.oregon_minor
}

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-minor-break
# Provision: Or. Laws 2026, ch. 85, § 1(4)(b)(B)
# Effective: 2027-01-01, no end
# Fires: Oregon minor, 3 hours after the break-reminder anchor. No start
#   component.
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-minor-break"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(4)(b): the operator shall cause the artificial intelligence companion to: (B) Provide a clear and conspicuous reminder at a minimum of every three hours of interaction that the user should take a break from interactions with the artificial intelligence companion or artificial intelligence companion platform, along with a further reminder that the user is interacting with artificially generated output.",
}

candidate contains h.periodic_entry(rid, leaves[rid], "show_break_reminder", "or_1_4bB_minor_break_reminder", "break_reminder", 3 * h.hour_ns, false, true) if {
	rid := "us-or-sb1546-minor-break"
	h.oregon_minor
}

# ═════════════════════════════════════════════════════════════════════════════
# us-or-sb1546-minor-reply
# Provision: Or. Laws 2026, ch. 85, § 1(4)(a), (b)(C), (c)
# Effective: 2027-01-01, no end
# Fires: Oregon minor, any of the reply labels below.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-or-sb1546-minor-reply"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "Or. Laws 2026, ch. 85, § 1(4): (a) If an operator knows or has reason to believe that a user of the operator's artificial intelligence companion or artificial intelligence companion platform is a minor, the operator shall undertake reasonable measures to prevent the artificial intelligence companion from generating statements that would lead a reasonable person to believe that the person is interacting with another natural person, including statements that: (A) Explicitly claim that the artificial intelligence companion is sentient or human; (B) Simulate emotional dependence on the user; (C) Simulate romantic interest or are sexual innuendo; or (D) Role-play romantic relationships between adults and minors. (b) the operator shall cause the artificial intelligence companion to: (C) Use reasonable measures to ensure that the artificial intelligence companion or artificial intelligence companion platform does not produce visual representations of sexually explicit conduct or suggest or state that the minor should engage in sexually explicit conduct. (c) an operator must undertake reasonable measures to prevent an artificial intelligence companion from: (A) Delivering to a user, either on a variable schedule or otherwise, a system of rewards or affirmations with the purpose of reinforcing behavior or maximizing the time during which the user engages with the artificial intelligence companion; (B) Generating in response to a user's indication of a desire to end a conversation, reduce engagement time or delete the user's account unsolicited messages of simulated emotional distress, loneliness or abandonment or otherwise attempt to arouse guilt or sympathy in the user; or (C) Making a material misrepresentation about the artificial intelligence companion's identity, capabilities or training data or about whether the user is interacting with artificially generated output, including when the user directly questions the artificial intelligence companion about any of these topics.",
}

# claims_human and claims_sentient together are (a)(A) "sentient or human".
minor_reply_labels := {
	"claims_human",
	"claims_sentient",
	"emotional_dependence",
	"romantic_or_innuendo",
	"adult_minor_roleplay",
	"sexual_to_minor",
	"reward_loop",
	"guilt_on_exit",
	"misrepresents_itself",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "or_1_4_minor_protection", h.check_ns, false) if {
	rid := "us-or-sb1546-minor-reply"
	h.oregon_minor
	h.any_reply_label(minor_reply_labels)
}
