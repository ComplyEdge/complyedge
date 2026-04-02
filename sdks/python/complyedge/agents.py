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

from typing import Any, Callable, List, Optional, Union
import logging

from . import ComplyEdge

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


def create_compliance_guardrail(
    api_key: str,
    rules: Union[str, List[str]] = "eu-ai-act/article-5",
    base_url: str = "https://api.complyedge.io",
    direction: str = "input",
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

    ce = ComplyEdge(api_key=api_key, base_url=base_url)
    rules_list = [rules] if isinstance(rules, str) else rules
    rules_label = ", ".join(rules_list)

    def compliance_guardrail(
        ctx: Any, agent: Any, input_data: Union[str, list]
    ) -> Any:
        text_to_check = input_data
        if isinstance(input_data, list):
            text_to_check = " ".join(str(item) for item in input_data)

        try:
            result = ce.check(text_to_check)

            output_info = {
                "rules": rules_list,
                "event_id": result.event_id,
                "latency_ms": result.latency_ms,
                "evaluated_rules": result.evaluated_rules,
            }

            if not result.safe:
                output_info.update({
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
                })
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
