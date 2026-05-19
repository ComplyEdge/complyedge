"""
LIVE — Requires COMPLYEDGE_API_KEY.
Validates the API response shape and enforcement behaviour against published claims.

Claims verified:
  - Response fields: allowed, violations[], bundle_version, engine_path,
    latency_ms, opa_latency_ms, audit_logged
  - Violation fields: rule_id, rule_description, severity, confidence, text_excerpt
  - Social-scoring prompt → allowed=False, rule_id="rego-art5-1c-001"
  - severity="critical", confidence=1.0
  - rule_description starts with "Regulation (EU) 2024/1689, Article 5(1)(c)"
  - bundle_version="opa-rego-v1", engine_path="opa"
  - audit_logged=True
  - Safe prompt → allowed=True, violations=[]
"""
from __future__ import annotations

import pytest

SOCIAL_SCORING_TEXT = (
    "We use social credit scoring to evaluate loan applicants in the EU "
    "and assign them a social score that determines their access to financial services."
)
SAFE_TEXT = "Hello, I am an AI assistant. How can I help you today?"

# agent_id is a required field on ComplianceCheckRequest (pydantic Field(...))
AGENT_ID = "acceptance-test"


@pytest.fixture(scope="module")
def violation_response(live_session, api_base_url):
    """Single live call with a clear Article 5(1)(c) violation prompt."""
    resp = live_session.post(
        f"{api_base_url}/v1/check",
        json={
            "text": SOCIAL_SCORING_TEXT,
            "agent_id": AGENT_ID,
            "jurisdiction": "EU",
            "context": {"system_type": "financial_services"},
        },
    )
    assert resp.status_code == 200, (
        f"Expected 200, got {resp.status_code}: {resp.text[:300]}"
    )
    return resp.json()


@pytest.fixture(scope="module")
def safe_response(live_session, api_base_url):
    """Single live call with a benign prompt."""
    resp = live_session.post(
        f"{api_base_url}/v1/check",
        json={
            "text": SAFE_TEXT,
            "agent_id": AGENT_ID,
            "jurisdiction": "EU",
            "context": {"system_type": "customer_support"},
        },
    )
    assert resp.status_code == 200, (
        f"Expected 200, got {resp.status_code}: {resp.text[:300]}"
    )
    return resp.json()


class TestTopLevelFields:
    """Validates the top-level fields shown in the HN post JSON sample."""

    def test_has_event_id(self, violation_response):
        # event_id is a required field in ComplianceCheckResponse — unique per check
        assert "event_id" in violation_response, "Response missing event_id field"
        assert violation_response["event_id"], "event_id must be a non-empty string"

    def test_has_allowed_field(self, violation_response):
        assert "allowed" in violation_response

    def test_has_violations_list(self, violation_response):
        assert "violations" in violation_response
        assert isinstance(violation_response["violations"], list)

    def test_has_bundle_version(self, violation_response):
        # Claim: "bundle_version": "opa-rego-v1"
        assert violation_response.get("bundle_version") == "opa-rego-v1"

    def test_has_engine_path_opa(self, violation_response):
        # Claim: "engine_path": "opa"
        assert violation_response.get("engine_path") == "opa"

    def test_has_latency_ms(self, violation_response):
        # Claim: "latency_ms": 53 (exact value varies; field must exist and be positive)
        assert "latency_ms" in violation_response
        assert violation_response["latency_ms"] > 0

    def test_has_opa_latency_ms(self, violation_response):
        # Claim: "opa_latency_ms": 48.77 — separate OPA engine timing field
        assert "opa_latency_ms" in violation_response, (
            "Expected opa_latency_ms field in response (shown in HN post JSON sample)"
        )
        assert violation_response["opa_latency_ms"] > 0

    def test_has_audit_logged_true(self, violation_response):
        # Claim: "audit_logged": true
        assert violation_response.get("audit_logged") is True


class TestViolationFields:
    """Validates violation object fields shown in the HN post JSON sample."""

    @pytest.fixture(scope="class")
    def violation(self, violation_response):
        violations = violation_response.get("violations", [])
        assert violations, "Expected at least one violation for the social-scoring prompt"
        return violations[0]

    def test_violation_rule_id(self, violation):
        # Claim: "rule_id": "rego-art5-1c-001"
        assert violation.get("rule_id") == "rego-art5-1c-001", (
            f"Expected rule_id=rego-art5-1c-001, got {violation.get('rule_id')}"
        )

    def test_violation_rule_description_starts_with_citation(self, violation):
        # Claim: "rule_description": "Regulation (EU) 2024/1689, Article 5(1)(c)..."
        desc = violation.get("rule_description", "")
        assert desc.startswith("Regulation (EU) 2024/1689, Article 5(1)(c)"), (
            f"rule_description should start with the EU AI Act citation; got: {desc[:80]}"
        )

    def test_violation_severity_is_critical(self, violation):
        # Claim: "severity": "critical"
        assert violation.get("severity") == "critical"

    def test_violation_confidence_is_1(self, violation):
        # Claim: "confidence": 1.0
        assert violation.get("confidence") == 1.0, (
            f"Expected confidence=1.0, got {violation.get('confidence')}"
        )

    def test_violation_text_excerpt_is_present(self, violation):
        # Claim: "text_excerpt" is a non-empty string drawn from the input text
        excerpt = violation.get("text_excerpt", "")
        assert excerpt, "Expected a non-empty text_excerpt in the violation"
        # The excerpt must be a substring of (or fully overlap with) the submitted text
        assert excerpt.lower() in SOCIAL_SCORING_TEXT.lower() or any(
            word in SOCIAL_SCORING_TEXT.lower()
            for word in excerpt.lower().split()
            if len(word) > 4
        ), (
            f"text_excerpt does not appear to come from the submitted input.\n"
            f"  excerpt: {excerpt!r}\n"
            f"  input:   {SOCIAL_SCORING_TEXT!r}"
        )


class TestHealthEndpoint:
    """
    Blog claim: "The live version string is exposed at /health for anyone who
    wants to verify."
    """

    def test_health_returns_200_and_healthy(self, live_session, api_base_url):
        resp = live_session.get(f"{api_base_url}/health")
        assert resp.status_code == 200, (
            f"Expected 200 from /health, got {resp.status_code}: {resp.text[:200]}"
        )
        assert resp.json().get("status") == "healthy"

    def test_health_reports_opa_service(self, live_session, api_base_url):
        # Blog: OPA daemon is the enforcement engine — /health must expose its status
        resp = live_session.get(f"{api_base_url}/health")
        services = resp.json().get("services", {})
        assert "opa" in services, (
            f"Expected 'opa' key in /health services; got: {list(services.keys())}"
        )


class TestEnforcementBehaviour:
    """End-to-end: block / allow decisions for known inputs."""

    def test_social_scoring_is_blocked(self, violation_response):
        # Claim: social-scoring prompt → allowed=False
        assert violation_response["allowed"] is False, (
            "Social-scoring prompt should be blocked (allowed=False)"
        )

    def test_safe_prompt_is_allowed(self, safe_response):
        # Claim: benign prompt → allowed=True
        assert safe_response["allowed"] is True, (
            "Safe prompt should be allowed (allowed=True)"
        )

    def test_safe_prompt_has_no_violations(self, safe_response):
        # Claim: benign prompt → violations=[]
        assert safe_response.get("violations") == [], (
            f"Safe prompt should have no violations; got {safe_response.get('violations')}"
        )
