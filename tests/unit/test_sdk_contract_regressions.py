"""Regression tests for the SDK published-contract cluster (A2-A5, B8, F1).

Every defect here shared one shape: the README documented behaviour the code
did not implement, and the existing tests could not catch it because they
mocked the layer where the contract actually broke.

- A2  TS client sent direction "input"; the API enum accepts "prompt"|"output",
      so 100% of withCompliance traffic 422'd.
- A3  kill switch parsed only the literal "true", so COMPLYEDGE_ENABLED=1
      silently DISABLED enforcement.
- A4  `if check_input and args:` gated the kwargs loop too, so agent(prompt=...)
      was never checked.
- A5  decorator failed open on API error while is_safe() failed closed, with
      nothing documented and no way to choose.
- B8  every input check was filed as direction "output".
- F1  the retry decorator watched exception types the body had already
      converted, so no retry ever fired.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

pytest.importorskip("httpx")

from complyedge import ComplianceError, ComplyEdgeClient  # noqa: E402
from complyedge.decorators import (  # noqa: E402
    ComplianceConfig,
    ComplianceUnavailableError,
    _parse_enabled,
    compliance_check,
)


class TestKillSwitchParsing:
    """A3: a truthy value must never silently disable enforcement."""

    @pytest.mark.parametrize("raw", ["1", "true", "TRUE", " True ", "yes", "on", "y"])
    def test_truthy_spellings_keep_enforcement_on(self, raw):
        assert _parse_enabled(raw, var_name="COMPLYEDGE_ENABLED") is True

    @pytest.mark.parametrize("raw", ["0", "false", "FALSE", "no", "off", "n"])
    def test_falsy_spellings_disable(self, raw):
        assert _parse_enabled(raw, var_name="COMPLYEDGE_ENABLED") is False

    def test_unset_defaults_to_enabled(self):
        assert _parse_enabled(None, var_name="COMPLYEDGE_ENABLED") is True

    def test_unrecognised_value_raises_rather_than_guessing(self):
        # Guessing wrong here ships unenforced, so refuse instead.
        with pytest.raises(ValueError, match="not a recognised boolean"):
            _parse_enabled("maybe", var_name="COMPLYEDGE_ENABLED")


class TestKwargsAreChecked:
    """A4: keyword-only invocations must be checked like positional ones."""

    def test_kwargs_only_call_is_still_checked(self):
        seen: list[str] = []

        fake = MagicMock()
        fake.check.side_effect = lambda text, **kw: seen.append(text) or MagicMock(
            safe=True, violations=[]
        )

        # Patch the namespace `compliance_check` actually resolves from, not the
        # dotted path. patch("complyedge.decorators._import_models") looks the
        # module up in sys.modules at call time; if anything in the suite causes
        # complyedge.decorators to be re-imported after this test module bound
        # `compliance_check`, the patch lands on a DIFFERENT module object and
        # silently does nothing. The decorator then builds a real ComplyEdge,
        # the HTTP call fails, fail-open swallows it, and the assertion sees an
        # empty list with no hint as to why. __globals__ is the dict the
        # function body reads, so this cannot miss.
        with patch.dict(
            compliance_check.__globals__,
            {"_import_models": lambda: (MagicMock(), lambda **kw: fake, ComplianceError)},
        ):
            cfg = ComplianceConfig(
                api_key="test-key",
                check_output=False,
                enable_condition=lambda: True,
            )

            @compliance_check(config=cfg)
            def agent(prompt: str) -> str:
                return "ok"

            agent(prompt="social credit score for all citizens")

        assert seen, "kwargs-only call was never compliance-checked"
        assert "social credit" in seen[0]

    def test_input_check_declares_prompt_direction(self):
        """B8: input checks must not be filed as outputs in the audit trail."""
        directions: list[str] = []

        fake = MagicMock()

        def _check(text, **kw):
            directions.append(kw.get("direction", "<unset>"))
            return MagicMock(safe=True, violations=[])

        fake.check.side_effect = _check

        # Patch the namespace `compliance_check` actually resolves from, not the
        # dotted path. patch("complyedge.decorators._import_models") looks the
        # module up in sys.modules at call time; if anything in the suite causes
        # complyedge.decorators to be re-imported after this test module bound
        # `compliance_check`, the patch lands on a DIFFERENT module object and
        # silently does nothing. The decorator then builds a real ComplyEdge,
        # the HTTP call fails, fail-open swallows it, and the assertion sees an
        # empty list with no hint as to why. __globals__ is the dict the
        # function body reads, so this cannot miss.
        with patch.dict(
            compliance_check.__globals__,
            {"_import_models": lambda: (MagicMock(), lambda **kw: fake, ComplianceError)},
        ):
            cfg = ComplianceConfig(
                api_key="test-key",
                check_output=False,
                enable_condition=lambda: True,
            )

            @compliance_check(config=cfg)
            def agent(prompt: str) -> str:
                return "ok"

            agent("check this input")

        assert directions == ["prompt"], f"input filed as {directions}"


class TestFailModeIsExplicit:
    """A5: an API outage must not silently disable enforcement by default."""

    def test_closed_mode_refuses_to_run_unchecked(self):
        fake = MagicMock()
        fake.check.side_effect = ComplianceError("API down", retryable=True)

        cfg = ComplianceConfig(
            api_key="k",
            check_output=False,
            fail_mode="closed",
            enable_condition=lambda: True,
        )

        # Patch the namespace `compliance_check` actually resolves from, not the
        # dotted path. patch("complyedge.decorators._import_models") looks the
        # module up in sys.modules at call time; if anything in the suite causes
        # complyedge.decorators to be re-imported after this test module bound
        # `compliance_check`, the patch lands on a DIFFERENT module object and
        # silently does nothing. The decorator then builds a real ComplyEdge,
        # the HTTP call fails, fail-open swallows it, and the assertion sees an
        # empty list with no hint as to why. __globals__ is the dict the
        # function body reads, so this cannot miss.
        with patch.dict(
            compliance_check.__globals__,
            {"_import_models": lambda: (MagicMock(), lambda **kw: fake, ComplianceError)},
        ):

            @compliance_check(config=cfg)
            def agent(prompt: str) -> str:
                return "should not be reached"

            with pytest.raises(ComplianceUnavailableError):
                agent("anything")

    def test_open_mode_proceeds_but_is_opt_in(self):
        fake = MagicMock()
        fake.check.side_effect = ComplianceError("API down", retryable=True)

        cfg = ComplianceConfig(
            api_key="k",
            check_output=False,
            fail_mode="open",
            enable_condition=lambda: True,
        )

        # Patch the namespace `compliance_check` actually resolves from, not the
        # dotted path. patch("complyedge.decorators._import_models") looks the
        # module up in sys.modules at call time; if anything in the suite causes
        # complyedge.decorators to be re-imported after this test module bound
        # `compliance_check`, the patch lands on a DIFFERENT module object and
        # silently does nothing. The decorator then builds a real ComplyEdge,
        # the HTTP call fails, fail-open swallows it, and the assertion sees an
        # empty list with no hint as to why. __globals__ is the dict the
        # function body reads, so this cannot miss.
        with patch.dict(
            compliance_check.__globals__,
            {"_import_models": lambda: (MagicMock(), lambda **kw: fake, ComplianceError)},
        ):

            @compliance_check(config=cfg)
            def agent(prompt: str) -> str:
                return "ran unchecked"

            assert agent("anything") == "ran unchecked"

    def test_invalid_fail_mode_rejected(self):
        with pytest.raises(ValueError, match="fail_mode"):
            ComplianceConfig(api_key="k", fail_mode="sometimes")


class TestRetryActuallyFires:
    """F1: the retry decorator must watch a type the body can still raise."""

    def test_transient_errors_are_marked_retryable(self):
        assert ComplianceError("boom", retryable=True).retryable is True

    def test_client_errors_are_not_retryable_by_default(self):
        assert ComplianceError("bad request").retryable is False

    def test_request_error_is_retried_then_surfaces(self):
        import httpx

        ce = ComplyEdgeClient(api_key="k", base_url="http://localhost:1")
        with patch.object(
            ce.client, "post", side_effect=httpx.ConnectError("refused")
        ) as post:
            with pytest.raises(ComplianceError):
                ce.check_compliance("text", agent_id="a")
        # stop_after_attempt(3): a dead retry predicate would call exactly once.
        assert post.call_count == 3, (
            f"expected 3 attempts, saw {post.call_count}; "
            "the retry predicate is not matching the raised type"
        )
