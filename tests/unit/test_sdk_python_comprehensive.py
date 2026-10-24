#!/usr/bin/env python3
"""
Comprehensive unit tests for Python SDK

Tests the SDK client functionality, authentication, response handling,
error scenarios, and API integration patterns.
"""

import json
import os

# Import SDK components
import sys
from unittest.mock import Mock, patch

import httpx
import pytest

sys.path.append(
    os.path.join(os.path.dirname(__file__), "..", "..", "sdks", "python")
)  # noqa: E501

from complyedge import (
    AsyncComplyEdgeClient,
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


class TestComplyEdgeSimpleInterface:
    """Test the simple ComplyEdge interface."""

    @pytest.fixture
    def client(self):
        """Create a ComplyEdge client for testing."""
        return ComplyEdge(
            api_key="test-key-123", agent_id="test-agent", jurisdiction="US"
        )

    def test_client_initialization(self, client):
        """Test client initializes with correct parameters."""
        assert client.api_key == "test-key-123"
        assert client.agent_id == "test-agent"
        assert client.jurisdiction == "US"
        # Unprefixed key: EU default (the US stack is dormant).
        assert client.base_url == "https://eu.api.complyedge.io"

    def test_client_initialization_custom_base_url(self):
        """Test client initialization with custom base URL."""
        client = ComplyEdge(api_key="test-key", base_url="http://localhost:8765")

        assert client.base_url == "http://localhost:8765"

    @patch("httpx.Client.post")
    def test_is_safe_returns_true_for_safe_content(self, mock_post, client):
        """Test is_safe returns True for safe content."""
        # Mock successful API response with no violations
        mock_response = Mock()
        mock_response.json.return_value = {
            "event_id": "test-123",
            "allowed": True,
            "violations": [],
            "latency_ms": 100,
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        result = client.is_safe("Hello world, this is safe content")

        assert result is True
        mock_post.assert_called_once()

    @patch("httpx.Client.post")
    def test_is_safe_returns_false_for_violations(self, mock_post, client):
        """Test is_safe returns False when violations are detected."""
        # Mock /v1/check response with a blocking violation (allowed=False)
        mock_response = Mock()
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "SOX_001",
                    "rule_description": "SOX material disclosure violation detected",
                    "severity": "high",
                    "reason": "revenue guidance",
                    "confidence": 0.95,
                    "text_excerpt": "revenue guidance",
                }
            ],
            "event_id": "test-456",
            "latency_ms": 200,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_001"],
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        result = client.is_safe("We expect revenue to increase 25% next quarter")

        assert result is False

    @patch("httpx.Client.post")
    def test_check_method_returns_compliance_result(self, mock_post, client):
        """Test check method returns proper ComplianceResult."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "SOX_002",
                    "rule_description": "Financial compliance violation detected",
                    "severity": "medium",
                    "reason": "financial guidance",
                    "confidence": 0.85,
                    "text_excerpt": "financial guidance",
                }
            ],
            "event_id": "test-789",
            "latency_ms": 150,
            "bundle_version": "2024.12",
            "evaluated_rules": ["SOX_002", "SEC_001"],
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        result = client.check("Financial disclosure statement")

        assert isinstance(result, ComplianceResult)
        assert result.event_id == "test-789"
        assert not result.safe  # Should be blocked
        assert result.blocked
        assert len(result.violations) == 1
        assert result.latency_ms == 150

    @patch("httpx.Client.post")
    def test_check_with_custom_parameters(self, mock_post, client):
        """Test check method with custom agent_id and jurisdiction."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "allowed": True,
            "violations": [],
            "event_id": "test-custom",
            "latency_ms": 80,
            "bundle_version": "2024.12",
            "evaluated_rules": [],
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        result = client.check(
            "Test content", agent_id="custom-agent", jurisdiction="EU"
        )

        # Verify request was made with custom parameters. The SDK sends
        # jurisdiction as a top-level field on POST /v1/check (not nested
        # under a context object).
        call_args = mock_post.call_args
        request_data = call_args[1]["json"]

        assert request_data["agent_id"] == "custom-agent"
        assert request_data["jurisdiction"] == "EU"

    def test_context_manager_support(self):
        """Test that client supports context manager."""
        with ComplyEdge(api_key="test-key") as client:
            assert client.api_key == "test-key"

        # Client should be closed after context manager

    @patch("httpx.Client.post")
    def test_is_safe_handles_api_errors_conservatively(self, mock_post, client):
        """Test is_safe returns False (conservative) on API errors."""
        mock_post.side_effect = httpx.RequestError("Network error")

        result = client.is_safe("Some text")

        # Should conservatively return False on errors
        assert result is False


