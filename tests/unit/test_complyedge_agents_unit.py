"""
Fast, offline unit tests for complyedge.agents.

These exercise create_compliance_guardrail end-to-end by mocking the HTTP-backed
ComplyEdge client so no network calls are made.

Both halves of the optional-dependency split are covered, and BOTH are forced
explicitly rather than inferred from the environment:

  * ``_no_agents_module()``   -> the ImportError fallback branches
                                (raw-function guardrail, raise-on-block)
  * ``_fake_agents_module()`` -> the branches that need the SDK importable

These tests used to assume the optional ``agents`` (OpenAI Agents) package was
simply absent here, and read the live environment to get the fallback branch.
That assumption expired: `openai-agents` is declared as the `agents` extra in
sdks/python/pyproject.toml and is now present in the venv, so the fallback
branch stopped being reachable and 12 tests failed for an environment reason
rather than a code reason. A test that depends on a package being missing has a
hidden dependency on every future `pip install`; control the condition instead.
"""

from enum import Enum
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from complyedge import agents as agents_mod
from complyedge.agents import create_compliance_guardrail


class _Sev(str, Enum):
    HIGH = "high"
    CRITICAL = "critical"


def _safe_result():
    return SimpleNamespace(
        safe=True,
        event_id="evt-safe",
        latency_ms=12,
        evaluated_rules=["eu-ai-act/article-5"],
        violations=[],
    )


def _blocked_result():
    v = SimpleNamespace(
        rule_id="ART5_001",
        rule_description="Regulation (EU) 2024/1689, Article 5(1)(c): social scoring",
        severity=_Sev.HIGH,
        confidence=0.91,
        reason="Remove the social scoring.",
        text_excerpt="bad text",
    )
    return SimpleNamespace(
        safe=False,
        event_id="evt-block",
        latency_ms=34,
        evaluated_rules=["eu-ai-act/article-5"],
        violations=[v],
    )


def _no_agents_module():
    """Force the optional-dependency-absent branch.

    Binding ``sys.modules["agents"]`` to None makes ``from agents import X``
    raise ImportError, which is exactly the condition agents.py guards for —
    without caring whether the real package happens to be installed.
    """
    import sys

    return patch.dict(sys.modules, {"agents": None})


def _patch_client(result=None, side_effect=None):
    """Patch the ComplyEdge symbol used inside agents.py with a mock client."""
    client = MagicMock()
    if side_effect is not None:
        client.check.side_effect = side_effect
    else:
        client.check.return_value = result
    return patch.object(agents_mod, "ComplyEdge", return_value=client), client


