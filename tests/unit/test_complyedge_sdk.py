"""
Unit tests for ComplyEdge Python SDK

This test suite validates all three SDK interfaces:
1. Simple class-based interface (ComplyEdge)
2. Simple global functions (is_safe, check)
3. Advanced enterprise interface (ComplyEdgeClient)
"""

import os
import sys
from unittest.mock import Mock, patch

import pytest

# Add SDK directory to path for SDK imports
project_root = os.path.join(os.path.dirname(__file__), "..", "..")
sdk_path = os.path.join(project_root, "sdks", "python")
sys.path.insert(0, sdk_path)

# Import all SDK interfaces
from complyedge import (
    ComplianceError,
    ComplianceResult,
    ComplianceViolation,
    ComplyEdge,
    ComplyEdgeClient,
    DirectionType,
    SeverityLevel,
    check,
    is_safe,
)


class TestComplianceDataModels:
    """Test SDK data models and enums."""

    def test_severity_level_enum(self):
        """Test SeverityLevel enum values."""
        assert SeverityLevel.LOW.value == "low"
        assert SeverityLevel.MEDIUM.value == "medium"
        assert SeverityLevel.HIGH.value == "high"
        assert SeverityLevel.CRITICAL.value == "critical"

    def test_direction_type_enum(self):
        """Test DirectionType enum values."""
        assert DirectionType.PROMPT.value == "prompt"
        assert DirectionType.OUTPUT.value == "output"

    def test_compliance_violation_creation(self):
        """Test ComplianceViolation data class."""
        violation = ComplianceViolation(
            rule_id="TEST_001",
            rule_description="Test violation description",
            severity=SeverityLevel.HIGH,
            reason="Test reason",
            confidence=0.95,
        )

        assert violation.rule_id == "TEST_001"
        assert violation.rule_description == "Test violation description"
        assert violation.severity == SeverityLevel.HIGH
        assert violation.reason == "Test reason"
        assert violation.confidence == 0.95

    def test_compliance_result_creation(self):
        """Test ComplianceResult data class."""
        violation = ComplianceViolation(
            rule_id="SOX_001",
            rule_description="Material disclosure",
            severity=SeverityLevel.HIGH,
            reason="Forward-looking statement",
            confidence=0.95,
        )

        result = ComplianceResult(
            event_id="test-123",
            allowed=False,
            violations=[violation],
            latency_ms=150,
            bundle_version="2024.12",
            evaluated_rules=["SOX_001", "GDPR_001"],
        )

        assert result.event_id == "test-123"
        assert result.allowed is False
        assert len(result.violations) == 1
        assert result.latency_ms == 150
        assert result.safe is False
        assert result.blocked is True
        assert result.reason == "Material disclosure"


