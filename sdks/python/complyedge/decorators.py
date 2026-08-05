"""
ComplyEdge Compliance Decorator

Provides Pythonic decorator syntax for automatic compliance checking
in AI agent functions, supporting both input and output validation.
"""

# PEP 604 unions (str | None) are evaluated at def time, so this module
# raised TypeError on import under Python 3.9 while pyproject, the PyPI
# classifiers and the quick-start all advertised 3.9 support. Reproduced
# on 3.9.19 at __init__.py:92. Do not remove without dropping 3.9.
from __future__ import annotations

import functools
import logging
import os
from collections.abc import Callable
from typing import TYPE_CHECKING, Any

# Resolve default base URL from environment
_DEFAULT_BASE_URL = os.getenv("COMPLYEDGE_API_URL")

if TYPE_CHECKING:
    from . import ComplianceResult


# Import from existing SDK components
# Note: Models and clients are defined in __init__.py
def _import_models():
    """Import models after module initialization to avoid circular imports."""
    from . import ComplianceError, ComplianceResult, ComplyEdge

    return ComplianceResult, ComplyEdge, ComplianceError


logger = logging.getLogger(__name__)


class ComplianceUnavailableError(RuntimeError):
    """The compliance API could not be reached and fail_mode is "closed".

    Raised instead of letting an unchecked call through. Callers who prefer
    availability over enforcement set fail_mode="open".
    """


_FAIL_MODES = frozenset({"open", "closed"})


def _validate_fail_mode(mode: str) -> str:
    if mode not in _FAIL_MODES:
        raise ValueError(
            f"fail_mode must be one of {sorted(_FAIL_MODES)}, got {mode!r}"
        )
    return mode


class ComplianceConfig:
    """
    Configuration object for compliance decorator.

    Provides enterprise-grade configuration for complex compliance scenarios
    including custom violation handlers, conditional enablement, and
    multi-jurisdiction support.
    """

    def __init__(
        self,
        api_key: str | None = None,
        check_input: bool = True,
        check_output: bool = True,
        enable_condition: Callable[[], bool] | None = None,
        violation_handler: Callable[[ComplianceResult, str], Any] | None = None,
        agent_id: str = "default",
        jurisdiction: str | None = None,
        base_url: str | None = _DEFAULT_BASE_URL,
        timeout: int = 300,
        max_retries: int = 3,
        fail_mode: str = "open",
    ):
        """
        Initialize compliance configuration.

        Args:
            api_key: ComplyEdge API key (overrides environment variables)
            check_input: Whether to check function input parameters
            check_output: Whether to check function output/return value
            enable_condition: Callable that returns whether compliance is enabled
            violation_handler: Custom function to handle compliance violations
            agent_id: Identifier for the AI agent
            jurisdiction: Regulatory jurisdiction (US, EU, US-CA, etc.)
            base_url: ComplyEdge API base URL
            timeout: Request timeout in seconds
            max_retries: Maximum retry attempts for API calls
            fail_mode: Behaviour when the ComplyEdge API itself is unreachable
                or errors. "open" lets the wrapped function run unchecked and
                logs the failure; "closed" raises ComplianceUnavailableError so
                an outage cannot silently disable enforcement.

                Default is "open" to preserve existing behaviour, but note the
                trade: with fail_mode="open" an API outage means traffic runs
                UNENFORCED, and nothing in the response distinguishes that from
                a clean pass. Compliance-critical deployments should set
                "closed". This was previously hard-coded open and undocumented,
                while ComplyEdge.is_safe() and the TypeScript client both failed
                closed: three surfaces, three postures, none written down.
        """
        self.api_key = api_key
        self.check_input = check_input
        self.check_output = check_output
        self.enable_condition = enable_condition
        self.violation_handler = violation_handler
        self.agent_id = agent_id
        self.jurisdiction = jurisdiction
        self.base_url = base_url
        self.timeout = timeout
        self.max_retries = max_retries
        self.fail_mode = _validate_fail_mode(fail_mode)


def default_violation_handler(result: ComplianceResult, context: str) -> None:
    """
    Default handler for compliance violations.

    Raises ComplianceError so the caller can catch and handle the block explicitly.
    Enterprise customers can override this with a custom violation handler that
    returns a value instead of raising (e.g., to return a safe fallback response).

    Args:
        result: ComplianceResult containing violation details
        context: Either "input" or "output" indicating where violation occurred

    Raises:
        ComplianceError: Always raised to block the request.
    """
    from . import ComplianceError as _ComplianceError

    violation_count = len(result.violations) if result.violations else 0
    regulations = (
        ", ".join(result.evaluated_rules)
        if result.evaluated_rules
        else "compliance policies"
    )
    raise _ComplianceError(
        f"Request blocked due to compliance violation in {context}. "
        f"Found {violation_count} violation(s) against {regulations}. "
        f"Event ID: {result.event_id}",
        violations=result.violations,
        event_id=result.event_id,
    )