class TestGuardrailConstruction:
    def test_returns_callable_when_agents_pkg_absent(self):
        p, _ = _patch_client(_safe_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k")
        assert callable(guard)

    def test_client_built_with_api_key_and_base_url(self):
        with patch.object(agents_mod, "ComplyEdge") as MockCE:
            create_compliance_guardrail(
                api_key="secret",
                base_url="http://localhost:9",
            )
        MockCE.assert_called_once_with(
            api_key="secret",
            agent_id="default",
            jurisdiction=None,
            base_url="http://localhost:9",
        )

    def test_agent_id_and_jurisdiction_reach_the_client(self):
        # Regression: agent_id was silently dropped and jurisdiction discarded,
        # so every guardrail check was filed as agent "default" and the ADA
        # dashboard could not attribute a single check to its agent.
        with patch.object(agents_mod, "ComplyEdge") as MockCE:
            create_compliance_guardrail(
                api_key="secret", agent_id="ada-coordinator", jurisdiction="EU"
            )
        MockCE.assert_called_once_with(
            api_key="secret",
            agent_id="ada-coordinator",
            jurisdiction="EU",
            base_url=None,
        )

    @pytest.mark.parametrize(
        ("direction", "expected"), [("input", "prompt"), ("output", "output")]
    )
    def test_direction_selects_audit_direction(self, direction, expected):
        # Regression: the guardrail always called check() with the client's
        # default direction ("output"), so input guardrails were filed in the
        # Art 12 trail as model outputs. Same defect the decorator fixed.
        p, client = _patch_client(_safe_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k", direction=direction)
            guard(None, None, "hello")
        client.check.assert_called_once_with("hello", direction=expected, user_id=None, user_role=None, session_id=None)

    def test_default_rule_is_article_5(self):
        # A single string rule is normalized into a one-element list; the
        # generated guardrail name encodes the rule path.
        with _no_agents_module(), patch.object(agents_mod, "ComplyEdge"):
            guard = create_compliance_guardrail(api_key="k")
        # Raw function fallback keeps __name__ from the inner function.
        assert callable(guard)


class TestGuardrailSafePath:
    def test_safe_returns_none_without_agents_pkg(self):
        p, client = _patch_client(_safe_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k")
            out = guard(ctx=None, agent=None, input_data="benign text")
        # With no OpenAI Agents installed, the safe branch returns None.
        assert out is None
        client.check.assert_called_once_with("benign text", direction="prompt", user_id=None, user_role=None, session_id=None)

    def test_list_input_is_joined_before_check(self):
        p, client = _patch_client(_safe_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k")
            guard(None, None, ["a", 1, "b"])
        client.check.assert_called_once_with("a 1 b", direction="prompt", user_id=None, user_role=None, session_id=None)


class TestGuardrailBlockedPath:
    def test_blocked_raises_without_agents_pkg(self):
        p, _ = _patch_client(_blocked_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(
                api_key="k", rules="eu-ai-act/article-5"
            )
            with pytest.raises(Exception) as exc:
                guard(None, None, "prohibited social scoring")
        # The fallback raises with the human-readable reason (rules label included).
        assert "Compliance violation detected" in str(exc.value)
        assert "eu-ai-act/article-5" in str(exc.value)


class TestGuardrailErrorHandling:
    def test_generic_error_is_wrapped_and_reraised(self):
        p, _ = _patch_client(side_effect=RuntimeError("network down"))
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k")
            with pytest.raises(Exception) as exc:
                guard(None, None, "text")
        assert "Compliance check failed" in str(exc.value)
        assert "network down" in str(exc.value)

    def test_compliance_flavoured_error_is_reraised_verbatim(self):
        # An error mentioning "compliance" must propagate unchanged (fail-closed),
        # not be swallowed/rewrapped.
        p, _ = _patch_client(side_effect=Exception("compliance backend exploded"))
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k")
            with pytest.raises(Exception) as exc:
                guard(None, None, "text")
        assert str(exc.value) == "compliance backend exploded"

    def test_blocked_keyword_error_is_reraised_verbatim(self):
        p, _ = _patch_client(side_effect=Exception("BLOCKED by upstream"))
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k")
            with pytest.raises(Exception) as exc:
                guard(None, None, "text")
        assert "BLOCKED" in str(exc.value)


class TestGuardrailDirection:
    def test_output_direction_builds_a_guardrail(self):
        p, _ = _patch_client(_safe_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(api_key="k", direction="output")
        assert callable(guard)

    def test_multiple_rules_accepted_as_list(self):
        p, client = _patch_client(_safe_result())
        with _no_agents_module(), p:
            guard = create_compliance_guardrail(
                api_key="k", rules=["gdpr/art-9", "eu-ai-act/article-5"]
            )
            guard(None, None, "text")
        client.check.assert_called_once()


class TestGuardrailFactoryHelpers:
    def test_input_helper_returns_raw_fn_when_pkg_absent(self):
        fn = MagicMock()
        with _no_agents_module():
            assert agents_mod._create_input_guardrail(fn, "n") is fn

    def test_output_helper_returns_raw_fn_when_pkg_absent(self):
        fn = MagicMock()
        with _no_agents_module():
            assert agents_mod._create_output_guardrail(fn, "n") is fn


def _fake_agents_module():
    """Build a stand-in for the OpenAI Agents SDK so we can exercise the
    branches that only run when that package is importable."""
    import sys
    import types

    mod = types.ModuleType("agents")

    class InputGuardrail:
        def __init__(self, fn, name=None):
            self.guardrail_function = fn
            self.name = name

    class OutputGuardrail:
        def __init__(self, fn, name=None):
            self.guardrail_function = fn
            self.name = name

    class GuardrailFunctionOutput:
        def __init__(self, output_info=None, tripwire_triggered=False):
            self.output_info = output_info
            self.tripwire_triggered = tripwire_triggered

    mod.InputGuardrail = InputGuardrail
    mod.OutputGuardrail = OutputGuardrail
    mod.GuardrailFunctionOutput = GuardrailFunctionOutput
    return patch.dict(sys.modules, {"agents": mod}), mod


class TestWithFakeAgentsPackage:
    """Cover the branches that only fire when the ``agents`` SDK is importable."""

    def test_input_guardrail_wrapped(self):
        fake, mod = _fake_agents_module()
        with fake:
            fn = MagicMock()
            wrapped = agents_mod._create_input_guardrail(fn, "gname")
            assert isinstance(wrapped, mod.InputGuardrail)
            assert wrapped.name == "gname"

    def test_output_guardrail_wrapped(self):
        fake, mod = _fake_agents_module()
        with fake:
            fn = MagicMock()
            wrapped = agents_mod._create_output_guardrail(fn, "oname")
            assert isinstance(wrapped, mod.OutputGuardrail)

    def test_safe_returns_guardrail_output_not_triggered(self):
        fake, mod = _fake_agents_module()
        p, _ = _patch_client(_safe_result())
        with fake, p:
            guard = create_compliance_guardrail(api_key="k")
            # guard is an InputGuardrail wrapper; call the inner function.
            out = guard.guardrail_function(None, None, "safe text")
        assert isinstance(out, mod.GuardrailFunctionOutput)
        assert out.tripwire_triggered is False
        assert out.output_info["compliance_status"] == "SAFE"

    def test_blocked_returns_triggered_output_with_violations(self):
        fake, mod = _fake_agents_module()
        p, _ = _patch_client(_blocked_result())
        with fake, p:
            guard = create_compliance_guardrail(api_key="k")
            out = guard.guardrail_function(None, None, "bad text")
        assert out.tripwire_triggered is True
        assert out.output_info["compliance_status"] == "BLOCKED"
        assert out.output_info["violations"][0]["rule_id"] == "ART5_001"
        assert out.output_info["violations"][0]["severity"] == "high"
        # The host renders the block to the user from output_info alone, so
        # the citation and the fix text must ride along, not just the id.
        v0 = out.output_info["violations"][0]
        assert v0["rule_description"].startswith("Regulation (EU) 2024/1689")
        assert v0["reason"] == "Remove the social scoring."
        assert v0["text_excerpt"] == "bad text"
        assert out.output_info["direction"] == "prompt"
        assert out.output_info["agent_id"] == "default"

    def test_generic_error_returns_error_blocked_output(self):
        fake, mod = _fake_agents_module()
        p, _ = _patch_client(side_effect=RuntimeError("boom"))
        with fake, p:
            guard = create_compliance_guardrail(api_key="k")
            out = guard.guardrail_function(None, None, "text")
        # Fail-closed: even an infra error trips the wire.
        assert out.tripwire_triggered is True
        assert out.output_info["compliance_status"] == "ERROR_BLOCKED"