class TestSimpleInterface:
    """Test the simple ComplyEdge class interface."""

    def test_complyedge_initialization(self):
        """Test ComplyEdge class initialization."""
        ce = ComplyEdge(api_key="test_key", base_url="http://test.com")
        assert ce.api_key == "test_key"
        assert ce.base_url == "http://test.com"

    def test_complyedge_initialization_defaults(self):
        """Test ComplyEdge class with default values."""
        ce = ComplyEdge(api_key="test_key")
        assert ce.api_key == "test_key"
        # Unprefixed key: EU default (the US stack is dormant).
        assert ce.base_url == "https://eu.api.complyedge.io"

    @patch("httpx.Client.post")
    def test_is_safe_method_safe_response(self, mock_post):
        """Test is_safe method with safe response."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "allowed": True,
            "violations": [],
            "event_id": "test-123",
            "latency_ms": 50,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_post.return_value = mock_response

        ce = ComplyEdge(api_key="test_key")
        result = ce.is_safe("Safe text")

        assert result is True
        mock_post.assert_called_once()

    @patch("httpx.Client.post")
    def test_is_safe_method_blocked_response(self, mock_post):
        """Test is_safe method with blocked response."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "SOX_001",
                    "rule_description": "Material disclosure violation",
                    "severity": "high",
                    "reason": "Forward-looking statement",
                    "confidence": 0.95,
                    "text_excerpt": "Forward-looking statement",
                }
            ],
            "event_id": "test-123",
            "latency_ms": 150,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_post.return_value = mock_response

        ce = ComplyEdge(api_key="test_key")
        result = ce.is_safe("Risky text")

        assert result is False
        mock_post.assert_called_once()

    @patch("httpx.Client.post")
    def test_missing_allowed_field_is_blocked(self, mock_post):
        """A 200 with no `allowed` used to default True (fail-open)."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "event_id": "test-123",
            "violations": [],
            "latency_ms": 10,
        }
        mock_post.return_value = mock_response

        ce = ComplyEdge(api_key="test_key")
        result = ce.check("anything")
        assert result.allowed is False
        assert ce.is_safe("anything") is False

    @patch("httpx.Client.post")
    def test_missing_audit_logged_field_is_false(self, mock_post):
        """A 200 with no `audit_logged` used to default True (fail-open)."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "event_id": "test-123",
            "allowed": True,
            "violations": [],
            "latency_ms": 10,
        }
        mock_post.return_value = mock_response

        ce = ComplyEdge(api_key="test_key")
        result = ce.check("anything")
        assert result.audit_logged is False

    @patch("httpx.Client.post")
    def test_non_boolean_allowed_is_blocked(self, mock_post):
        """bool('false') and bool(1) used to pass. Only JSON true is a pass."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_post.return_value = mock_response
        ce = ComplyEdge(api_key="test_key")
        for value in ("true", "false", 1, 0, "True"):
            mock_response.json.return_value = {
                "event_id": "test-123",
                "allowed": value,
                "violations": [],
            }
            assert ce.check("anything").allowed is False, repr(value)

    @patch("httpx.Client.post")
    def test_check_method(self, mock_post):
        """Test check method returning ComplianceResult."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "SOX_001",
                    "rule_description": "Material disclosure violation",
                    "severity": "high",
                    "reason": "Forward-looking statement",
                    "confidence": 0.95,
                    "text_excerpt": "Forward-looking statement",
                }
            ],
            "event_id": "test-123",
            "latency_ms": 150,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_post.return_value = mock_response

        ce = ComplyEdge(api_key="test_key")
        result = ce.check("Risky text")

        assert isinstance(result, ComplianceResult)
        assert result.blocked is True
        assert result.safe is False
        assert len(result.violations) == 1
        assert result.violations[0].rule_id == "SOX_001"
        mock_post.assert_called_once()


class TestGlobalFunctions:
    """Test global convenience functions."""

    @patch("httpx.Client.post")
    def test_is_safe_global_function(self, mock_post):
        """Test global is_safe function."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "allowed": True,
            "violations": [],
            "event_id": "test-123",
            "latency_ms": 50,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_post.return_value = mock_response

        result = is_safe("Safe text", api_key="test_key")

        assert result is True
        mock_post.assert_called_once()

    @patch("httpx.Client.post")
    def test_check_global_function(self, mock_post):
        """Test global check function."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "SOX_001",
                    "rule_description": "Sensitive FINANCIAL_DATA detected",
                    "severity": "high",
                    "reason": "Forward-looking statement",
                    "confidence": 0.95,
                    "text_excerpt": "Forward-looking statement",
                }
            ],
            "event_id": "test-123",
            "latency_ms": 150,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_post.return_value = mock_response

        result = check("Risky text", api_key="test_key")

        assert isinstance(result, ComplianceResult)
        assert result.blocked is True
        assert result.safe is False
        assert result.reason == "Sensitive FINANCIAL_DATA detected"
        mock_post.assert_called_once()


