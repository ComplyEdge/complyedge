"""
ComplyEdge Agents Integration

Ready-to-use guardrail functions for AI agent frameworks.
Provides one-line compliance integration for OpenAI Agents and other frameworks.

Usage:
    from complyedge.agents import create_compliance_guardrail

    # One line setup — EU AI Act Article 5
    guardrail = create_compliance_guardrail(
        api_key="your-key",
        rules="eu-ai-act/article-5",
    )

    # Use with any agent framework
    agent = Agent(
        model="gpt-4",
        input_guardrails=[guardrail]
    )
"""

# PEP 604 unions (str | None) are evaluated at def time, so this module
# raised TypeError on import under Python 3.9 while pyproject, the PyPI
# classifiers and the quick-start all advertised 3.9 support. Reproduced
# on 3.9.19 at __init__.py:92. Do not remove without dropping 3.9.
from __future__ import annotations

import logging
import os
from collections.abc import Callable
from typing import Any

from . import ComplyEdge

# Resolve default base URL from environment
_DEFAULT_BASE_URL = os.getenv("COMPLYEDGE_API_URL", "https://api.complyedge.io")

logger = logging.getLogger(__name__)


# OpenAI Agents compatibility functions
def _create_input_guardrail(guardrail_function: Callable, name: str):
    """
    Create an OpenAI Agents compatible InputGuardrail object.

    Falls back to returning the raw function for non-OpenAI frameworks.
    """
    try:
        from agents import InputGuardrail

        return InputGuardrail(guardrail_function, name=name)
    except ImportError:
        return guardrail_function


def _create_output_guardrail(guardrail_function: Callable, name: str):
    """
    Create an OpenAI Agents compatible OutputGuardrail object.

    Falls back to returning the raw function for non-OpenAI frameworks.
    """
    try:
        from agents import OutputGuardrail

        return OutputGuardrail(guardrail_function, name=name)
    except ImportError:
        return guardrail_function


_RULE_TYPE_PATHS = {
    "sox": "us/sox",
    "gdpr": "eu/gdpr",
    "hipaa": "us/hipaa",
    "universal": "global/universal",
    "eu-ai-act": "eu-ai-act/article-5",
}


def create_compliance_guardrail(
    api_key: str,
    rules: str | list[str] = "eu-ai-act/article-5",
    base_url: str = _DEFAULT_BASE_URL,
    direction: str = "input",
    rule_type: str | None = None,
    jurisdiction: str | None = None,
    **_unused: Any,
) -> Callable:
    """
    Create a compliance guardrail for AI agent frameworks.

    Rule paths map 1:1 to OPA/Rego policy paths. Same engine, any regulation.

    Args:
        api_key: Your ComplyEdge API key
        rules: Rule path or list of rule paths to enforce
        base_url: ComplyEdge API base URL
        direction: "input" for input guardrail, "output" for output guardrail

    Returns:
        A guardrail compatible with OpenAI Agents and other frameworks

    Example:
        from complyedge.agents import create_compliance_guardrail
        from agents import Agent

        guardrail = create_compliance_guardrail(
            api_key="your-key",
            rules="eu-ai-act/article-5",
        )

        agent = Agent(
            model="gpt-4",
            input_guardrails=[guardrail],
        )
    """

    if rule_type:
        rules = _RULE_TYPE_PATHS.get(rule_type, rule_type)
    _ = jurisdiction  # accepted for the pre-pivot call sites; unused

    ce = ComplyEdge(api_key=api_key, base_url=base_url)
    rules_list = [rules] if isinstance(rules, str) else rules
    rules_label = ", ".join(rules_list)

    def compliance_guardrail(ctx: Any, agent: Any, input_data: str | list) -> Any:
        if isinstance(input_data, list):
            text_to_check = " ".join(str(item) for item in input_data)
        else:
            text_to_check = input_data

        try:
            result = ce.check(text_to_check)

            output_info = {
                "rules": rules_list,
                "event_id": result.event_id,
                "latency_ms": result.latency_ms,
                "evaluated_rules": result.evaluated_rules,
            }

            if not result.safe:
                output_info.update(
                    {
                        "compliance_status": "BLOCKED",
                        "reason": f"Compliance violation detected ({rules_label})",
                        "violations": [
                            {
                                "rule_id": v.rule_id,
                                "severity": v.severity.value,
                                "confidence": v.confidence,
                            }
                            for v in result.violations
                        ],
                    }
                )
                try:
                    from agents import GuardrailFunctionOutput

                    return GuardrailFunctionOutput(
                        output_info=output_info,
                        tripwire_triggered=True,
                    )
                except ImportError:
                    raise Exception(output_info["reason"])

            output_info["compliance_status"] = "SAFE"
            try:
                from agents import GuardrailFunctionOutput

                return GuardrailFunctionOutput(
                    output_info=output_info,
                    tripwire_triggered=False,
                )
            except ImportError:
                return None

        except Exception as e:
            if "BLOCKED" in str(e) or "compliance" in str(e).lower():
                raise
            logger.error(f"Compliance guardrail error: {str(e)}")
            try:
                from agents import GuardrailFunctionOutput

                return GuardrailFunctionOutput(
                    output_info={
                        "compliance_status": "ERROR_BLOCKED",
                        "reason": f"Compliance check failed — blocking for safety: {str(e)}",
                        "rules": rules_list,
                    },
                    tripwire_triggered=True,
                )
            except ImportError:
                raise Exception(f"Compliance check failed: {str(e)}")

    name = f"complyedge_{'_'.join(r.replace('/', '_').replace('-', '_') for r in rules_list)}"
    if direction == "output":
        return _create_output_guardrail(compliance_guardrail, name)
    return _create_input_guardrail(compliance_guardrail, name)


def create_sox_guardrail(
    api_key: str,
    base_url: str = _DEFAULT_BASE_URL,
    custom_blocked_message: str | None = None,
    **kwargs: Any,
) -> Callable:
    """Pre-pivot alias. SOX maps onto the same OPA engine as any other rule path."""
    _ = custom_blocked_message
    return create_compliance_guardrail(
        api_key=api_key, rules="us/sox", base_url=base_url, **kwargs
    )


def create_gdpr_guardrail(
    api_key: str,
    base_url: str = _DEFAULT_BASE_URL,
    custom_blocked_message: str | None = None,
    **kwargs: Any,
) -> Callable:
    """Pre-pivot alias. GDPR maps onto the same OPA engine as any other rule path."""
    _ = custom_blocked_message
    return create_compliance_guardrail(
        api_key=api_key, rules="eu/gdpr", base_url=base_url, **kwargs
    )


def create_hipaa_guardrail(
    api_key: str,
    base_url: str = _DEFAULT_BASE_URL,
    custom_blocked_message: str | None = None,
    **kwargs: Any,
) -> Callable:
    """Pre-pivot alias. HIPAA maps onto the same OPA engine as any other rule path."""
    _ = custom_blocked_message
    return create_compliance_guardrail(
        api_key=api_key, rules="us/hipaa", base_url=base_url, **kwargs
    )


def create_universal_guardrail(
    api_key: str,
    base_url: str = _DEFAULT_BASE_URL,
    use_simple_check: bool = False,
    custom_blocked_message: str | None = None,
    **kwargs: Any,
) -> Callable:
    """Pre-pivot alias. Universal maps onto the same OPA engine as any other rule path."""
    _ = use_simple_check, custom_blocked_message
    return create_compliance_guardrail(
        api_key=api_key, rules="global/universal", base_url=base_url, **kwargs
    )