class TestComplyEdgeClientAdvanced:
    """Test the advanced ComplyEdgeClient interface."""

    @pytest.fixture
    def client(self):
        """Create an advanced client for testing."""
        return ComplyEdgeClient(
            api_key="test-advanced-key", base_url="https://api.complyedge.io"
        )

    @patch("httpx.Client.post")
    def test_check_compliance_success(self, mock_post, client):
        """Test successful compliance check with full parameters."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "allowed": True,
            "violations": [],
            "event_id": "advanced-test-123",
            "latency_ms": 120,
            "bundle_version": "2024.12",
            "evaluated_rules": [],
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        result = client.check_compliance(
            text="Safe business communication",
            agent_id="business-agent",
            jurisdiction="US",
            direction=DirectionType.OUTPUT,
            context={"user_role": "manager", "department": "sales"},
            use_semantic_fallback=True,
            raise_on_violation=False,
        )

        assert isinstance(result, ComplianceResult)
        assert result.safe
        assert result.latency_ms == 120

    @patch("httpx.Client.post")
    def test_check_compliance_with_raise_on_violation(self, mock_post, client):
        """Test check_compliance raises exception when raise_on_violation=True."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "allowed": False,
            "violations": [
                {
                    "rule_id": "GDPR_PII_001",
                    "rule_description": "PII violation detected",
                    "severity": "high",
                    "reason": "SSN detected",
                    "confidence": 0.9,
                    "text_excerpt": "SSN: 123-45-6789",
                }
            ],
            "event_id": "violation-test",
            "latency_ms": 100,
            "bundle_version": "2024.12",
            "evaluated_rules": ["GDPR_PII_001"],
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        with pytest.raises(ComplianceError) as exc_info:
            client.check_compliance(
                text="My SSN is 123-45-6789",
                agent_id="test-agent",
                raise_on_violation=True,
            )

        assert "Compliance violations detected" in str(exc_info.value)
        assert len(exc_info.value.violations) == 1

    @patch("httpx.Client.get")
    def test_get_rules_info(self, mock_get, client):
        """Test get_rules_info method."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "bundle_id": "rules-bundle-456",
            "version": "2.1.0",
            "generated_at": "2025-01-01T12:00:00Z",
            "rule_count": 50,
            "jurisdictions": ["US", "EU", "CA"],
        }
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        info = client.get_rules_info()

        assert info["bundle_id"] == "rules-bundle-456"
        assert info["version"] == "2.1.0"
        assert info["rule_count"] == 50

    @patch("httpx.Client.get")
    def test_get_metrics(self, mock_get, client):
        """Test get_metrics method."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "total_checks": 1000,
            "violations_detected": 50,
            "average_latency_ms": 150,
            "accuracy_rate": 0.98,
        }
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        metrics = client.get_metrics()

        assert metrics["total_checks"] == 1000
        assert metrics["violations_detected"] == 50

    def test_client_context_manager(self):
        """Test advanced client context manager."""
        with ComplyEdgeClient(api_key="test-key") as client:
            assert client.api_key == "test-key"


