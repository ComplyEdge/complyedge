"""
Validates @compliance_check decorator fail-open behaviour (offline only).

  - COMPLYEDGE_ENABLED=false → decorator passes through without checking
  - No API key in env → decorator passes through without checking

No live API calls: those wrote audit rows on the shared test tenant.
"""
from __future__ import annotations

# conftest.py prepends sdks/python to sys.path so this always imports
# the local SDK source, not any system-installed copy.
from complyedge.decorators import compliance_check

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

