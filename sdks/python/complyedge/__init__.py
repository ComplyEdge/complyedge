"""
ComplyEdge Python SDK

A Python client library for the ComplyEdge Compliance API.
Provides both simple and advanced interfaces for AI agent compliance checking.

Basic Usage (Simple Interface):
    from complyedge import ComplyEdge, is_safe, check

    # Option 1: Class instance
    ce = ComplyEdge(api_key="your-key")
    if ce.is_safe("Some text"):
        print("Safe to use")

    # Option 2: Global functions
    if is_safe("Some text", api_key="your-key"):
        print("Safe to use")

    result = check("Some text", api_key="your-key")
    print(f"Safe: {result.safe}, Reason: {result.reason}")

Advanced Usage (Full Interface):
    from complyedge import ComplyEdgeClient, AsyncComplyEdgeClient

    # Synchronous client
    with ComplyEdgeClient(api_key="your-key") as client:
        result = client.check_compliance(
            text="Your AI agent output text",
            agent_id="my-bot",
            jurisdiction="EU"
        )

    # Asynchronous client
    async with AsyncComplyEdgeClient(api_key="your-key") as client:
        result = await client.check_compliance(
            text="Your AI agent output text",
            agent_id="my-bot"
        )
"""

import os
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, Optional

import httpx
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)

__version__ = "0.2.0"

# Decorator functionality will be imported at the end to avoid circular imports

# =============================================================================
# CORE DATA MODELS
# =============================================================================


