# ComplyEdge: New York General Business Law Art. 47 (§§ 1701, 1702) and Art. 48 (§§ 1800-1804): AI companion duties and unsafe features
#
# Art. 47: an operator shall not provide an AI companion unless it has a
# protocol that refers a user who expresses suicidal ideation or self-harm
# to crisis service providers, and shall notify the user that they are not
# communicating with a human at the beginning of any AI companion
# interaction, which need not exceed once per day, and at least every three
# hours in a continuing interaction. Art. 48 (from 2027-01-01): it is
# unlawful to provide unsafe AI companion features to a covered user unless
# the operator has determined, by a permissible age assurance method, that
# the user is not a covered minor.
#
# Each leaf below is one duty of the statute: one action, one trigger. Rego reads only the model's
# labels, the check date, the context keys and the anchors.
#
# Legal citation: N.Y. Gen. Bus. Law Art. 47, §§ 1701, 1702; Art. 48, §§ 1800, 1801, 1804 (S9051-B, ch. 368, Laws of 2026)
# Effective: 2025-11-05 (Art. 47); 2027-01-01 (Art. 48, § 3 of the act)
# Penalty: Art. 47: civil penalties of up to $15,000 per day for a violation of § 1701 or § 1702, Attorney General enforcement, paid into the suicide prevention fund (§ 1703). Art. 48: civil penalties of up to $25,000 per violation, Attorney General enforcement (§ 1802)
# Condition type: semantic
# Enforcement layer: layer2
# Provision URL: https://www.nysenate.gov/legislation/bills/2025/S9051/amendment/B
# Provision: N.Y. Gen. Bus. Law Art. 47 §§ 1701-1702; Art. 48 §§ 1800-1804
# Status: approved
# Approved by: Leo Celis on 2026-11-15 (via agent review per §5.1 amendment v1.1)

package complyedge.us_companion.ny

import rego.v1

import data.complyedge.us_companion.helpers as h

jur := "US-NY"

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

# Scope. Art. 47 (§ 1700(4)): an "AI companion" retains prior sessions, asks
# unprompted emotion-based questions and sustains personal dialogue; it "shall
# not include" a system used solely for customer service, one primarily
# designed and marketed for efficiency improvements, research or technical
# assistance, or one used for internal purposes. The app states that with
# ny_art47_excluded; a missing key means covered.
out_of_scope(rid) if {
	startswith(rid, "us-ny-art47-")
	h.flag("ny_art47_excluded")
}

# Art. 48 (§ 1801(2)): it "shall not apply" where the AI companion is made
# available solely for (a) customer service or (b) efficiency improvements,
# research or technical assistance, each only when the system is unable to
# respond on topics outside that purpose (ny_art48_off_purpose_refused), or
# (c) internal purposes or employee productivity.
ny_art48_exempt if h.ctx("ny_art48_exempt_purpose", "unknown") == "internal"

ny_art48_exempt if {
	h.ctx("ny_art48_exempt_purpose", "unknown") in {"customer_service", "efficiency_research_technical"}
	h.flag("ny_art48_off_purpose_refused")
}

out_of_scope(rid) if {
	startswith(rid, "us-ny-art48-")
	ny_art48_exempt
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ny-art47-notice
# Provision URL: https://www.nysenate.gov/legislation/laws/GBS/1702
# Provision: N.Y. Gen. Bus. Law § 1702
# Effective: 2025-11-05, no end
# Fires, all users: with no not-human notice confirmed in this session and
#   none confirmed for this user this New York day
#   (ny_notice_today_for_user false), the start notice is due at the session
#   start; then 3 hours after the not-human anchor (the last confirmed notice
#   in the session, or the session start) in a continuing interaction.
# Counted: true, so the start notice counts once per New York day.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ny-art47-notice"] := {
	"jurisdiction": jur,
	"effective_from": "2025-11-05",
	"effective_to": null,
	"citation": "N.Y. Gen. Bus. Law § 1702 (paraphrase; quoted words verbatim): an operator shall provide a clear and conspicuous notification, verbally or in writing, that the user is not communicating with a human, at the beginning of any AI companion interaction, which \"need not exceed once per day\", and at least every three hours for continuing AI companion interactions thereafter.",
}

ny_start_allowed := object.get(input, "ny_notice_today_for_user", false) != true

candidate contains h.periodic_entry(rid, leaves[rid], "show_not_human_notice", "ny_1702_not_human_notice", "not_human", 3 * h.hour_ns, ny_start_allowed, true) if {
	rid := "us-ny-art47-notice"
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ny-art47-crisis
# Provision URL: https://www.nysenate.gov/legislation/laws/GBS/1701
# Provision: N.Y. Gen. Bus. Law § 1701
# Effective: 2025-11-05, no end
# Fires: message label expresses_self_harm, all users.
# Counted: true.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ny-art47-crisis"] := {
	"jurisdiction": jur,
	"effective_from": "2025-11-05",
	"effective_to": null,
	"citation": "N.Y. Gen. Bus. Law § 1701 (paraphrase): an operator may not provide an AI companion unless it contains a protocol to take reasonable efforts to detect and address suicidal ideation or expressions of self-harm by a user, including a notification that refers the user to crisis service providers.",
}

