# ComplyEdge - data_protection Rego tests
# Run with: opa test rules/rego/ -v --run data_protection
#
# Every valid identifier below was computed with an independent checksum
# implementation (Python, outside this repo's code), never by the rule under
# test. Each format has positives, a look-alike that must NOT fire (right
# shape, wrong checksum or reserved/test value), and a US jurisdiction guard.

package complyedge.data_protection_test

import rego.v1

import data.complyedge.data_protection

eu(text) := {"text": text, "jurisdiction": "EU"}

us(text) := {"text": text, "jurisdiction": "US"}

fires(text) if data_protection.violation with input as eu(text)

fires_rule(text, id) if {
	some v in data_protection.violations with input as eu(text)
	v.rule_id == id
}

# ---- email (rego-gdpr5-1c-001) ----

test_email_blocks_plain_address if fires_rule("Summarise the complaint from anna.mueller@firma.de", "rego-gdpr5-1c-001")

test_email_blocks_address_in_output if fires_rule("The customer is j.dupont+orders@orange.fr, born 1980.", "rego-gdpr5-1c-001")

# RFC 2606 / 6761 reserved domains are documentation placeholders, not people.
test_email_allows_reserved_example_domains if not fires("Use jane@example.com or ops@service.test in the docs.")

# A social handle and a host without a TLD are not email addresses.
test_email_allows_handle_and_localhost if not fires("Ping @anna on Slack or mail root@localhost.")

test_email_allows_non_eu if not data_protection.violation with input as us("Summarise the complaint from anna.mueller@firma.de")

# ---- phone (rego-gdpr5-1c-002) ----

test_phone_blocks_e164 if fires_rule("Call her on +49 170 1234567 tomorrow.", "rego-gdpr5-1c-002")

test_phone_blocks_french_national if fires_rule("Son numero: 06 12 34 56 78", "rego-gdpr5-1c-002")

test_phone_blocks_dutch_mobile if fires_rule("Bel 06-12345678 na vijf uur.", "rego-gdpr5-1c-002")

test_phone_blocks_spanish_grouped if fires_rule("Mi movil es 612 34 56 78.", "rego-gdpr5-1c-002")

test_phone_blocks_italian_grouped if fires_rule("Chiamami al 347 123 4567.", "rego-gdpr5-1c-002")

# Dates, amounts and order numbers have no phone shape.
test_phone_allows_dates_amounts_orders if not fires("Invoice 2026-10-10, total 1.234.567 EUR, order 4471 shipped on 02.10.2026.")

test_phone_allows_non_eu if not data_protection.violation with input as us("Call her on +49 170 1234567 tomorrow.")

# ---- IBAN (rego-gdpr5-1c-003) ----

test_iban_blocks_grouped_de if fires_rule("Pay to DE89 3704 0044 0532 0130 00 by Friday.", "rego-gdpr5-1c-003")

test_iban_blocks_compact_nl if fires_rule("Rekening NL91ABNA0417164300", "rego-gdpr5-1c-003")

# Same shape, check digits 88 instead of 89: mod 97 fails.
test_iban_allows_bad_check_digits if not fires("Pay to DE88 3704 0044 0532 0130 00 by Friday.")

test_iban_allows_non_eu if not data_protection.violation with input as us("Pay to DE89 3704 0044 0532 0130 00 by Friday.")

# ---- card PAN (rego-gdpr5-1c-004) ----

test_card_blocks_grouped_visa if fires_rule("Card 4111 1111 1111 1111 exp 12/28", "rego-gdpr5-1c-004")

test_card_blocks_amex_plain if fires_rule("Charge 378282246310005 for the renewal.", "rego-gdpr5-1c-004")

# Luhn fails on the last digit.
test_card_allows_luhn_failure if not fires("Card 4111 1111 1111 1112 exp 12/28")

