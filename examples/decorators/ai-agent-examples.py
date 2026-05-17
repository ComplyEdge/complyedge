#!/usr/bin/env python3
"""
ComplyEdge Decorator: AI Agent Examples

Shows how to add EU AI Act compliance to any Python function
with one decorator. Each example uses the jurisdiction= API.

Usage:
    pip install complyedge
    export COMPLYEDGE_API_KEY="your-key"
    python ai-agent-examples.py
"""

import os
import sys
from typing import Dict

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "sdks", "python"))

from complyedge import compliance_check, ComplianceConfig


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
# CROSS-JURISDICTION — US HIPAA, SOX, COPPA, TCPA, BIPA
# =============================================================================

@compliance_check(jurisdiction="US", agent_id="customer-service")
def customer_service_agent(message: str, account: Dict) -> str:
    """
    Customer service agent checked against US rule corpus (HIPAA, TCPA, BIPA, etc.).
    """
    return f"Support response for: {message}"


@compliance_check(jurisdiction="US", agent_id="medical-info")
def medical_information_agent(query: str) -> str:
    """
    Medical information agent — HIPAA minimum-necessary + PHI disclosure rules apply.
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

def main():
    print("=" * 60)
    print("ComplyEdge Decorator Examples — EU AI Act + US compliance")
    print("=" * 60)

    os.environ["COMPLYEDGE_ENABLED"] = "false"  # Demo mode
    os.environ["COMPLYEDGE_API_KEY"] = "demo_key"

    print("\n1. EU AI ACT — Article 5, Article 50, GPAI")
    print("-" * 40)

    print(f"  HR Agent: {hr_screening_agent('Senior developer, 5 years experience')[:80]}")
    print(f"  Content: {content_moderation_agent('Review this marketing copy')[:80]}")
    print(f"  Credit:  {credit_decision_agent('Applicant income 50K, credit score 720')[:80]}")

    print("\n2. US COMPLIANCE — HIPAA, SOX, COPPA, TCPA, BIPA")
    print("-" * 40)

    print(f"  Support: {customer_service_agent('Help with billing', {'tier': 'premium'})[:80]}")
    print(f"  Medical: {medical_information_agent('Diabetes management info')[:80]}")

    print("\n3. INPUT-ONLY / OUTPUT-ONLY")
    print("-" * 40)

    print(f"  Intake:  {intake_agent('Score citizens by social behaviour')[:80]}")
    print(f"  Output:  {generation_agent('Write a product description')[:80]}")

    print("\n" + "=" * 60)
    print("Every agent protected with one line:")
    print('  @compliance_check(jurisdiction="EU", agent_id="my-agent")')
    print("=" * 60)


if __name__ == "__main__":
    main()