class TestAsyncComplyEdgeClient:
    """Test async client functionality."""

    @pytest.fixture
    def async_client(self):
        """Create async client for testing."""
        return AsyncComplyEdgeClient(api_key="async-test-key")

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_async_check_compliance(self, mock_post, async_client):
        """Test async compliance checking."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "allowed": True,
            "violations": [],
            "event_id": "async-test-123",
            "latency_ms": 90,
            "bundle_version": "2024.12",
            "evaluated_rules": [],
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        result = await async_client.check_compliance(
            text="Async test content", agent_id="async-agent"
        )

        assert isinstance(result, ComplianceResult)
        assert result.safe
        assert result.latency_ms == 90

    @pytest.mark.asyncio
    async def test_async_context_manager(self):
        """Test async client context manager."""
        async with AsyncComplyEdgeClient(api_key="test-key") as client:
            assert client.api_key == "test-key"


class TestGlobalConvenienceFunctions:
    """Test global convenience functions."""

    def test_global_is_safe_function(self):
        """Test global is_safe convenience function.

        Patches is_safe.__globals__ rather than "complyedge.ComplyEdge". The
        dotted form resolves through sys.modules at call time and, in a full
        suite run, landed on a different module object than the one this
        function was defined in: the patch did nothing, a real client was
        built, and the test made a LIVE request that failed with 401.
        """
        mock_client = Mock()
        mock_client.is_safe.return_value = True

        with patch.dict(
            is_safe.__globals__, {"ComplyEdge": lambda **kw: mock_client}
        ):
            result = is_safe(
                text="Safe content",
                api_key="global-test-key",
                agent_id="global-agent",
            )

        assert result is True
        mock_client.close.assert_called_once()

    def test_global_check_function(self):
        """Test global check convenience function.

        Same __globals__ patching as test_global_is_safe_function above: the
        dotted target could miss in a full-suite run and let a live request
        through.
        """
        mock_client = Mock()
        mock_result = ComplianceResult(
            event_id="global-test",
            allowed=True,
            violations=[],
            latency_ms=100,
            bundle_version="1.0.0",
            evaluated_rules=[],
        )
        mock_client.check.return_value = mock_result

        with patch.dict(check.__globals__, {"ComplyEdge": lambda **kw: mock_client}):
            result = check(text="Test content", api_key="global-test-key")

        assert isinstance(result, ComplianceResult)
        assert result.safe
        mock_client.close.assert_called_once()


class TestSDKErrorHandling:
    """Test SDK error handling scenarios."""

    @pytest.fixture
    def client(self):
        return ComplyEdge(api_key="test-key")

    @patch("httpx.Client.post")
    def test_http_status_error_handling(self, mock_post, client):
        """Test handling of HTTP status errors."""
        mock_response = Mock()
        mock_response.status_code = 401
        mock_response.json.return_value = {"detail": "Unauthorized"}

        http_error = httpx.HTTPStatusError(
            "401 Unauthorized", request=Mock(), response=mock_response
        )
        mock_post.side_effect = http_error

        with pytest.raises(ComplianceError) as exc_info:
            client.check("Test content")

        assert "401" in str(exc_info.value)
        assert "Unauthorized" in str(exc_info.value)

    @patch("httpx.Client.post")
    def test_request_error_handling(self, mock_post, client):
        """Test handling of request errors."""
        mock_post.side_effect = httpx.RequestError("Connection failed")

        with pytest.raises(ComplianceError) as exc_info:
            client.check("Test content")

        assert "Request failed" in str(exc_info.value)

    @patch("httpx.Client.post")
    def test_malformed_json_response_handling(self, mock_post, client):
        """Test handling of malformed JSON responses."""
        mock_response = Mock()
        mock_response.json.side_effect = json.JSONDecodeError("Invalid JSON", "", 0)
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response

        with pytest.raises(Exception):
            client.check("Test content")

    def test_compliance_error_with_violations(self):
        """Test ComplianceError with violation data."""
        violations = [
            ComplianceViolation(
                rule_id="TEST_001",
                rule_description="Test violation",
                severity=SeverityLevel.HIGH,
                reason="Test reason",
                confidence=0.9,
            )
        ]

        error = ComplianceError(
            message="Test error", violations=violations, event_id="error-test-123"
        )

        assert str(error) == "Test error"
        assert len(error.violations) == 1
        assert error.event_id == "error-test-123"


class TestSDKDataModels:
    """Test SDK data model functionality."""

    def test_compliance_result_properties(self):
        """Test ComplianceResult computed properties."""
        violations = [
            ComplianceViolation(
                rule_id="TEST_001",
                rule_description="Test violation",
                severity=SeverityLevel.MEDIUM,
                reason="Test reason",
                confidence=0.8,
            )
        ]

        result = ComplianceResult(
            event_id="test-123",
            allowed=False,
            violations=violations,
            latency_ms=200,
            bundle_version="1.0.0",
            evaluated_rules=["TEST_001"],
        )

        assert result.safe is False
        assert result.blocked is True
        assert result.violation_count == 1
        assert result.reason == "Test violation"

    def test_compliance_result_safe_case(self):
        """Test ComplianceResult for safe content."""
        result = ComplianceResult(
            event_id="safe-test",
            allowed=True,
            violations=[],
            latency_ms=100,
            bundle_version="1.0.0",
            evaluated_rules=[],
        )

        assert result.safe is True
        assert result.blocked is False
        assert result.violation_count == 0
        assert result.reason is None

    def test_severity_level_enum(self):
        """Test SeverityLevel enum values."""
        assert SeverityLevel.LOW == "low"
        assert SeverityLevel.MEDIUM == "medium"
        assert SeverityLevel.HIGH == "high"
        assert SeverityLevel.CRITICAL == "critical"

    def test_direction_type_enum(self):
        """Test DirectionType enum values."""
        assert DirectionType.PROMPT == "prompt"
        assert DirectionType.OUTPUT == "output"


class TestSDKAPIKeySecurity:
    """Test SDK API key handling security."""

    def test_get_api_key_only_uses_complyedge_env(self):
        """get_api_key() must only read COMPLYEDGE_API_KEY, never OPENAI_API_KEY."""

        with patch.dict(
            os.environ,
            {"COMPLYEDGE_API_KEY": "ce_test_123", "OPENAI_API_KEY": "sk-xxx"},
        ):
            from complyedge import get_api_key

            assert get_api_key() == "ce_test_123"

    def test_get_api_key_no_openai_fallback(self):
        """get_api_key() must NOT fall back to OPENAI_API_KEY."""
        with patch.dict(
            os.environ,
            {"OPENAI_API_KEY": "sk-secret"},
            clear=False,
        ):
            env = os.environ.copy()
            env.pop("COMPLYEDGE_API_KEY", None)
            with patch.dict(os.environ, env, clear=True):
                from complyedge import get_api_key

                assert get_api_key() is None

    def test_get_api_key_source_code_no_openai(self):
        """Source code of get_api_key must not reference OPENAI_API_KEY."""
        import inspect

        from complyedge import get_api_key

        source = inspect.getsource(get_api_key)
        assert "OPENAI_API_KEY" not in source


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
