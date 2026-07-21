"""
Validates @compliance_check decorator behaviour end-to-end.

Offline (no API key needed):
  - COMPLYEDGE_ENABLED=false → decorator passes through without checking (fail-open)
  - No API key in env → decorator passes through without checking (fail-open)

Live (requires COMPLYEDGE_API_KEY):
  - Safe prompt passes through; decorated function returns its result
  - Article 5 violation raises ComplianceError
  - ComplianceError message contains the rule_id (rego-art5-1c-001)
  - Default decorator behaviour (API key set, no ENABLED=false) → blocks violations

Claims verified:
  - "@compliance_check decorator blocks by default when COMPLYEDGE_API_KEY is set"
  - "Set COMPLYEDGE_ENABLED=false to disable without removing the key (e.g. in CI)"
  - "Raises ComplianceError on violation"
  - "No API key → fails open (safe for environments without a key)"
"""
from __future__ import annotations

import pytest
from complyedge import ComplianceError

# conftest.py prepends sdks/python to sys.path so this always imports
# the local SDK source, not any system-installed copy.
from complyedge.decorators import compliance_check

SAFE_INPUT = "Hello, I am an AI assistant. How can I help you today?"
VIOLATION_INPUT = (
    "We use social credit scoring to evaluate loan applicants in the EU "
    "and assign them a social score that determines their access to financial services."
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_agent(text_to_return: str = "ok"):
    """Factory: returns a decorated agent function that echoes its input."""

    @compliance_check()
    def agent(user_input: str) -> str:
        return text_to_return

    return agent


# ---------------------------------------------------------------------------
# Offline tests — no API key needed
# ---------------------------------------------------------------------------


class TestDecoratorFailOpen:
    """Decorator must fail-open when it cannot check compliance."""

    def test_fail_open_when_enabled_is_false(self, monkeypatch):
        # Claim: "set COMPLYEDGE_ENABLED=false to disable without removing the key"
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "test-key-placeholder")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "false")

        agent = _make_agent("result-value")
        result = agent(VIOLATION_INPUT)
        assert (
            result == "result-value"
        ), "Decorator with COMPLYEDGE_ENABLED=false should pass through without blocking"

    def test_fail_open_when_no_api_key(self, monkeypatch):
        # Claim: "No API key → fail open"
        monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
        monkeypatch.delenv("COMPLYEDGE_ENABLED", raising=False)

        agent = _make_agent("result-value")
        result = agent(VIOLATION_INPUT)
        assert (
            result == "result-value"
        ), "Decorator with no API key should pass through without blocking"


# ---------------------------------------------------------------------------
# Live tests — require COMPLYEDGE_API_KEY
# ---------------------------------------------------------------------------


class TestDecoratorLive:
    """End-to-end decorator behaviour against the real API."""

    @pytest.fixture(autouse=True)
    def ensure_api_key(self, api_key, monkeypatch):
        """Set COMPLYEDGE_API_KEY env var for the duration of each test."""
        monkeypatch.setenv("COMPLYEDGE_API_KEY", api_key)
        # Ensure COMPLYEDGE_ENABLED is not set to false
        monkeypatch.delenv("COMPLYEDGE_ENABLED", raising=False)

    def test_safe_input_passes_through(self, api_base_url, monkeypatch):
        # Claim: safe prompts are allowed; function returns its result normally
        monkeypatch.setenv("COMPLYEDGE_API_URL", api_base_url)

        @compliance_check()
        def agent(user_input: str) -> str:
            return "safe-result"

        result = agent(SAFE_INPUT)
        assert (
            result == "safe-result"
        ), "Decorated function should return its result for a safe input"

    def test_violation_raises_compliance_error(self, api_base_url, monkeypatch):
        # Claim: "@compliance_check raises ComplianceError on violation"
        monkeypatch.setenv("COMPLYEDGE_API_URL", api_base_url)

        @compliance_check()
        def agent(user_input: str) -> str:
            return "should-not-reach"

        with pytest.raises(ComplianceError):
            agent(VIOLATION_INPUT)

    def test_compliance_error_contains_rule_id(self, api_base_url, monkeypatch):
        # Claim: ComplianceError message contains the specific rule that fired
        monkeypatch.setenv("COMPLYEDGE_API_URL", api_base_url)

        @compliance_check()
        def agent(user_input: str) -> str:
            return "should-not-reach"

        with pytest.raises(ComplianceError) as exc_info:
            agent(VIOLATION_INPUT)

        error_text = str(exc_info.value)
        assert (
            "rego-art5-1c-001" in error_text
        ), f"ComplianceError should cite the rule_id; got: {error_text[:200]}"

    def test_enabled_by_default_with_only_api_key_set(self, api_base_url, monkeypatch):
        # Claim: "decorator is enabled by default when COMPLYEDGE_API_KEY is set"
        # Only COMPLYEDGE_API_KEY is set; COMPLYEDGE_ENABLED is absent entirely.
        # Article 5 input must still be blocked — no explicit opt-in required.
        monkeypatch.setenv("COMPLYEDGE_API_URL", api_base_url)
        # ensure_api_key already removed COMPLYEDGE_ENABLED for this test class

        @compliance_check()
        def agent(user_input: str) -> str:
            return "should-not-reach"

        with pytest.raises(ComplianceError):
            agent(VIOLATION_INPUT)