class SeverityLevel(str, Enum):
    """Severity levels for compliance violations."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class DirectionType(str, Enum):
    """Direction of text flow for compliance checking."""

    PROMPT = "prompt"  # Input from user to AI
    OUTPUT = "output"  # Output from AI to user


@dataclass
class ComplianceViolation:
    """A compliance violation detected in text."""

    rule_id: str
    rule_description: str
    severity: SeverityLevel
    reason: str
    confidence: float
    text_excerpt: Optional[str] = None


@dataclass
class ComplianceResult:
    """Result of a compliance check."""

    event_id: str
    allowed: bool
    violations: List[ComplianceViolation]
    latency_ms: int
    bundle_version: str
    evaluated_rules: List[str]

    @property
    def safe(self) -> bool:
        """True if text is safe (no violations)."""
        return self.allowed

    @property
    def blocked(self) -> bool:
        """True if text is blocked (has violations)."""
        return not self.allowed

    @property
    def violation_count(self) -> int:
        """Number of violations found."""
        return len(self.violations)

    @property
    def reason(self) -> Optional[str]:
        """Human-readable reason for the decision."""
        if self.allowed:
            return None
        if self.violations:
            return self.violations[0].rule_description
        return "Blocked by compliance system"


class ComplianceError(Exception):
    """Exception raised when compliance checking fails."""

    def __init__(
        self,
        message: str,
        violations: Optional[List[ComplianceViolation]] = None,
        event_id: Optional[str] = None,
    ):
        super().__init__(message)
        self.violations = violations or []
        self.event_id = event_id


# =============================================================================
# SIMPLE INTERFACE (recommended for most users)
# =============================================================================


class ComplyEdge:
    """
    Simple synchronous client for ComplyEdge Compliance API.

    This is the recommended interface for most users.

    Example:
        ce = ComplyEdge(api_key="your-key")

        if ce.is_safe("Some text"):
            print("Safe to use")
        else:
            result = ce.check("Some text")
            print(f"Blocked: {result.reason}")
    """

    def __init__(
        self,
        api_key: str,
        agent_id: str = "default",
        jurisdiction: Optional[str] = None,
        base_url: str = "https://api.complyedge.io",
    ):
        """
        Initialize ComplyEdge client.

        Args:
            api_key: Your ComplyEdge API key
            agent_id: Default agent identifier
            jurisdiction: Regulatory jurisdiction (e.g., 'EU', 'US')
            base_url: API base URL
        """
        self.api_key = api_key
        self.agent_id = agent_id
        self.jurisdiction = jurisdiction
        self.base_url = base_url.rstrip("/")

        self._client = httpx.Client(
            base_url=self.base_url,
            timeout=300,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"complyedge-python-sdk/{__version__}",
            },
        )

    def is_safe(self, text: str) -> bool:
        """
        Check if text is safe to use (no compliance violations).

        Args:
            text: Text to check

        Returns:
            True if safe, False if blocked

        Example:
            if ce.is_safe("Hello world"):
                print("Safe to use")
        """
        try:
            result = self.check(text)
            return result.safe
        except Exception:
            # Conservative: assume unsafe if check fails
            return False

    def check(
        self,
        text: str,
        agent_id: Optional[str] = None,
        jurisdiction: Optional[str] = None,
    ) -> ComplianceResult:
        """
        Check text for compliance violations.

        Args:
            text: Text to check
            agent_id: Agent identifier (uses default if not provided)
            jurisdiction: Regulatory jurisdiction (uses default if not provided)

        Returns:
            ComplianceResult with detailed information

        Example:
            result = ce.check("Some text")
            if result.safe:
                print("Safe")
            else:
                print(f"Blocked: {result.reason}")
        """
        request_data = {
            "input_text": text,  # Enhanced engine uses input_text
            "context": {
                "user_jurisdiction": jurisdiction or self.jurisdiction,
                "platform_type": "sdk",
            },
            "agent_id": agent_id or self.agent_id,
        }

        try:
            response = self._client.post("/v1/sensitivity/detect", json=request_data)
            response.raise_for_status()
            data = response.json()

            # Enhanced engine returns detections instead of violations
            violations = []
            detections = data.get("detections", [])

            for detection in detections:
                # Use regulation field as description if it contains violation details
                regulation_text = detection.get("regulation", "UNKNOWN")
                if "violation detected" in regulation_text.lower():
                    # Enhanced engine provides specific violation descriptions
                    rule_description = regulation_text
                    rule_id = detection.get("data_type", "UNKNOWN")
                else:
                    # Legacy generic descriptions
                    rule_description = (
                        f"Sensitive {detection.get('data_type', 'data')} detected"
                    )
                    rule_id = regulation_text

                violation = ComplianceViolation(
                    rule_id=rule_id,
                    rule_description=rule_description,
                    severity=SeverityLevel(
                        detection.get("risk_level", "medium").lower()
                    ),
                    reason=detection.get("excerpt", "Compliance violation"),
                    confidence=detection.get("confidence", 0.8),
                    text_excerpt=detection.get("excerpt"),
                )
                violations.append(violation)

            # Determine if allowed based on intervention
            intervention = data.get("intervention")
            action = intervention.get("action", "").upper() if intervention else ""
            blocked = intervention is not None and action in [
                "BLOCK",
                "WARN_AND_BLOCK",
            ]

            return ComplianceResult(
                event_id=data["event_id"],
                allowed=not blocked,
                violations=violations,
                latency_ms=data.get("processing_time_ms", 0),
                bundle_version="enhanced_v1",
                evaluated_rules=data.get("applicable_regulations", []),
            )

        except httpx.HTTPStatusError as e:
            try:
                error_data = e.response.json()
                error_detail = error_data.get("detail", str(e))
            except Exception:
                error_detail = str(e)

            raise ComplianceError(
                f"API error ({e.response.status_code}): {error_detail}"
            )

        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}")

    def close(self):
        """Close the HTTP client."""
        self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


# Global convenience functions
def is_safe(
    text: str,
    api_key: str,
    agent_id: str = "default",
    jurisdiction: Optional[str] = None,
    base_url: str = "https://api.complyedge.io",
) -> bool:
    """
    Global convenience function to check if text is safe.

    Args:
        text: Text to check
        api_key: ComplyEdge API key
        agent_id: Agent identifier
        jurisdiction: Regulatory jurisdiction
        base_url: API base URL

    Returns:
        True if safe, False if blocked

    Example:
        from complyedge import is_safe

        if is_safe("Hello world", api_key="your-key"):
            print("Safe to use")
    """
    client = ComplyEdge(
        api_key=api_key, agent_id=agent_id, jurisdiction=jurisdiction, base_url=base_url
    )
    try:
        return client.is_safe(text)
    finally:
        client.close()


def check(
    text: str,
    api_key: str,
    agent_id: str = "default",
    jurisdiction: Optional[str] = None,
    base_url: str = "https://api.complyedge.io",
) -> ComplianceResult:
    """
    Global convenience function to check text compliance.

    Args:
        text: Text to check
        api_key: ComplyEdge API key
        agent_id: Agent identifier
        jurisdiction: Regulatory jurisdiction
        base_url: API base URL

    Returns:
        ComplianceResult with detailed information

    Example:
        from complyedge import check

        result = check("Some text", api_key="your-key")
        if result.safe:
            print("Safe")
        else:
            print(f"Blocked: {result.reason}")
    """
    client = ComplyEdge(
        api_key=api_key, agent_id=agent_id, jurisdiction=jurisdiction, base_url=base_url
    )
    try:
        return client.check(text)
    finally:
        client.close()


# =============================================================================
# ADVANCED INTERFACE (for power users and backward compatibility)
# =============================================================================


class ComplyEdgeClient:
    """
    Synchronous ComplyEdge client for compliance checking.

    This client provides a simple, synchronous interface to the ComplyEdge API.
    Perfect for quick integrations, testing, and scenarios where you don't need
    async/await patterns.

    Example:
        Basic usage:

        ```python
        from complyedge import ComplyEdgeClient

        client = ComplyEdgeClient(api_key="your-api-key")

        result = client.check_compliance(
            text="We expect revenue to increase by 25% next quarter",
            agent_id="financial-agent"
        )

        if result.allowed:
            print("Text is compliant")
        else:
            print(f"Found {len(result.violations)} violations")
        ```

        With context manager:

        ```python
        with ComplyEdgeClient(api_key="your-api-key") as client:
            result = client.check_compliance(
                text="Check this message",
                agent_id="my-agent"
            )
        ```

        except ComplianceError as e:
            print(f"Compliance check failed: {e}")
    """

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.complyedge.io",
        timeout: int = 300,
        max_retries: int = 3,
        verify_ssl: bool = True,
    ):
        """
        Initialize the ComplyEdge client.

        Args:
            api_key: Your ComplyEdge API key
            base_url: Base URL for the ComplyEdge API
            timeout: Request timeout in seconds
            max_retries: Maximum number of retry attempts
            verify_ssl: Whether to verify SSL certificates
        """
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

        self.client = httpx.Client(
            base_url=self.base_url,
            timeout=timeout,
            verify=verify_ssl,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"complyedge-python-sdk/{__version__}",
            },
        )
        self.max_retries = max_retries

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def close(self):
        """Close the HTTP client."""
        self.client.close()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.HTTPStatusError)),
    )
    def check_compliance(
        self,
        text: str,
        agent_id: str,
        jurisdiction: Optional[str] = None,
        direction: DirectionType = DirectionType.OUTPUT,
        context: Optional[Dict[str, Any]] = None,
        use_semantic_fallback: bool = True,
        raise_on_violation: bool = False,
    ) -> ComplianceResult:
        """
        Check text for compliance violations.

        Args:
            text: Text to evaluate for compliance
            agent_id: Identifier of the AI agent
            jurisdiction: Regulatory jurisdiction (e.g., 'EU', 'US', 'US-CA')
            direction: Whether this is a prompt or output
            context: Additional context for evaluation
            use_semantic_fallback: Use LLM-based evaluation for ambiguous cases
            raise_on_violation: Raise ComplianceError if violations are found

        Returns:
            ComplianceResult with decision and any violations

        Raises:
            ComplianceError: If compliance check fails or violations found
                           (when raise_on_violation=True)
        """
        try:
            # Build context for enhanced engine
            enhanced_context = {
                "user_jurisdiction": jurisdiction,
                "platform_type": "sdk",
                "user_role": context.get("user_role", "user") if context else "user",
            }
            if context:
                enhanced_context.update(context)

            request_data = {
                "input_text": text,  # Enhanced engine uses input_text
                "context": enhanced_context,
                "agent_id": agent_id,
            }

            response = self.client.post("/v1/sensitivity/detect", json=request_data)
            response.raise_for_status()

            data = response.json()

            # Enhanced engine returns detections instead of violations
            violations = []
            detections = data.get("detections", [])

            for detection in detections:
                # Use regulation field as description if it contains violation details
                regulation_text = detection.get("regulation", "UNKNOWN")
                if "violation detected" in regulation_text.lower():
                    # Enhanced engine provides specific violation descriptions
                    rule_description = regulation_text
                    rule_id = detection.get("data_type", "UNKNOWN")
                else:
                    # Legacy generic descriptions
                    rule_description = (
                        f"Sensitive {detection.get('data_type', 'data')} detected"
                    )
                    rule_id = regulation_text

                violation = ComplianceViolation(
                    rule_id=rule_id,
                    rule_description=rule_description,
                    severity=SeverityLevel(
                        detection.get("risk_level", "medium").lower()
                    ),
                    reason=detection.get("excerpt", "Compliance violation"),
                    confidence=detection.get("confidence", 0.8),
                    text_excerpt=detection.get("excerpt"),
                )
                violations.append(violation)

            # Determine if allowed based on intervention
            intervention = data.get("intervention")
            blocked = intervention is not None and intervention.get(
                "action", ""
            ).upper() in [
                "BLOCK",
                "WARN_AND_BLOCK",
            ]

            result = ComplianceResult(
                event_id=data["event_id"],
                allowed=not blocked,
                violations=violations,
                latency_ms=data.get("processing_time_ms", 0),
                bundle_version="enhanced_v1",
                evaluated_rules=data.get("applicable_regulations", []),
            )

            # Optionally raise on violations
            if raise_on_violation and not result.allowed:
                raise ComplianceError(
                    f"Compliance violations detected: "
                    f"{len(violations)} rules violated",
                    violations=violations,
                    event_id=result.event_id,
                )

            return result

        except httpx.HTTPStatusError as e:
            error_detail = "Unknown error"
            try:
                error_data = e.response.json()
                error_detail = error_data.get("detail", str(e))
            except Exception:
                pass

            raise ComplianceError(
                f"API error ({e.response.status_code}): {error_detail}"
            )

        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}")

    def get_rules_info(self) -> Dict[str, Any]:
        """Get information about the current rule bundle."""
        try:
            response = self.client.get("/v1/rules/info")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get rules info: {e}")

    def get_metrics(self) -> Dict[str, Any]:
        """Get compliance metrics for your tenant."""
        try:
            response = self.client.get("/v1/metrics")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get metrics: {e}")


class AsyncComplyEdgeClient:
    """
    Async client for ComplyEdge Compliance API.

    This is the advanced async interface for power users.
    For simple use cases, use the ComplyEdge class instead.

    Example:
        async with AsyncComplyEdgeClient(api_key="your-key") as client:
            result = await client.check_compliance(
                text="Your AI agent output text",
                agent_id="my-bot"
            )

            if result.allowed:
                print("Text is compliant")
            else:
                print(f"Found {len(result.violations)} violations")
    """

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.complyedge.io",
        timeout: int = 300,
        max_retries: int = 3,
        verify_ssl: bool = True,
    ):
        """Initialize the async ComplyEdge client."""
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=timeout,
            verify=verify_ssl,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"complyedge-python-sdk/{__version__}",
            },
        )
        self.max_retries = max_retries

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.HTTPStatusError)),
    )
    async def check_compliance(
        self,
        text: str,
        agent_id: str,
        jurisdiction: Optional[str] = None,
        direction: DirectionType = DirectionType.OUTPUT,
        context: Optional[Dict[str, Any]] = None,
        use_semantic_fallback: bool = True,
        raise_on_violation: bool = False,
    ) -> ComplianceResult:
        """Async version of check_compliance."""
        try:
            # Build context for enhanced engine
            enhanced_context = {
                "user_jurisdiction": jurisdiction,
                "platform_type": "sdk",
                "user_role": context.get("user_role", "user") if context else "user",
            }
            if context:
                enhanced_context.update(context)

            request_data = {
                "input_text": text,  # Enhanced engine uses input_text
                "context": enhanced_context,
                "agent_id": agent_id,
            }

            response = await self.client.post(
                "/v1/sensitivity/detect", json=request_data
            )
            response.raise_for_status()

            data = response.json()

            # Enhanced engine returns detections instead of violations
            violations = []
            detections = data.get("detections", [])

            for detection in detections:
                # Use regulation field as description if it contains violation details
                regulation_text = detection.get("regulation", "UNKNOWN")
                if "violation detected" in regulation_text.lower():
                    # Enhanced engine provides specific violation descriptions
                    rule_description = regulation_text
                    rule_id = detection.get("data_type", "UNKNOWN")
                else:
                    # Legacy generic descriptions
                    rule_description = (
                        f"Sensitive {detection.get('data_type', 'data')} detected"
                    )
                    rule_id = regulation_text

                violation = ComplianceViolation(
                    rule_id=rule_id,
                    rule_description=rule_description,
                    severity=SeverityLevel(
                        detection.get("risk_level", "medium").lower()
                    ),
                    reason=detection.get("excerpt", "Compliance violation"),
                    confidence=detection.get("confidence", 0.8),
                    text_excerpt=detection.get("excerpt"),
                )
                violations.append(violation)

            # Determine if allowed based on intervention
            intervention = data.get("intervention")
            blocked = intervention is not None and intervention.get(
                "action", ""
            ).upper() in [
                "BLOCK",
                "WARN_AND_BLOCK",
            ]

            result = ComplianceResult(
                event_id=data["event_id"],
                allowed=not blocked,
                violations=violations,
                latency_ms=data.get("processing_time_ms", 0),
                bundle_version="enhanced_v1",
                evaluated_rules=data.get("applicable_regulations", []),
            )

            if raise_on_violation and not result.allowed:
                raise ComplianceError(
                    f"Compliance violations detected: "
                    f"{len(violations)} rules violated",
                    violations=violations,
                    event_id=result.event_id,
                )

            return result

        except httpx.HTTPStatusError as e:
            error_detail = "Unknown error"
            try:
                error_data = e.response.json()
                error_detail = error_data.get("detail", str(e))
            except Exception:
                pass

            raise ComplianceError(
                f"API error ({e.response.status_code}): {error_detail}"
            )

        except httpx.RequestError as e:
            raise ComplianceError(f"Request failed: {str(e)}")

    async def get_rules_info(self) -> Dict[str, Any]:
        """Get information about the current rule bundle."""
        try:
            response = await self.client.get("/v1/rules/info")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get rules info: {e}")

    async def get_metrics(self) -> Dict[str, Any]:
        """Get compliance metrics for your tenant."""
        try:
            response = await self.client.get("/v1/metrics")
            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            raise ComplianceError(f"Failed to get metrics: {e}")


# =============================================================================
# BACKWARD COMPATIBILITY
# =============================================================================


def check_compliance(
    text: str, agent_id: str, api_key: str, jurisdiction: Optional[str] = None, **kwargs
) -> ComplianceResult:
    """
    Quick compliance check without creating a client instance.

    DEPRECATED: Use ComplyEdge class or global check() function instead.

    Args:
        text: Text to check
        agent_id: Agent identifier
        api_key: ComplyEdge API key
        jurisdiction: Regulatory jurisdiction
        **kwargs: Additional arguments passed to check_compliance

    Returns:
        ComplianceResult
    """
    with ComplyEdgeClient(api_key=api_key) as client:
        return client.check_compliance(
            text=text, agent_id=agent_id, jurisdiction=jurisdiction, **kwargs
        )


# =============================================================================
# AUTO-CONFIGURATION FROM ENVIRONMENT
# =============================================================================


def get_api_key() -> Optional[str]:
    """Get API key from environment variables."""
    return os.environ.get("COMPLYEDGE_API_KEY") or os.environ.get("OPENAI_API_KEY")


# Convenience instance with environment configuration
if get_api_key():
    default_client = ComplyEdge(api_key=get_api_key())

    def safe(text: str) -> bool:
        """Check if text is safe using environment-configured client."""
        return default_client.is_safe(text)

    def compliance_check(text: str) -> ComplianceResult:
        """Check compliance using environment-configured client."""
        return default_client.check(text)

else:
    default_client = None
    safe = None
    compliance_check = None


# Export public API
__all__ = [
    # Simple interface (recommended)
    "ComplyEdge",
    "is_safe",
    "check",
    # Advanced interface
    "ComplyEdgeClient",
    "AsyncComplyEdgeClient",
    # Data models
    "ComplianceResult",
    "ComplianceViolation",
    "ComplianceError",
    "SeverityLevel",
    "DirectionType",
    # Decorator interface
    "compliance_check",
    "ComplianceConfig", 
    "default_violation_handler",
    # Backward compatibility
    "check_compliance",
    # Environment helpers
    "get_api_key",
    "safe",
    # Agent integration module (import separately)
    # from complyedge.agents import create_compliance_guardrail
]

# Import decorator functionality after all classes are defined to avoid circular imports
from .decorators import compliance_check, ComplianceConfig, default_violation_handler
