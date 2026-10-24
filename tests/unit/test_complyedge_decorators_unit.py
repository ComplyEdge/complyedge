"""
Fast, offline unit tests for complyedge.decorators.

The decorator talks to the HTTP-backed ComplyEdge client; here we patch
`_import_models` so a mock client is used and no network calls happen.
Covers: config resolution, fail-open degradation, input/output checks,
violation handling, custom handlers, and check-failure conservatism.
"""

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from complyedge import ComplianceError
from complyedge.decorators import (
    ComplianceConfig,
    compliance_check,
    default_violation_handler,
)


def _result(safe=True, violations=None, event_id="evt-1", rules=None):
    return SimpleNamespace(
        safe=safe,
        violations=violations if violations is not None else [],
        event_id=event_id,
        evaluated_rules=rules if rules is not None else ["eu-ai-act/article-5"],
    )


def _patch_models(client):
    """Patch decorators._import_models to return (ComplianceResult, ComplyEdge, ComplianceError).

    Only the ComplyEdge factory (2nd element) is used at runtime by the wrapper.
    """
    factory = MagicMock(return_value=client)
    return patch(
        "complyedge.decorators._import_models",
        return_value=(SimpleNamespace, factory, ComplianceError),
    )


class TestImportModels:
    def test_import_models_returns_real_symbols(self):
        from complyedge import (
            ComplianceError as RealError,
        )
        from complyedge import (
            ComplianceResult as RealResult,
        )
        from complyedge import (
            ComplyEdge as RealClient,
        )
        from complyedge.decorators import _import_models

        result_cls, client_cls, error_cls = _import_models()
        assert result_cls is RealResult
        assert client_cls is RealClient
        assert error_cls is RealError


class TestComplianceConfig:
    def test_stores_all_fields(self):
        handler = lambda r, c: None  # noqa: E731
        cond = lambda: True  # noqa: E731
        cfg = ComplianceConfig(
            api_key="k",
            check_input=False,
            check_output=False,
            enable_condition=cond,
            violation_handler=handler,
            agent_id="agent-x",
            jurisdiction="US",
            base_url="http://h",
            timeout=42,
            max_retries=7,
        )
        assert cfg.api_key == "k"
        assert cfg.check_input is False
        assert cfg.check_output is False
        assert cfg.enable_condition is cond
        assert cfg.violation_handler is handler
        assert cfg.agent_id == "agent-x"
        assert cfg.jurisdiction == "US"
        assert cfg.base_url == "http://h"
        assert cfg.timeout == 42
        assert cfg.max_retries == 7

    def test_defaults(self):
        cfg = ComplianceConfig()
        assert cfg.check_input is True
        assert cfg.check_output is True
        assert cfg.agent_id == "default"
        assert cfg.timeout == 300
        assert cfg.max_retries == 3


class TestDefaultViolationHandler:
    def test_raises_compliance_error_with_details(self):
        v1 = SimpleNamespace(rule_id="A")
        result = _result(
            safe=False, violations=[v1], event_id="evt-9", rules=["gdpr", "sox"]
        )
        with pytest.raises(ComplianceError) as exc:
            default_violation_handler(result, "input")
        msg = str(exc.value)
        assert "input" in msg
        assert "1 violation" in msg
        assert "gdpr, sox" in msg
        assert "evt-9" in msg
        assert exc.value.event_id == "evt-9"

    def test_falls_back_to_generic_policy_label(self):
        result = _result(safe=False, violations=[], event_id="evt-0", rules=[])
        with pytest.raises(ComplianceError) as exc:
            default_violation_handler(result, "output")
        assert "compliance policies" in str(exc.value)
        assert "0 violation" in str(exc.value)


class TestFailOpenDegradation:
    def test_disabled_via_env_proceeds_without_client(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "false")
        client = MagicMock()
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "ok:" + text

            assert fn("hello") == "ok:hello"
        client.check.assert_not_called()

    def test_missing_api_key_proceeds_without_client(self, monkeypatch):
        monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        with _patch_models(client):

            @compliance_check()
            def fn(text: str) -> str:
                return "done"

            assert fn("hi") == "done"
        client.check.assert_not_called()