_TRUTHY = frozenset({"1", "true", "t", "yes", "y", "on"})
_FALSY = frozenset({"0", "false", "f", "no", "n", "off"})


def _parse_enabled(raw: str | None, *, var_name: str) -> bool:
    """Interpret the kill-switch env var.

    Previously this was ``raw.lower() == "true"``, so every truthy spelling a
    deployer would reasonably reach for (``1``, ``yes``, ``on``, or ``TRUE``
    with a trailing space) evaluated False and SILENTLY DISABLED compliance
    enforcement. The failure was invisible: the decorator simply stopped
    checking. A value we cannot interpret now raises rather than guessing,
    because guessing wrong means shipping unenforced.
    """
    if raw is None:
        return True
    value = raw.strip().lower()
    if value in _TRUTHY:
        return True
    if value in _FALSY:
        return False
    raise ValueError(
        f"{var_name}={raw!r} is not a recognised boolean. "
        f"Use one of {sorted(_TRUTHY)} to enable or {sorted(_FALSY)} to disable. "
        "Refusing to guess, because guessing wrong disables compliance checks."
    )


def compliance_check(
    input: bool = True,
    output: bool = True,
    api_key_env: str = "COMPLYEDGE_API_KEY",
    enabled_env: str = "COMPLYEDGE_ENABLED",
    agent_id: str = "default",
    jurisdiction: str | None = None,
    config: ComplianceConfig | None = None,
    violation_handler: Callable[[ComplianceResult, str], Any] | None = None,
    base_url: str | None = _DEFAULT_BASE_URL,
):
    """
    Decorator for automatic ComplyEdge compliance checking.

    Provides clean, Pythonic integration of compliance checking into any
    AI agent function. Supports both simple parameter-based configuration
    and complex configuration object patterns.

    Usage Patterns:

        # Simple usage
        @compliance_check(input=True, output=True)
        def my_agent_function(user_input: str) -> str:
            return process_input(user_input)

        # Environment-based configuration
        @compliance_check(
            api_key_env="CUSTOM_API_KEY_VAR",
            enabled_env="CUSTOM_ENABLED_VAR"
        )
        def my_function(text: str) -> str:
            return text.upper()

        # Configuration object pattern
        config = ComplianceConfig(
            api_key=os.getenv("COMPLYEDGE_API_KEY"),
            check_input=True,
            check_output=True,
            enable_condition=lambda: os.getenv("COMPLIANCE_MODE") == "strict",
            violation_handler=custom_violation_handler
        )

        @compliance_check(config=config)
        def enterprise_function(data: str) -> str:
            return process_enterprise_data(data)

    Args:
        input: Whether to check function input parameters for compliance
        output: Whether to check function return value for compliance
        api_key_env: Environment variable name containing ComplyEdge API key
        enabled_env: Environment variable name for opt-out (defaults to enabled when
            COMPLYEDGE_API_KEY is set; set COMPLYEDGE_ENABLED=false to disable without
            removing the key, e.g., in CI)
        agent_id: Default agent identifier for compliance tracking
        jurisdiction: Default regulatory jurisdiction
        config: ComplianceConfig object (overrides individual parameters)
        violation_handler: Custom function to handle compliance violations
        base_url: ComplyEdge API base URL

    Returns:
        Decorated function with automatic compliance checking

    Raises:
        No exceptions - uses graceful degradation on configuration errors
    """

    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            # Configuration resolution: config object takes precedence
            if config:
                check_input = config.check_input
                check_output = config.check_output
                api_key = config.api_key or os.getenv(api_key_env)
                enabled = (
                    config.enable_condition()
                    if config.enable_condition
                    else _parse_enabled(os.getenv(enabled_env), var_name=enabled_env)
                )
                handler = (
                    config.violation_handler
                    or violation_handler
                    or default_violation_handler
                )
                agent = config.agent_id
                juris = config.jurisdiction
                api_base_url = config.base_url
                fail_mode = config.fail_mode
            else:
                check_input = input
                check_output = output
                api_key = os.getenv(api_key_env)
                enabled = _parse_enabled(os.getenv(enabled_env), var_name=enabled_env)
                handler = violation_handler or default_violation_handler
                agent = agent_id
                juris = jurisdiction
                api_base_url = base_url
                fail_mode = _validate_fail_mode(
                    os.getenv("COMPLYEDGE_FAIL_MODE", "open")
                )

            # Graceful degradation: proceed without compliance if disabled or misconfigured
            if not enabled or not api_key:
                logger.warning(
                    "Compliance checking disabled or API key missing - proceeding WITHOUT compliance checks (fail-open)",
                    extra={
                        "enabled": enabled,
                        "api_key_present": bool(api_key),
                        "function_name": func.__name__,
                        "agent_id": agent,
                    },
                )
                return func(*args, **kwargs)

            # Initialize ComplyEdge client with configuration
            # Import classes dynamically to avoid circular import
            ComplianceResult, ComplyEdge, ComplianceError = _import_models()

            ce = ComplyEdge(
                api_key=api_key,
                agent_id=agent,
                jurisdiction=juris,
                base_url=api_base_url,
            )

            try:
                # Input compliance checking
                if check_input and (args or kwargs):
                    # Extract string arguments for compliance checking
                    input_texts = []
                    for _i, arg in enumerate(args):
                        if isinstance(arg, str) and arg.strip():
                            input_texts.append(arg)

                    # Add string keyword arguments
                    for _key, value in kwargs.items():
                        if isinstance(value, str) and value.strip():
                            input_texts.append(value)

                    if input_texts:
                        # Combine all text inputs for comprehensive checking
                        combined_input = " ".join(input_texts)

                        logger.debug(
                            "Performing input compliance check",
                            extra={
                                "function_name": func.__name__,
                                "agent_id": agent,
                                "input_length": len(combined_input),
                                "jurisdiction": juris,
                            },
                        )

                        _input_violation = None
                        try:
                            result = ce.check(combined_input, direction="prompt")
                            if not result.safe:
                                logger.warning(
                                    "Input compliance violation detected",
                                    extra={
                                        "function_name": func.__name__,
                                        "agent_id": agent,
                                        "event_id": result.event_id,
                                        "violation_count": len(result.violations)
                                        if result.violations
                                        else 0,
                                        "regulations": result.evaluated_rules,
                                    },
                                )
                                _input_violation = result
                        except Exception as e:
                            logger.error(
                                "Input compliance check failed - proceeding with caution",
                                extra={
                                    "function_name": func.__name__,
                                    "agent_id": agent,
                                    "error": str(e),
                                },
                            )
                            # fail_mode decides. "open" proceeds unchecked (and
                            # the caller has been told, in ComplianceConfig, that
                            # this means traffic runs unenforced during an
                            # outage); "closed" refuses rather than silently
                            # dropping enforcement.
                            if fail_mode == "closed":
                                raise ComplianceUnavailableError(
                                    "Input compliance check failed and "
                                    "fail_mode='closed'; refusing to run "
                                    f"{func.__name__} unchecked"
                                ) from e
                        if _input_violation is not None:
                            return handler(_input_violation, "input")

                # Execute the original function
                logger.debug(
                    "Executing function with compliance protection",
                    extra={
                        "function_name": func.__name__,
                        "agent_id": agent,
                        "input_checked": check_input,
                        "output_will_check": check_output,
                    },
                )

                response = func(*args, **kwargs)

                # Output compliance checking
                if check_output and isinstance(response, str) and response.strip():
                    logger.debug(
                        "Performing output compliance check",
                        extra={
                            "function_name": func.__name__,
                            "agent_id": agent,
                            "output_length": len(response),
                            "jurisdiction": juris,
                        },
                    )

                    _output_violation = None
                    try:
                        result = ce.check(response)
                        if not result.safe:
                            logger.warning(
                                "Output compliance violation detected",
                                extra={
                                    "function_name": func.__name__,
                                    "agent_id": agent,
                                    "event_id": result.event_id,
                                    "violation_count": len(result.violations)
                                    if result.violations
                                    else 0,
                                    "regulations": result.evaluated_rules,
                                },
                            )
                            _output_violation = result
                    except Exception as e:
                        logger.error(
                            "Output compliance check failed - returning original response",
                            extra={
                                "function_name": func.__name__,
                                "agent_id": agent,
                                "error": str(e),
                            },
                        )
                        # Same posture as the input side, see fail_mode.
                        if fail_mode == "closed":
                            raise ComplianceUnavailableError(
                                "Output compliance check failed and "
                                "fail_mode='closed'; refusing to return "
                                f"unchecked output from {func.__name__}"
                            ) from e
                    if _output_violation is not None:
                        return handler(_output_violation, "output")

                logger.debug(
                    "Function execution completed with compliance checks",
                    extra={
                        "function_name": func.__name__,
                        "agent_id": agent,
                        "compliance_passed": True,
                    },
                )

                return response

            finally:
                # Ensure client cleanup
                try:
                    ce.close()
                except Exception:
                    pass  # Ignore cleanup errors

        return wrapper

    return decorator
