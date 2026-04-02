#!/usr/bin/env python3
"""
ComplyEdge Decorator: AI Agent Examples

Shows how to add EU AI Act compliance to any Python function
with one decorator. Each example uses the canonical rules= API.

Usage:
    pip install complyedge
    export COMPLYEDGE_API_KEY="your-key"
    python ai-agent-examples.py
"""

import os
import sys
from typing import Dict, List

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "sdks", "python"))

from complyedge import compliance_check, ComplianceConfig


# =============================================================================
# EU AI ACT ARTICLE 5 — Prohibited Practices (law since Feb 2, 2025)
# =============================================================================

@compliance_check(rules="eu-ai-act/article-5", agent_id="hr-screening")
def hr_screening_agent(candidate_profile: str) -> str:
    """
    HR screening agent. Article 5 blocks social scoring and
    exploitation of vulnerabilities before they reach hiring decisions.
    """
    return f"Candidate evaluation: {candidate_profile}. Assessment based on qualifications only."


@compliance_check(rules="eu-ai-act/article-5", agent_id="content-moderation")
def content_moderation_agent(user_content: str) -> str:
    """
    Content moderation agent. Article 5 blocks subliminal manipulation
    and deceptive AI techniques in content generation.
    """
    return f"Content reviewed: {user_content}. No prohibited practices detected."


@compliance_check(rules="eu-ai-act/article-5", agent_id="credit-decision")
def credit_decision_agent(applicant_data: str) -> str:
    """
    Credit decision agent. Article 5 blocks exploitation of
    vulnerable populations (age, disability, economic situation).
    """
    return f"Credit assessment for: {applicant_data}. Decision based on financial criteria only."


# =============================================================================
# MULTI-REGULATION — Same decorator, multiple rules
# =============================================================================

@compliance_check(
    rules=["eu-ai-act/article-5", "gdpr/consent"],
    agent_id="customer-service",
)
def customer_service_agent(message: str, account: Dict) -> str:
    """
    Customer service agent checked against Article 5 AND GDPR consent rules.
    One decorator, multiple regulations, same pattern.
    """
    return f"Support response for: {message}"


@compliance_check(
    rules=["eu-ai-act/article-5", "pii/detection"],
    agent_id="medical-info",
)
def medical_information_agent(query: str) -> str:
    """
    Medical information agent. Article 5 + PII detection.
    Blocks prohibited practices and protects personal data.
    """
    response = f"General information: {query}"
    response += "\n\nDisclaimer: Consult a healthcare professional for medical advice."
    return response


# =============================================================================
# INPUT-ONLY vs OUTPUT-ONLY checking
# =============================================================================

@compliance_check(rules="eu-ai-act/article-5", input=True, output=False, agent_id="intake")
def intake_agent(user_message: str) -> str:
    """
    Input-only checking. Catches prohibited requests before
    they reach the LLM. Output passes through unchecked.
    """
    return f"Processing: {user_message}"


@compliance_check(rules="eu-ai-act/article-5", input=False, output=True, agent_id="generator")
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
    print("ComplyEdge Decorator Examples — EU AI Act")
    print("=" * 60)

    os.environ["COMPLYEDGE_ENABLED"] = "false"  # Demo mode
    os.environ["COMPLYEDGE_API_KEY"] = "demo_key"

    print("\n1. ARTICLE 5 — Prohibited Practices")
    print("-" * 40)

    print(f"  HR Agent: {hr_screening_agent('Senior developer, 5 years experience')[:80]}")
    print(f"  Content: {content_moderation_agent('Review this marketing copy')[:80]}")
    print(f"  Credit:  {credit_decision_agent('Applicant income 50K, credit score 720')[:80]}")

    print("\n2. MULTI-REGULATION")
    print("-" * 40)

    print(f"  Support: {customer_service_agent('Help with billing', {'tier': 'premium'})[:80]}")
    print(f"  Medical: {medical_information_agent('Diabetes management info')[:80]}")

    print("\n3. INPUT-ONLY / OUTPUT-ONLY")
    print("-" * 40)

    print(f"  Intake:  {intake_agent('Score citizens by social behaviour')[:80]}")
    print(f"  Output:  {generation_agent('Write a product description')[:80]}")

    print("\n" + "=" * 60)
    print("Every agent protected with one line:")
    print('  @compliance_check(rules="eu-ai-act/article-5")')
    print("=" * 60)


if __name__ == "__main__":
    main()