class TestHappyPath:
    def test_input_and_output_safe_returns_response_and_closes(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(safe=True)
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "RESPONSE"

            assert fn("some input") == "RESPONSE"
        # input + output both checked
        assert client.check.call_count == 2
        client.close.assert_called_once()

    def test_non_string_args_skip_input_check(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(safe=True)
        with _patch_models(client):

            @compliance_check(input=True, output=False)
            def fn(a, b):
                return 123  # non-str return: output check skipped too

            assert fn(1, 2) == 123
        client.check.assert_not_called()

    def test_positional_and_kwarg_strings_combined_for_check(self, monkeypatch):
        # Input checking only runs when there is at least one positional arg;
        # positional + keyword string values are then combined into one check.
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(safe=True)
        with _patch_models(client):

            @compliance_check(input=True, output=False)
            def fn(first, note=""):
                return "r"

            fn("hi", note="please review")
        # direction="prompt" added 2026-08-04: input checks were previously
        # filed in the Article 12 audit trail as outputs.
        client.check.assert_called_once_with(
            "hi please review", direction="prompt", decision_context=None
        )

    def test_kwargs_only_is_still_input_checked(self, monkeypatch):
        """CORRECTED 2026-08-04. Was test_kwargs_only_skips_input_check.

        The old name and assertion codified a bug: `if check_input and args:`
        gated the kwargs collection loop as well, so a keyword-only call such
        as agent(prompt=...) was never compliance-checked and the decorator
        silently did nothing. The old comment ("the input-check block is
        skipped entirely") described the defect as if it were a design.

        A keyword argument is not less user input than a positional one, and
        the README promises every input is checked.
        """
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(safe=True)
        with _patch_models(client):

            @compliance_check(input=True, output=False)
            def fn(**kwargs):
                return "r"

            assert fn(note="please review") == "r"
        client.check.assert_called_once_with(
            "please review", direction="prompt", decision_context=None
        )


class TestViolationHandling:
    def test_input_violation_invokes_default_handler_and_raises(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(
            safe=False, violations=[SimpleNamespace(rule_id="X")], event_id="evt-in"
        )
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "should-not-run"

            with pytest.raises(ComplianceError) as exc:
                fn("dangerous")
        assert "input" in str(exc.value)
        # Function body must never run once input is blocked.
        client.close.assert_called_once()

    def test_output_violation_invokes_default_handler(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        # input safe, output blocked
        client.check.side_effect = [
            _result(safe=True),
            _result(
                safe=False,
                violations=[SimpleNamespace(rule_id="Y")],
                event_id="evt-out",
            ),
        ]
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "risky output"

            with pytest.raises(ComplianceError) as exc:
                fn("clean input")
        assert "output" in str(exc.value)

    def test_custom_violation_handler_returns_fallback(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(
            safe=False, violations=[SimpleNamespace(rule_id="Z")]
        )
        handler = MagicMock(return_value="SAFE_FALLBACK")
        with _patch_models(client):

            @compliance_check(input=True, output=False, violation_handler=handler)
            def fn(text: str) -> str:
                return "orig"

            assert fn("bad") == "SAFE_FALLBACK"
        handler.assert_called_once()
        assert handler.call_args[0][1] == "input"


class TestConfigObjectPath:
    def test_config_precedence_and_enable_condition(self, monkeypatch):
        monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
        client = MagicMock()
        client.check.return_value = _result(safe=True)
        cfg = ComplianceConfig(
            api_key="cfg-key",
            check_input=True,
            check_output=False,
            enable_condition=lambda: True,
            agent_id="cfg-agent",
            jurisdiction="EU",
            base_url="http://cfg",
        )
        factory = MagicMock(return_value=client)
        with patch(
            "complyedge.decorators._import_models",
            return_value=(SimpleNamespace, factory, ComplianceError),
        ):

            @compliance_check(config=cfg)
            def fn(text: str) -> str:
                return "ok"

            assert fn("hello") == "ok"
        # Client built from config values (api_key/agent/jurisdiction/base_url).
        _, kwargs = factory.call_args
        assert kwargs["api_key"] == "cfg-key"
        assert kwargs["agent_id"] == "cfg-agent"
        assert kwargs["jurisdiction"] == "EU"
        assert kwargs["base_url"] == "http://cfg"

    def test_config_enable_condition_false_fails_open(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "envkey")
        client = MagicMock()
        cfg = ComplianceConfig(api_key="cfg-key", enable_condition=lambda: False)
        with _patch_models(client):

            @compliance_check(config=cfg)
            def fn(text: str) -> str:
                return "passthrough"

            assert fn("x") == "passthrough"
        client.check.assert_not_called()

    def test_config_violation_handler_used(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        client = MagicMock()
        client.check.return_value = _result(
            safe=False, violations=[SimpleNamespace(rule_id="Q")]
        )
        cfg_handler = MagicMock(return_value="CFG_FALLBACK")
        cfg = ComplianceConfig(
            api_key="cfg-key",
            check_output=False,
            violation_handler=cfg_handler,
        )
        with _patch_models(client):

            @compliance_check(config=cfg)
            def fn(text: str) -> str:
                return "orig"

            assert fn("bad") == "CFG_FALLBACK"
        cfg_handler.assert_called_once()


class TestCheckFailureConservatism:
    def test_input_check_exception_proceeds_to_function(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        # input check raises, output check is safe
        client.check.side_effect = [RuntimeError("api down"), _result(safe=True)]
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "EXECUTED"

            assert fn("input") == "EXECUTED"

    def test_output_check_exception_returns_original_response(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.side_effect = [_result(safe=True), RuntimeError("api down")]
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "ORIGINAL"

            assert fn("input") == "ORIGINAL"

    def test_close_failure_is_swallowed(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_KEY", "k")
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "true")
        client = MagicMock()
        client.check.return_value = _result(safe=True)
        client.close.side_effect = RuntimeError("cannot close")
        with _patch_models(client):

            @compliance_check(input=True, output=True)
            def fn(text: str) -> str:
                return "OK"

            # close() error must not propagate.
            assert fn("input") == "OK"

    def test_decorator_preserves_function_metadata(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_ENABLED", "false")

        @compliance_check()
        def documented(text: str) -> str:
            """A docstring."""
            return text

        assert documented.__name__ == "documented"
        assert documented.__doc__ == "A docstring."
        assert hasattr(documented, "__wrapped__")