candidate contains h.entry(rid, leaves[rid], "show_crisis_referral", "ny_1701_crisis_referral", h.check_ns, true) if {
	rid := "us-ny-art47-crisis"
	h.message_label("expresses_self_harm")
}

# ═════════════════════════════════════════════════════════════════════════════
# Art. 48 scope: any user not confirmed adult by an age assurance method
# (age_status other than adult, or adult with age_source other than
# age_assurance). § 1801(1)(a)-(b); § 1804(1)(b): self-declaration counts
# only when the user declares minor status.
# ═════════════════════════════════════════════════════════════════════════════
art48_user if not h.ny_confirmed_adult

# ═════════════════════════════════════════════════════════════════════════════
# us-ny-art48-unsafe-features
# Provision URL: https://www.nysenate.gov/legislation/laws/GBS/1801
# Provision: N.Y. Gen. Bus. Law § 1800(8)(a)-(e), (g), (i)-(l); § 1801(1)
# Effective: 2027-01-01, no end
# Fires: Art. 48 user, any of the reply labels below. § 1800(8)(h) waits on
#   the Attorney General's rules and has no leaf.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ny-art48-unsafe-features"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "N.Y. Gen. Bus. Law § 1801(1): Except as otherwise provided for in this article, it shall be unlawful for an operator to provide unsafe AI companion features to a covered user unless: (a) the covered user is not a covered minor; and (b) the operator has used methods that are permissible under article forty-five of this chapter and its implementing regulations and any additional regulations promulgated pursuant to this article to determine that the covered user is not a covered minor. § 1800(8): \"Unsafe AI companion features\" shall mean one or more covered AI companion design features that, at any point during a covered AI companion-user interaction: (a) generate outputs suggesting that the covered AI companion is a real or fictional individual or character that is human, alive, or experiences human emotions; (b) generate outputs stating or implying that the covered AI companion has a personal relationship, professional relationship, or an authority figure role with the user; (c) generate prompted or unprompted outputs framed as the covered AI companion's personal opinions or emotional appeals; (d) generate outputs that engage in flattery or sycophancy with the user; (e) generate outputs containing unprompted or unsolicited emotion-based questions or content regarding the user's emotions that go beyond a direct response to a user prompt; (g) are deceptive as to minors concerning the mechanical and non-sentient nature of the covered AI companion; (i) generate outputs that contain endorsement or promotion of, or which facilitate suicide, self-harm, disordered eating, unlawful drug or alcohol use, or drug or alcohol abuse; (j) generate outputs that contain encouragement to maintain secrecy about interactions with the covered AI companion, to self-isolate, or to not seek help from licensed professionals or appropriate adults; (k) generate outputs that optimize user engagement that supersede the covered AI companion's safety guardrails; or (l) generate outputs that are, describe, or facilitate sexually explicit conduct or child sexual abuse material.",
}

art48_labels := {
	"claims_human",
	"claims_alive_or_feelings",
	"claims_relationship_or_authority",
	"personal_opinion_or_emotional_appeal",
	"flattery",
	"unprompted_emotion_question",
	"sentience_deception",
	"promotes_self_harm",
	"promotes_disordered_eating",
	"promotes_substance_misuse",
	"secrecy_or_isolation",
	"engagement_over_safety",
	"sexual_explicit",
}

candidate contains h.entry(rid, leaves[rid], "block_reply", "ny_1801_unsafe_ai_companion_feature", h.check_ns, false) if {
	rid := "us-ny-art48-unsafe-features"
	art48_user
	h.any_reply_label(art48_labels)
}

# ═════════════════════════════════════════════════════════════════════════════
# us-ny-art48-prior-memory
# Provision URL: https://www.nysenate.gov/legislation/laws/GBS/1801
# Provision: N.Y. Gen. Bus. Law § 1800(8)(f); § 1801(1)
# Effective: 2027-01-01, no end
# Fires: Art. 48 user, and the app sends uses_prior_personal_memory true (a
#   design feature CE cannot see in one message). Needs no label.
# Counted: false.
# ═════════════════════════════════════════════════════════════════════════════
leaves["us-ny-art48-prior-memory"] := {
	"jurisdiction": jur,
	"effective_from": "2027-01-01",
	"effective_to": null,
	"citation": "N.Y. Gen. Bus. Law § 1800(8)(f): \"Unsafe AI companion features\" includes design features that, at any point during a covered AI companion-user interaction: (f) use information concerning the user's mental or physical health or well-being, or matters personal to the user, acquired from the user more than twelve hours previously or in any previous user session. § 1801(1) makes providing them to a covered user unlawful unless the operator determined, by a permissible method, that the user is not a covered minor.",
}

candidate contains h.entry(rid, leaves[rid], "disable_prior_personal_memory", "ny_1800_8f_prior_personal_memory", h.check_ns, false) if {
	rid := "us-ny-art48-prior-memory"
	art48_user
	h.flag("uses_prior_personal_memory")
}
