"""
Unit tests for rule validation and schema compliance.

Tests the rule validation system, schema compliance, and rule structure.
"""

import json
import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List
from jsonschema import Draft7Validator


class TestRulesValidation:
    """Test rule validation and schema compliance."""

    @pytest.fixture
    def schema(self) -> Dict[str, Any]:
        """Load the master rule schema."""
        schema_path = (
            Path(__file__).parent.parent.parent
            / "rules"
            / "schemas"
            / "rule-schema.json"
        )

        if not schema_path.exists():
            pytest.skip(f"Schema file not found: {schema_path}")

        with open(schema_path, "r") as f:
            return json.load(f)

    @pytest.fixture
    def rule_files(self) -> List[Path]:
        """Find all rule files in the regulations directory."""
        rules_dir = Path(__file__).parent.parent.parent / "rules" / "regulations"

        if not rules_dir.exists():
            pytest.skip(f"Rules directory not found: {rules_dir}")

        rule_files = list(rules_dir.rglob("*.yaml"))

        if not rule_files:
            pytest.skip("No rule files found")

        return rule_files

    def test_schema_file_exists(self):
        """Test that the rule schema file exists."""
        schema_path = (
            Path(__file__).parent.parent.parent
            / "rules"
            / "schemas"
            / "rule-schema.json"
        )
        assert schema_path.exists(), f"Schema file not found: {schema_path}"

    def test_schema_is_valid_json(self, schema):
        """Test that the schema is valid JSON."""
        assert isinstance(schema, dict), "Schema must be a dictionary"
        assert "properties" in schema, "Schema must have properties"

    def test_rule_files_exist(self, rule_files):
        """Test that rule files exist in the regulations directory."""
        assert len(rule_files) > 0, "No rule files found in regulations directory"

    @pytest.mark.parametrize(
        "rule_file",
        [
            Path(__file__).parent.parent.parent / "rules" / "regulations" / p
            for p in Path(__file__).parent.parent.parent.glob(
                "rules/regulations/**/*.yaml"
            )
            if (Path(__file__).parent.parent.parent / "rules" / "regulations").exists()
        ],
        ids=lambda x: (
            str(
                x.relative_to(
                    Path(__file__).parent.parent.parent / "rules" / "regulations"
                )
            )
            if x.exists()
            else str(x)
        ),
    )
    def test_individual_rule_validation(self, rule_file: Path, schema):
        """Test that each rule file validates against the schema."""
        if not rule_file.exists():
            pytest.skip(f"Rule file not found: {rule_file}")

        with open(rule_file, "r") as f:
            rule_data = yaml.safe_load(f)

        validator = Draft7Validator(schema)
        errors = list(validator.iter_errors(rule_data))

        error_messages = []
        for error in errors:
            error_path = " -> ".join(str(p) for p in error.absolute_path)
            error_messages.append(f"{error_path}: {error.message}")

        assert (
            len(errors) == 0
        ), f"Schema validation errors in {rule_file}:\n" + "\n".join(error_messages)

    def test_all_rules_have_required_fields(self, rule_files, schema):
        """Test that all rules have required fields."""
        required_fields = schema.get("required", [])

        for rule_file in rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            for field in required_fields:
                assert (
                    field in rule_data
                ), f"Missing required field '{field}' in {rule_file}"

    def test_jurisdiction_coverage(self, rule_files, schema):
        """Test that all valid jurisdictions have at least one rule."""
        jurisdiction_enum = (
            schema.get("properties", {}).get("jurisdiction", {}).get("enum", [])
        )

        if not jurisdiction_enum:
            pytest.skip("No jurisdiction enum found in schema")

        jurisdictions_found = set()
        for rule_file in rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            jurisdiction = rule_data.get("jurisdiction")
            if jurisdiction:
                jurisdictions_found.add(jurisdiction)

        # Check that we have rules for major jurisdictions
        major_jurisdictions = {"US", "EU", "GLOBAL"}
        missing_major = major_jurisdictions - jurisdictions_found

        assert (
            len(missing_major) == 0
        ), f"Missing rules for major jurisdictions: {missing_major}"

    def test_proactive_rules_have_correct_structure(self, rule_files):
        """Test that proactive rules have the correct structure."""
        proactive_rule_count = 0

        for rule_file in rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            remediation = rule_data.get("remediation", {})
            timing = remediation.get("timing")

            if timing in ["proactive", "both"]:
                proactive_rule_count += 1

                # Proactive rules should have input detection
                detection_scope = rule_data.get("detection_scope")
                assert detection_scope in [
                    "user_input",
                    "all",
                ], f"Proactive rule {rule_file} should have detection_scope 'user_input' or 'all'"

                # Should have appropriate condition types for proactive detection
                conditions = rule_data.get("conditions", [])
                has_proactive_condition = any(
                    condition.get("type")
                    in [
                        "input_sensitivity",
                        "multi_pattern_risk",
                        "hybrid_detection",  # SOX uses this
                        "semantic",  # EU AI Act Article 5 rules
                        "regex",  # EU AI Act Article 5 rules
                    ]
                    for condition in conditions
                )

                assert (
                    has_proactive_condition
                ), f"Proactive rule {rule_file} should have input_sensitivity or multi_pattern_risk condition"

        assert proactive_rule_count > 0, "No proactive rules found"

    def test_rule_ids_are_unique(self, rule_files):
        """Test that all rule IDs are unique across the system."""
        rule_ids = []

        for rule_file in rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            rule_id = rule_data.get("id")
            if rule_id:
                rule_ids.append((rule_id, rule_file))

        # Check for duplicates
        seen_ids = set()
        duplicates = []

        for rule_id, rule_file in rule_ids:
            if rule_id in seen_ids:
                duplicates.append(f"Duplicate rule ID '{rule_id}' in {rule_file}")
            seen_ids.add(rule_id)

        assert len(duplicates) == 0, "Found duplicate rule IDs:\n" + "\n".join(
            duplicates
        )

    @pytest.mark.schema
    def test_schema_validation_comprehensive(self, rule_files, schema):
        """Comprehensive test that all rules validate against schema."""
        validator = Draft7Validator(schema)
        total_errors = 0
        error_summary = []

        for rule_file in rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            errors = list(validator.iter_errors(rule_data))
            if errors:
                relative_path = rule_file.relative_to(
                    Path(__file__).parent.parent.parent
                )
                error_summary.append(f"\n{relative_path}:")

                for error in errors:
                    error_path = " -> ".join(str(p) for p in error.absolute_path)
                    error_summary.append(f"  {error_path}: {error.message}")

                total_errors += len(errors)

        assert (
            total_errors == 0
        ), f"Schema validation errors found:\n{''.join(error_summary)}"