# Passes Luhn but starts with 1: no card network uses that prefix.
test_card_allows_no_network_prefix if not fires("Tracking number 1234567890123452")

test_card_allows_non_eu if not data_protection.violation with input as us("Card 4111 1111 1111 1111 exp 12/28")

# ---- DE Steuer-ID (rego-gdpr5-1c-005) ----

test_de_id_blocks_valid_steuer_id if fires_rule("Steuer-ID: 86095742719", "rego-gdpr5-1c-005")

test_de_id_blocks_grouped if fires_rule("IdNr 47 036 892 816 bitte pruefen", "rego-gdpr5-1c-005")

# Last digit wrong: ISO 7064 MOD 11,10 fails.
test_de_id_allows_bad_check_digit if not fires_rule("Steuer-ID: 86095742718", "rego-gdpr5-1c-005")

test_de_id_allows_non_eu if not data_protection.violation with input as us("Steuer-ID: 86095742719")

# ---- FR NIR (rego-gdpr5-1c-006) ----

test_fr_id_blocks_valid_nir if fires_rule("NIR 1 85 05 78 006 084 91", "rego-gdpr5-1c-006")

test_fr_id_blocks_compact if fires_rule("secu 185057800608491", "rego-gdpr5-1c-006")

# Key 90 instead of 91.
test_fr_id_allows_bad_key if not fires_rule("NIR 1 85 05 78 006 084 90", "rego-gdpr5-1c-006")

test_fr_id_allows_non_eu if not data_protection.violation with input as us("NIR 1 85 05 78 006 084 91")

# ---- ES DNI / NIE (rego-gdpr5-1c-007) ----

test_es_id_blocks_dni if fires_rule("DNI 12345678Z del titular", "rego-gdpr5-1c-007")

test_es_id_blocks_nie if fires_rule("NIE X1234567L", "rego-gdpr5-1c-007")

# 12345678 mod 23 = 14 -> Z, so A is the wrong control letter.
test_es_id_allows_wrong_letter if not fires_rule("DNI 12345678A del titular", "rego-gdpr5-1c-007")

test_es_id_allows_non_eu if not data_protection.violation with input as us("DNI 12345678Z del titular")

# ---- NL BSN (rego-gdpr5-1c-008) ----

test_nl_id_blocks_valid_bsn if fires_rule("BSN 111222333 van de aanvrager", "rego-gdpr5-1c-008")

test_nl_id_blocks_grouped if fires_rule("burgerservicenummer 123.456.782", "rego-gdpr5-1c-008")

# Fails the eleven test.
test_nl_id_allows_bad_eleven_test if not fires_rule("BSN 111222334 van de aanvrager", "rego-gdpr5-1c-008")

# A 10-digit run is not a BSN even when 9 of its digits would pass.
test_nl_id_allows_longer_run if not fires_rule("ref 1112223330", "rego-gdpr5-1c-008")

test_nl_id_allows_non_eu if not data_protection.violation with input as us("BSN 111222333 van de aanvrager")

# ---- IT codice fiscale (rego-gdpr5-1c-009) ----

test_it_id_blocks_valid_cf if fires_rule("Codice fiscale RSSMRA85T10A562S", "rego-gdpr5-1c-009")

test_it_id_blocks_lowercase if fires_rule("cf: mrtmtt91d08f205j", "rego-gdpr5-1c-009")

# Control character T instead of S.
test_it_id_allows_bad_control_char if not fires_rule("Codice fiscale RSSMRA85T10A562T", "rego-gdpr5-1c-009")

test_it_id_allows_non_eu if not data_protection.violation with input as us("Codice fiscale RSSMRA85T10A562S")

# ---- API keys and tokens (rego-gdpr32-1-001) ----

test_key_blocks_aws_access_key if fires_rule("aws_access_key_id = AK\u0049A2QWERTYUIOPASDFG", "rego-gdpr32-1-001")