class TestAdvancedInterface:
    """Test advanced ComplyEdgeClient interface."""

    def test_client_initialization(self):
        """Test ComplyEdgeClient initialization."""
        client = ComplyEdgeClient(api_key="test_key", base_url="http://test.com")
        assert client.api_key == "test_key"
        assert client.base_url == "http://test.com"

    @patch("httpx.Client.post")
    def test_check_compliance_method(self, mock_post):
        """Test check_compliance method."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "SOX_001",
                    "rule_description": "Material disclosure violation",
                    "severity": "high",
                    "reason": "Forward-looking statement",
                    "confidence": 0.95,
                    "text_excerpt": "Forward-looking statement",
                }
            ],
            "event_id": "test-123",
            "latency_ms": 150,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_post.return_value = mock_response

        client = ComplyEdgeClient(api_key="test_key")
        result = client.check_compliance(
            text="Test text", agent_id="test-agent", jurisdiction="US"
        )

        assert isinstance(result, ComplianceResult)
        assert result.allowed is False
        assert len(result.violations) == 1
        assert result.event_id == "test-123"
        assert result.latency_ms == 150
        mock_post.assert_called_once()


class TestErrorHandling:
    """Test error handling scenarios."""

    @patch("httpx.Client.post")
    def test_api_error_handling(self, mock_post):
        """Test handling of API errors."""
        # Mock HTTP error response
        from httpx import HTTPStatusError, Request, Response

        request = Request("POST", "http://test.com")
        response = Response(400, request=request)
        response._content = b'{"detail": "Bad request"}'

        mock_post.side_effect = HTTPStatusError(
            "400 Bad Request", request=request, response=response
        )

        ce = ComplyEdge(api_key="test_key")

        # is_safe catches exceptions and returns False (conservative approach)
        result = ce.is_safe("Test text")
        assert result is False

        # check method should raise ComplianceError
        with pytest.raises(ComplianceError) as exc_info:
            ce.check("Test text")

        assert "API error (400)" in str(exc_info.value)

    def test_missing_api_key_error(self):
        """Test error when API key is missing."""
        with pytest.raises(TypeError):
            is_safe("Test text")  # Missing required api_key argument


class TestComplianceResult:
    """Test ComplianceResult helper properties."""

    def test_compliance_result_safe_property(self):
        """Test ComplianceResult.safe property."""
        # Safe result
        result = ComplianceResult(
            event_id="test-123",
            allowed=True,
            violations=[],
            latency_ms=50,
            bundle_version="2024.12",
            evaluated_rules=["SOX_001"],
        )
        assert result.safe is True
        assert result.blocked is False
        assert result.reason is None

    def test_compliance_result_blocked_property(self):
        """Test ComplianceResult.blocked property."""
        # Blocked result
        violation = ComplianceViolation(
            rule_id="SOX_001",
            rule_description="Material information disclosure",
            severity=SeverityLevel.HIGH,
            reason="Forward-looking statement",
            confidence=0.95,
        )
        result = ComplianceResult(
            event_id="test-123",
            allowed=False,
            violations=[violation],
            latency_ms=150,
            bundle_version="2024.12",
            evaluated_rules=["SOX_001"],
        )
        assert result.safe is False
        assert result.blocked is True
        assert result.reason == "Material information disclosure"

    def test_compliance_result_violation_count(self):
        """Test ComplianceResult.violation_count property."""
        violation1 = ComplianceViolation(
            rule_id="SOX_001",
            rule_description="SOX violation",
            severity=SeverityLevel.HIGH,
            reason="Material disclosure",
            confidence=0.95,
        )
        violation2 = ComplianceViolation(
            rule_id="GDPR_001",
            rule_description="GDPR violation",
            severity=SeverityLevel.MEDIUM,
            reason="PII exposure",
            confidence=0.85,
        )

        result = ComplianceResult(
            event_id="test-123",
            allowed=False,
            violations=[violation1, violation2],
            latency_ms=200,
            bundle_version="2024.12",
            evaluated_rules=["SOX_001", "GDPR_001"],
        )

        assert result.violation_count == 2
        assert len(result.violations) == 2


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v"])
