"""
Unit tests for existing rule functionality and compliance detection.

Tests that focus on the actual rule detection logic and business functionality.
"""

import pytest
from pathlib import Path
from typing import Dict, Any, List
import yaml


class TestRulesExisting:
    """Test existing rule functionality and detection capabilities."""

    @pytest.fixture
    def eu_ai_act_rules(self) -> List[Dict[str, Any]]:
        """Load EU AI Act rules for testing."""
        rules_dir = Path(__file__).parent.parent.parent / "rules" / "regulations"
        eu_rules = []

        if not rules_dir.exists():
            pytest.skip("Rules directory not found")

        for rule_file in rules_dir.rglob("*article5*.yaml"):
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)
                if rule_data:
                    eu_rules.append(rule_data)

        return eu_rules

    @pytest.fixture
    def sample_rule_files(self) -> List[Path]:
        """Get a sample of rule files for testing."""
        rules_dir = Path(__file__).parent.parent.parent / "rules" / "regulations"

        if not rules_dir.exists():
            pytest.skip("Rules directory not found")

        rule_files = list(rules_dir.rglob("*.yaml"))[:5]  # Sample first 5

        if not rule_files:
            pytest.skip("No rule files found")

        return rule_files

    def test_eu_ai_act_rules_exist(self, eu_ai_act_rules):
        """Test that EU AI Act Article 5 rules exist and are properly structured."""
        assert len(eu_ai_act_rules) > 0, "No EU AI Act Article 5 rules found"

        for rule in eu_ai_act_rules:
            assert "id" in rule, "EU AI Act rule missing ID"
            assert "jurisdiction" in rule, "EU AI Act rule missing jurisdiction"
            assert rule["jurisdiction"] == "EU", "EU AI Act rules should be EU jurisdiction"

    def test_rules_have_valid_structure(self, sample_rule_files):
        """Test that rules have the basic required structure."""
        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            # Check required top-level fields
            required_fields = ["id", "jurisdiction", "conditions", "remediation"]
            for field in required_fields:
                assert field in rule_data, f"Missing {field} in {rule_file}"

            # Check conditions structure
            conditions = rule_data["conditions"]
            assert isinstance(
                conditions, list
            ), f"Conditions must be list in {rule_file}"
            assert (
                len(conditions) > 0
            ), f"Must have at least one condition in {rule_file}"

            for condition in conditions:
                assert "type" in condition, f"Condition missing type in {rule_file}"

    def test_proactive_rules_functionality(self, sample_rule_files):
        """Test that proactive rules have correct functional structure."""
        proactive_count = 0

        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            remediation = rule_data.get("remediation", {})
            timing = remediation.get("timing")

            if timing in ["proactive", "both"]:
                proactive_count += 1

                # Should have detection scope
                assert (
                    "detection_scope" in rule_data
                ), f"Proactive rule missing detection_scope: {rule_file}"

                detection_scope = rule_data["detection_scope"]
                assert detection_scope in [
                    "user_input",
                    "ai_output",
                    "all",
                ], f"Invalid detection_scope in {rule_file}: {detection_scope}"

        # We should have at least some proactive rules
        if proactive_count == 0:
            pytest.skip("No proactive rules found in sample")

    def test_rule_conditions_are_actionable(self, sample_rule_files):
        """Test that rule conditions contain actionable detection logic."""
        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            conditions = rule_data["conditions"]

            for condition in conditions:
                condition_type = condition["type"]

                # Each condition type should have appropriate parameters
                if condition_type == "regex":
                    # Rule files use either 'pattern' or 'value' for regex
                    assert (
                        "pattern" in condition or "value" in condition
                    ), f"Regex condition missing pattern/value in {rule_file}"
                elif condition_type == "semantic":
                    assert (
                        "description" in condition
                    ), f"Semantic condition missing description in {rule_file}"
                elif condition_type == "input_sensitivity":
                    # Input sensitivity conditions use 'patterns' or other fields
                    assert (
                        "sensitivity_keywords" in condition
                        or "patterns" in condition
                        or "sensitivity_type" in condition
                    ), f"Input sensitivity missing required fields in {rule_file}"
                elif condition_type == "metadata":
                    # Metadata conditions can have 'checks' or individual fields
                    assert "checks" in condition or (
                        "key" in condition and "op" in condition
                    ), f"Metadata condition missing required fields in {rule_file}"
                elif condition_type == "hybrid_detection":
                    # Complex hybrid detection structure
                    assert (
                        "tier1_config" in condition or "tier2_config" in condition
                    ), f"Hybrid detection missing tier config in {rule_file}"

    def test_eu_jurisdiction_rules_exist(self, sample_rule_files):
        """Test that EU jurisdiction rules exist."""
        eu_rules = []

        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            if rule_data.get("jurisdiction") == "EU":
                eu_rules.append(rule_data)

        assert len(eu_rules) > 0, "No EU jurisdiction rules found in sample"

    def test_remediation_messages_exist(self, sample_rule_files):
        """Test that all rules have meaningful remediation messages."""
        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            remediation = rule_data["remediation"]

            assert (
                "message" in remediation
            ), f"Missing remediation message in {rule_file}"

            message = remediation["message"]
            assert isinstance(
                message, str
            ), f"Remediation message must be string in {rule_file}"
            assert len(message) > 10, f"Remediation message too short in {rule_file}"

    @pytest.mark.proactive
    def test_proactive_rule_detection_capabilities(self, sample_rule_files):
        """Test that proactive rules can actually detect violations."""
        proactive_rules_tested = 0

        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            remediation = rule_data.get("remediation", {})
            if remediation.get("timing") in ["proactive", "both"]:
                proactive_rules_tested += 1

                # Test that the rule has detectable conditions
                conditions = rule_data["conditions"]
                has_detectable_condition = False

                for condition in conditions:
                    condition_type = condition["type"]
                    if condition_type in [
                        "input_sensitivity",
                        "multi_pattern_risk",
                        "regex",
                        "hybrid_detection",
                    ]:
                        has_detectable_condition = True
                        break

                assert (
                    has_detectable_condition
                ), f"Proactive rule has no detectable conditions: {rule_file}"

        if proactive_rules_tested == 0:
            pytest.skip("No proactive rules found in sample for testing")

    def test_rule_source_citations_exist(self, sample_rule_files):
        """Test that rules have proper regulatory source citations."""
        for rule_file in sample_rule_files:
            with open(rule_file, "r") as f:
                rule_data = yaml.safe_load(f)

            assert "source" in rule_data, f"Missing source citation in {rule_file}"

            source = rule_data["source"]
            assert (
                "regulation" in source
            ), f"Missing regulation in source for {rule_file}"
            # Rules may use 'section', 'article', or 'title' for specific reference
            assert (
                "section" in source or "article" in source or "title" in source
            ), f"Missing section/article/title in source for {rule_file}"
