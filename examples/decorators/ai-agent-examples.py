#!/usr/bin/env python3
"""
ComplyEdge Decorator: AI Agent Examples

Shows how to add a ComplyEdge check, and a record of each decision, to any
Python function with one decorator. Each example uses the jurisdiction= API.

With COMPLYEDGE_API_KEY set, every call is checked and recorded in your audit
trail. Without it, checking is off and the script says so.

Usage:
    pip install complyedge
    export COMPLYEDGE_API_KEY="your-key"
    python ai-agent-examples.py
"""

import os
import sys
from typing import Dict

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "sdks", "python"))

from complyedge import ComplianceConfig, ComplianceError, compliance_check


# =============================================================================
# EU AI ACT — Article 5 (prohibited), Article 50 (transparency), GPAI
# =============================================================================
# `jurisdiction="EU"` evaluates against the full EU rule corpus on the API.

@compliance_check(jurisdiction="EU", agent_id="hr-screening")
def hr_screening_agent(candidate_profile: str) -> str:
    """
    HR screening agent. Article 5 blocks social scoring and
    exploitation of vulnerabilities before they reach hiring decisions.
    """
    return f"Candidate evaluation: {candidate_profile}. Assessment based on qualifications only."


@compliance_check(jurisdiction="EU", agent_id="content-moderation")
def content_moderation_agent(user_content: str) -> str:
    """
    Content moderation agent. Article 5 blocks subliminal manipulation
    and deceptive AI techniques in content generation.
    """
    return f"Content reviewed: {user_content}. No prohibited practices detected."


@compliance_check(jurisdiction="EU", agent_id="credit-decision")
def credit_decision_agent(applicant_data: str) -> str:
    """
    Credit decision agent. Article 5 blocks exploitation of
    vulnerable populations (age, disability, economic situation).
    """
    return f"Credit assessment for: {applicant_data}. Decision based on financial criteria only."


# =============================================================================
# US — on the hosted path the US rule is SOX. HIPAA, COPPA, TCPA, BIPA and the
# other US rules run offline in TrustLint (pip install trustlint).
# =============================================================================

@compliance_check(jurisdiction="US", agent_id="customer-service")
def customer_service_agent(message: str, account: Dict) -> str:
    """
    Customer service agent checked with jurisdiction="US" (SOX on the hosted path).
    """
    return f"Support response for: {message}"


@compliance_check(jurisdiction="US", agent_id="medical-info")
def medical_information_agent(query: str) -> str:
    """
    Medical information agent. The HIPAA rules run offline in TrustLint, not on
    the hosted /v1/check path, so check this text with trustlint for HIPAA.
    """
    response = f"General information: {query}"
    response += "\n\nDisclaimer: Consult a healthcare professional for medical advice."
    return response


# =============================================================================
# INPUT-ONLY vs OUTPUT-ONLY checking
# =============================================================================

@compliance_check(jurisdiction="EU", input=True, output=False, agent_id="intake")
def intake_agent(user_message: str) -> str:
    """
    Input-only checking. Catches prohibited requests before
    they reach the LLM. Output passes through unchecked.
    """
    return f"Processing: {user_message}"


@compliance_check(jurisdiction="EU", input=False, output=True, agent_id="generator")
def generation_agent(prompt: str) -> str:
    """
    Output-only checking. LLM generates freely, but output
    is checked before delivery to the user.
    """
    return f"Generated content for: {prompt}"


# =============================================================================
# ENTERPRISE CONFIGURATION
# =============================================================================

enterprise_config = ComplianceConfig(
    api_key=os.getenv("COMPLYEDGE_API_KEY"),
    check_input=True,
    check_output=True,
    agent_id="enterprise-agent",
    jurisdiction="EU",
    enable_condition=lambda: os.getenv("ENVIRONMENT") == "production",
)


@compliance_check(config=enterprise_config)
def enterprise_agent(request: str) -> str:
    """Enterprise agent with custom config. Only active in production."""
    return f"Enterprise processing: {request}"


# =============================================================================
# DEMO
# =============================================================================

def _show(label: str, agent, *args) -> None:
    """Run one agent and print what came back, or the block if a rule fired."""
    try:
        print(f"  {label:<8} {agent(*args)[:80]}")
    except ComplianceError as e:
        print(f"  {label:<8} BLOCKED: {str(e)[:80]}")


def main():
    print("=" * 60)
    print("ComplyEdge Decorator Examples: EU AI Act and US checks")
    print("=" * 60)

    live = bool(os.getenv("COMPLYEDGE_API_KEY"))
    if live:
        print("COMPLYEDGE_API_KEY is set: every call below goes through /v1/check")
        print("and writes one record to your audit trail.")
    else:
        os.environ["COMPLYEDGE_ENABLED"] = "false"
        print("No COMPLYEDGE_API_KEY: checking is OFF and nothing is sent.")
        print("The lines below are the functions' own output, unchecked.")

    print("\n1. EU AI ACT")
    print("-" * 40)
    _show("HR:", hr_screening_agent, "Senior developer, 5 years experience")
    _show("Content:", content_moderation_agent, "Review this marketing copy")
    _show("Credit:", credit_decision_agent, "Applicant income 50K, credit score 720")

    print("\n2. US (SOX on the hosted path)")
    print("-" * 40)
    _show("Support:", customer_service_agent, "Help with billing", {"tier": "premium"})
    _show("Medical:", medical_information_agent, "Diabetes management info")

    print("\n3. INPUT-ONLY / OUTPUT-ONLY")
    print("-" * 40)
    _show("Intake:", intake_agent, "Score citizens by social behaviour")
    _show("Output:", generation_agent, "Write a product description")

    print("\n" + "=" * 60)
    if live:
        print("The intake request asks for social scoring: with checking on, the")
        print("Article 5 rule blocks it before the function runs.")
    else:
        print("The intake request asks for social scoring and passed because checking")
        print("is off. Set COMPLYEDGE_API_KEY and run again to see it blocked.")
    print("=" * 60)


if __name__ == "__main__":
    main()
