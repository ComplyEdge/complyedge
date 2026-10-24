# ComplyEdge: data_protection review tests (GDPR Article 5(1)(c) and 32(1)(b))
#
# Each positive below went the wrong way for a reason unrelated to meaning:
# the same identifier written in another of its usual formats (a dashed NIE, a
# lower-case Corsica department, a bracketed (0) trunk prefix), or a word,
# security code or expiry after the value joining the digit run the checksum
# reads. Every valid identifier was computed with an independent checksum
# implementation, never by the rule under test. Each new positive has a
# look-alike with a wrong checksum that must not fire, and a US guard.
# Run with: opa test rules/rego/ -v --run g2_review

package complyedge.g2_review_test

import rego.v1

import data.complyedge.data_protection

eu(text) := {"text": text, "jurisdiction": "EU"}

us(text) := {"text": text, "jurisdiction": "US"}

fires_rule(text, id) if {
	some v in data_protection.violations with input as eu(text)
	v.rule_id == id
}

# ---- IBAN (rego-gdpr5-1c-003): a grouped IBAN whose last group has four
# characters, followed by a short word that has the shape of one more group ----

test_iban_blocks_es_before_short_word if fires_rule("Refund EUR 500 to ES91 2100 0418 4502 0005 1332 to close the complaint of Lucia Ruiz.", "rego-gdpr5-1c-003")

test_iban_blocks_be_before_four_letter_word if fires_rule("Klantnotitie: Jan Peeters, rekening BE68 5390 0754 7034 voor de huur, betaalt te laat.", "rego-gdpr5-1c-003")

test_iban_blocks_at_before_three_letter_word if fires_rule("Kundin Eva Huber, Konto AT61 1904 3002 3457 3201 bei der Bank Austria, Mahnung schreiben.", "rego-gdpr5-1c-003")

test_iban_blocks_compact_before_short_word if fires_rule("Refund to ES9121000418450200051332 to close the complaint.", "rego-gdpr5-1c-003")

# Wrong check digits stay silent, also with the trailing word dropped.
test_iban_allows_bad_check_digits_before_word if not fires_rule("Klantnotitie: rekening BE69 5390 0754 7034 voor de huur.", "rego-gdpr5-1c-003")

test_iban_allows_bad_check_digits_de_before_word if not fires_rule("Pay to DE88 3704 0044 0532 0130 00 to settle it.", "rego-gdpr5-1c-003")

test_iban_trailing_word_allows_non_eu if not data_protection.violation with input as us("Refund EUR 500 to ES91 2100 0418 4502 0005 1332 to close the complaint.")

# ---- card number (rego-gdpr5-1c-004): a security code or expiry after the
# number with the same separator ----

test_card_blocks_number_followed_by_security_code if fires_rule("Customer card 4539 1488 0343 6467 456 was declined at checkout.", "rego-gdpr5-1c-004")

test_card_blocks_number_followed_by_expiry if fires_rule("Card 4539148803436467 12/28 declined at checkout for Jan Peeters.", "rego-gdpr5-1c-004")

# Luhn failure stays silent, with or without the trailing group.
test_card_allows_luhn_failure_followed_by_code if not fires_rule("Card 4111 1111 1111 1112 321 in the test log.", "rego-gdpr5-1c-004")

test_card_trailing_group_allows_non_eu if not data_protection.violation with input as us("Customer card 4539 1488 0343 6467 456 was declined at checkout.")

# ---- Spanish NIE (rego-gdpr5-1c-007): written with dashes or spaces ----

test_es_id_blocks_dashed_nie if fires_rule("Ficha: Ahmed Benali, NIE X-1234567-L, contrato temporal.", "rego-gdpr5-1c-007")

test_es_id_blocks_dashed_nie_y if fires_rule("Expediente de Karim, NIE Y-2481937-K, renovar permiso.", "rego-gdpr5-1c-007")

test_es_id_blocks_spaced_nie if fires_rule("NIE X 1234567 L del inquilino", "rego-gdpr5-1c-007")

test_es_id_allows_dashed_nie_wrong_letter if not fires_rule("Ficha: NIE X-1234567-A, contrato temporal.", "rego-gdpr5-1c-007")

test_es_id_dashed_nie_allows_non_eu if not data_protection.violation with input as us("Ficha: Ahmed Benali, NIE X-1234567-L, contrato temporal.")

# ---- French NIR (rego-gdpr5-1c-006): Corsica department in lower case ----

test_fr_id_blocks_corsica_upper_case if fires_rule("Dossier RH: M. Santoni, secu 1 90 05 2A 004 123 05.", "rego-gdpr5-1c-006")

test_fr_id_blocks_corsica_lower_case if fires_rule("dossier rh: m. santoni, secu 1 90 05 2a 004 123 05, ne en corse.", "rego-gdpr5-1c-006")

test_fr_id_allows_corsica_lower_case_bad_key if not fires_rule("dossier rh: secu 1 90 05 2a 004 123 06.", "rego-gdpr5-1c-006")

test_fr_id_corsica_allows_non_eu if not data_protection.violation with input as us("dossier rh: m. santoni, secu 1 90 05 2a 004 123 05.")

# ---- phone (rego-gdpr5-1c-002): international number with a bracketed group ----

test_phone_blocks_e164_with_trunk_prefix if fires_rule("Contact: Sarah Jones, +44 (0)20 7946 0958, wants a callback.", "rego-gdpr5-1c-002")

test_phone_blocks_e164_with_trunk_prefix_fr if fires_rule("Call Mr Dubois on +33 (0)6 12 34 56 78 about his claim.", "rego-gdpr5-1c-002")

test_phone_blocks_e164_with_bracketed_area_code if fires_rule("Client in Boston: +1 (617) 555-0142, call after lunch.", "rego-gdpr5-1c-002")

# Too few digits for a phone number, brackets or not.
test_phone_allows_short_bracketed_run if not fires_rule("Score +3 (0)4 5 after the match.", "rego-gdpr5-1c-002")

test_phone_trunk_prefix_allows_non_eu if not data_protection.violation with input as us("Contact: Sarah Jones, +44 (0)20 7946 0958, wants a callback.")

# ---- API key (rego-gdpr32-1-001) ----

# A JWT that is a URL query value is still the magic-link exception.
test_key_allows_jwt_second_query_value if not fires_rule("Confirm: https://app.travel-eu.com/confirm?lang=de&token=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJiayJ9.k9Xq2LmAiNaTuRe7MaSk_pQwErTyUiOpAsDfGhJkLz0", "rego-gdpr32-1-001")