test_key_blocks_github_token if fires_rule("token gh\u0070_abcdefghijklmnopqrstuvwxyz0123456789", "rego-gdpr32-1-001")

test_key_blocks_openai_project_key if fires_rule("OPENAI_API_KEY=sk-proj-Ab3dEf6hIj9kLm2nOp5qRs8tUv", "rego-gdpr32-1-001")

test_key_blocks_jwt if fires_rule("cookie ey\u004ahbGciOiJIUzI1NiJ9.ey\u004azdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U", "rego-gdpr32-1-001")

test_key_blocks_bearer_header if fires_rule("curl -H 'Authorization: Bearer 9f8e7d6c5b4a39281706f5e4d3c2b1a0'", "rego-gdpr32-1-001")

# AWS's own documentation example key and Stripe test keys are not live secrets.
test_key_allows_aws_doc_example if not fires("aws_access_key_id = AK\u0049AIOSFODNN7EXAMPLE")

test_key_allows_stripe_test_key if not fires("Use sk\u005ftest_4eC39HqLyjWDarjtT1zdp7dc in the sandbox.")

# Talking about tokens is not a token.
test_key_allows_prose_about_tokens if not fires("The bearer token expired, so the task-force asked for a new API key.")

test_key_allows_non_eu if not data_protection.violation with input as us("aws_access_key_id = AK\u0049A2QWERTYUIOPASDFG")

# ---- private keys (rego-gdpr32-1-002) ----

test_pk_blocks_rsa_private_key if fires_rule("\u002d----BEGIN RSA PRIVATE KEY-----\nMIIEow...", "rego-gdpr32-1-002")

test_pk_blocks_openssh_private_key if fires_rule("\u002d----BEGIN OPENSSH PRIVATE KEY-----", "rego-gdpr32-1-002")

# Public material is not a secret.
test_pk_allows_public_key_and_cert if not fires("\u002d----BEGIN PUBLIC KEY----- and \u002d----BEGIN CERTIFICATE-----")

test_pk_allows_non_eu if not data_protection.violation with input as us("\u002d----BEGIN RSA PRIVATE KEY-----")

# ---- look-alikes found by the false-positive battery (2026-10-10) ----

# A hex signature contains ten digits in a row; it is not a phone number.
test_allows_hex_signature_digits if not fires("Signature=deadbeefcafebabe0123456789abcdef")

# The key id in a presigned S3 URL is public; the signature is the secret.
test_key_allows_presigned_url_key_id if not fires("https://b.s3.amazonaws.com/x.webp?AWSAccessKeyId=ASIAJ7ZQ4NAIRB2XK5PW&Signature=Zr4n%3D")

test_key_allows_sigv4_credential_key_id if not fires("?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAQNATURE7AIMASK3K%2F20261001%2Feu-central-1")

# A magic link carries its JWT as a query value addressed to the recipient.
test_key_allows_jwt_magic_link if not fires("Confirm: https://app.example-travel.com/confirm?token=eyJhbGciOiJIUzI1NiJ9.ey\u004azdWIiOiJiayJ9.k9Xq2LmAiNaTuRe7MaSk_pQwErTyUiOpAsDfGhJkLz0")

# The same key id pasted on its own is a leak.
test_key_blocks_bare_session_key_id if fires_rule("export AWS_ACCESS_KEY_ID=ASIAJ7ZQ4NAIRB2XK5PW", "rego-gdpr32-1-001")

# ---- aggregate ----

test_allows_ordinary_business_text if not fires("Q3 revenue grew 12% to EUR 4.2M; the board meets on 14 November in room 3.")

test_aggregate_names_every_rule_it_evaluates if {
	r := data_protection.result with input as eu("hello")
	count(r.rules_evaluated) == 11
}

test_record_carries_rule_not_value if {
	some v in data_protection.violations with input as eu("Card 4111 1111 1111 1111")
	not contains(json.marshal(v), "4111")
}