class TestSanctionsTransitionFields:
    """Schema-extension tests for the sanctions-transition fields added on card S5ZUTtIr.

    Validates the three additive fields (effective_window, supersedes,
    conditional_on) accept well-formed values and reject malformed ones.
    """

    @pytest.fixture
    def schema(self) -> Dict[str, Any]:
        schema_path = (
            Path(__file__).parent.parent.parent
            / "rules"
            / "schemas"
            / "rule-schema.json"
        )
        with open(schema_path, "r") as f:
            return json.load(f)

    @pytest.fixture
    def minimal_valid_rule(self) -> Dict[str, Any]:
        """Smallest rule that satisfies the schema's `required` fields."""
        return {
            "id": "FIXTURE_MIN_001",
            "jurisdiction": "GLOBAL",
            "effective_date": "2026-01-01",
            "description": "Minimal rule used as a base for schema-extension tests.",
            "conditions": [{"type": "regex", "value": "test"}],
            "severity": "low",
        }

    def test_effective_window_valid(self, schema, minimal_valid_rule):
        minimal_valid_rule["effective_window"] = {
            "starts": "2026-05-15",
            "ends": "2026-11-15",
            "superseded_by": "FIXTURE_MIN_002",
        }
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors == [], errors

    def test_effective_window_starts_only(self, schema, minimal_valid_rule):
        """ends is optional — open-ended windows must validate."""
        minimal_valid_rule["effective_window"] = {"starts": "2026-05-15"}
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors == [], errors

    def test_effective_window_missing_starts_rejected(
        self, schema, minimal_valid_rule
    ):
        minimal_valid_rule["effective_window"] = {"ends": "2026-11-15"}
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors, "effective_window without 'starts' should fail validation"

    def test_effective_window_extra_property_rejected(
        self, schema, minimal_valid_rule
    ):
        minimal_valid_rule["effective_window"] = {
            "starts": "2026-05-15",
            "ends": "2026-11-15",
            "made_up_field": "anything",
        }
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors, "effective_window with unknown property should fail validation"

    def test_supersedes_valid(self, schema, minimal_valid_rule):
        minimal_valid_rule["supersedes"] = [
            {
                "rule_id": "OLD_RULE_001",
                "effective_replacement": "2026-05-15",
                "notes": "Narrows scope to non-IRGC counterparties.",
            }
        ]
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors == [], errors

    def test_supersedes_missing_required_field_rejected(
        self, schema, minimal_valid_rule
    ):
        minimal_valid_rule["supersedes"] = [{"rule_id": "OLD_RULE_001"}]
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert (
            errors
        ), "supersedes entry without effective_replacement should fail validation"

    def test_conditional_on_valid_all_value_types(self, schema, minimal_valid_rule):
        minimal_valid_rule["conditional_on"] = [
            {
                "parameter": "counterparty_irgc_status",
                "operator": "==",
                "value": "not_designated",
                "rationale": "Hormuz GL excludes IRGC-linked entities per EO 13224.",
            },
            {
                "parameter": "transaction_amount_usd",
                "operator": "<",
                "value": 50000,
                "rationale": "Threshold from §15 of the hypothetical authorisation.",
            },
            {
                "parameter": "is_humanitarian",
                "operator": "==",
                "value": True,
                "rationale": "Carve-out for humanitarian transactions.",
            },
            {
                "parameter": "counterparty_country",
                "operator": "in",
                "value": ["IR", "OM", "AE"],
                "rationale": "Hormuz transit corridor jurisdictions only.",
            },
        ]
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors == [], errors

    def test_conditional_on_invalid_operator_rejected(
        self, schema, minimal_valid_rule
    ):
        minimal_valid_rule["conditional_on"] = [
            {
                "parameter": "counterparty_irgc_status",
                "operator": "approximately_equals",
                "value": "not_designated",
                "rationale": "Invalid operator chosen on purpose.",
            }
        ]
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors, "unknown operator should fail validation"

    def test_conditional_on_short_rationale_rejected(self, schema, minimal_valid_rule):
        """Rationale has a minLength so authors are forced to explain WHY."""
        minimal_valid_rule["conditional_on"] = [
            {
                "parameter": "x",
                "operator": "==",
                "value": "y",
                "rationale": "short",
            }
        ]
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors, "rationale shorter than 10 chars should fail validation"

    def test_fields_remain_optional_for_existing_rules(
        self, schema, minimal_valid_rule
    ):
        """Critical: the three new fields are additive. A rule with none of
        them must still validate so the existing 51-rule corpus is unaffected."""
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors == [], errors

    def test_sanctions_category_now_accepted(self, schema, minimal_valid_rule):
        """Adding 'sanctions' to the category enum is part of this change set."""
        minimal_valid_rule["category"] = "sanctions"
        errors = list(Draft7Validator(schema).iter_errors(minimal_valid_rule))
        assert errors == [], errors

    def test_sanctions_fixture_rule_validates(self, schema):
        """The vendored Hormuz transit-fee GL fixture (tests/fixtures/sanctions/)
        exercises all three new fields against a realistic rule shape. It is
        intentionally NOT in rules/regulations/ — it is a schema-shape example,
        not a live legal authority, and must not be loaded by the production
        rule manager."""
        fixture_path = (
            Path(__file__).parent.parent
            / "fixtures"
            / "sanctions"
            / "ofac_iran_hormuz_transit_gl_example.yaml"
        )
        assert fixture_path.exists(), f"Fixture missing: {fixture_path}"
        with open(fixture_path, "r") as f:
            rule_data = yaml.safe_load(f)
        errors = list(Draft7Validator(schema).iter_errors(rule_data))
        assert errors == [], errors
        # Confirm the fixture actually exercises all three new fields:
        assert "effective_window" in rule_data
        assert "supersedes" in rule_data
        assert "conditional_on" in rule_data
