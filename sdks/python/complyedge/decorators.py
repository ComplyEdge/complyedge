"""
ComplyEdge Compliance Decorator

Provides Pythonic decorator syntax for automatic compliance checking
in AI agent functions, supporting both input and output validation.
"""

import os
import functools
import logging
from typing import Callable, Any, Optional, Union, Dict, List, TYPE_CHECKING

if TYPE_CHECKING:
    from . import ComplianceResult, ComplyEdge

# Import from existing SDK components
# Note: Models and clients are defined in __init__.py
def _import_models():
    """Import models after module initialization to avoid circular imports."""
    from . import ComplianceResult, ComplyEdge
    return ComplianceResult, ComplyEdge

logger = logging.getLogger(__name__)


class ComplianceConfig:
    """
    Configuration object for compliance decorator.
    
    Provides enterprise-grade configuration for complex compliance scenarios
    including custom violation handlers, conditional enablement, and 
    multi-jurisdiction support.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        check_input: bool = True,
        check_output: bool = True,
        enable_condition: Optional[Callable[[], bool]] = None,
        violation_handler: Optional[Callable[["ComplianceResult", str], Any]] = None,
        agent_id: str = "default",
        jurisdiction: Optional[str] = None,
        base_url: str = "https://api.complyedge.io",
        timeout: int = 300,
        max_retries: int = 3
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


def default_violation_handler(result: "ComplianceResult", context: str) -> str:
    """
    Default handler for compliance violations.
    
    Provides conservative blocking behavior with informative error messages.
    Enterprise customers can override this with custom violation handling.
    
    Args:
        result: ComplianceResult containing violation details
        context: Either "input" or "output" indicating where violation occurred
        
    Returns:
        String message explaining the compliance violation
    """
    violation_count = len(result.violations) if result.violations else 0
    regulations = ", ".join(result.evaluated_rules) if result.evaluated_rules else "compliance policies"
    
    return (
        f"Request blocked due to compliance violation in {context}. "
        f"Found {violation_count} violation(s) against {regulations}. "
        f"Event ID: {result.event_id}"
    )


def compliance_check(
    input: bool = True,
    output: bool = True,
    api_key_env: str = "COMPLYEDGE_API_KEY",
    enabled_env: str = "COMPLYEDGE_ENABLED",
    agent_id: str = "default",
    jurisdiction: Optional[str] = None,
    config: Optional[ComplianceConfig] = None,
    violation_handler: Optional[Callable[["ComplianceResult", str], Any]] = None,
    base_url: str = "https://api.complyedge.io"
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
        enabled_env: Environment variable name for enabling/disabling compliance
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
                enabled = (config.enable_condition() if config.enable_condition 
                          else os.getenv(enabled_env, "false").lower() == "true")
                handler = config.violation_handler or violation_handler or default_violation_handler
                agent = config.agent_id
                juris = config.jurisdiction
                api_base_url = config.base_url
                timeout = config.timeout
                retries = config.max_retries
            else:
                check_input = input
                check_output = output
                api_key = os.getenv(api_key_env)
                enabled = os.getenv(enabled_env, "false").lower() == "true"
                handler = violation_handler or default_violation_handler
                agent = agent_id
                juris = jurisdiction
                api_base_url = base_url
                timeout = 300
                retries = 3
            
            # Graceful degradation: proceed without compliance if disabled or misconfigured
            if not enabled or not api_key:
                logger.debug(
                    "Compliance checking disabled or API key missing - proceeding without checks",
                    extra={
                        "enabled": enabled,
                        "api_key_present": bool(api_key),
                        "function_name": func.__name__,
                        "agent_id": agent
                    }
                )
                return func(*args, **kwargs)
            
            # Initialize ComplyEdge client with configuration
            # Import classes dynamically to avoid circular import
            ComplianceResult, ComplyEdge = _import_models()
            
            ce = ComplyEdge(
                api_key=api_key,
                agent_id=agent,
                jurisdiction=juris,
                base_url=api_base_url
            )
            
            try:
                # Input compliance checking
                if check_input and args:
                    # Extract string arguments for compliance checking
                    input_texts = []
                    for i, arg in enumerate(args):
                        if isinstance(arg, str) and arg.strip():
                            input_texts.append(arg)
                    
                    # Add string keyword arguments
                    for key, value in kwargs.items():
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
                                "jurisdiction": juris
                            }
                        )
                        
                        try:
                            result = ce.check(combined_input)
                            if not result.safe:
                                logger.warning(
                                    "Input compliance violation detected",
                                    extra={
                                        "function_name": func.__name__,
                                        "agent_id": agent,
                                        "event_id": result.event_id,
                                        "violation_count": len(result.violations) if result.violations else 0,
                                        "regulations": result.evaluated_rules
                                    }
                                )
                                return handler(result, "input")
                        except Exception as e:
                            logger.error(
                                "Input compliance check failed - proceeding with caution",
                                extra={
                                    "function_name": func.__name__,
                                    "agent_id": agent,
                                    "error": str(e)
                                }
                            )
                            # Conservative approach: allow function to proceed but log the failure
                
                # Execute the original function
                logger.debug(
                    "Executing function with compliance protection",
                    extra={
                        "function_name": func.__name__,
                        "agent_id": agent,
                        "input_checked": check_input,
                        "output_will_check": check_output
                    }
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
                            "jurisdiction": juris
                        }
                    )
                    
                    try:
                        result = ce.check(response)
                        if not result.safe:
                            logger.warning(
                                "Output compliance violation detected",
                                extra={
                                    "function_name": func.__name__,
                                    "agent_id": agent,
                                    "event_id": result.event_id,
                                    "violation_count": len(result.violations) if result.violations else 0,
                                    "regulations": result.evaluated_rules
                                }
                            )
                            return handler(result, "output")
                    except Exception as e:
                        logger.error(
                            "Output compliance check failed - returning original response",
                            extra={
                                "function_name": func.__name__,
                                "agent_id": agent,
                                "error": str(e)
                            }
                        )
                        # Conservative approach: return original response but log the failure
                
                logger.debug(
                    "Function execution completed with compliance checks",
                    extra={
                        "function_name": func.__name__,
                        "agent_id": agent,
                        "compliance_passed": True
                    }
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