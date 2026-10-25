"""Python SDK: one stack per region, keys are region-bound, the SDK picks the
host — and every explicit setting outranks the inference.

Precedence (sdks/python/complyedge/__init__.py::resolve_base_url):
    base_url > COMPLYEDGE_API_URL > region / COMPLYEDGE_REGION > key prefix > US

Every client entry point (ComplyEdge, ComplyEdgeClient, AsyncComplyEdgeClient,
module-level check/is_safe, the agents guardrail, the decorator) must route a
`ce_eu_` key to eu.api.complyedge.io without being told. A `ce_eu_` key sent
to the US stack is refused with 401 wrong_region on its first call, so an SDK
that pinned the US host at import time would fail every EU customer.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest

pytest.importorskip("httpx")

import complyedge  # noqa: E402
from complyedge import (  # noqa: E402
    AsyncComplyEdgeClient,
    ComplyEdge,
    ComplyEdgeClient,
    region_from_api_key,
    resolve_base_url,
)

US = "https://api.complyedge.io"
EU = "https://eu.api.complyedge.io"


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch):
    monkeypatch.delenv("COMPLYEDGE_API_URL", raising=False)
    monkeypatch.delenv("COMPLYEDGE_REGION", raising=False)


class TestKeyInference:
    @pytest.mark.parametrize(
        "key, region",
        [
            ("ce_eu_abc", "eu"),
            ("ce_abc", "us"),
            ("sk-other", None),
            ("", None),
            (None, None),
        ],
    )
    def test_region_from_api_key(self, key, region):
        assert region_from_api_key(key) == region

    def test_eu_prefix_wins_over_its_us_prefix(self):
        """ce_eu_ starts with ce_; the longer prefix must be checked first."""
        assert region_from_api_key("ce_eu_x") == "eu"


class TestPrecedence:
    def test_key_alone_picks_the_region(self):
        assert resolve_base_url("ce_eu_x") == EU
        assert resolve_base_url("ce_x") == US
        # No recognisable prefix: EU, where every new account lives. US stays
        # reachable only for a legacy ce_ key (dormant stack, 2026-09-25).
        assert resolve_base_url("unknown") == EU
        assert resolve_base_url(None) == EU

    def test_region_argument_beats_the_key(self):
        assert resolve_base_url("ce_eu_x", region="us") == US
        assert resolve_base_url("ce_x", region="eu") == EU

    def test_region_env_beats_the_key_but_not_the_argument(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_REGION", "eu")
        assert resolve_base_url("ce_x") == EU
        assert resolve_base_url("ce_x", region="us") == US

    def test_api_url_env_beats_region(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_URL", "http://env.local/")
        assert resolve_base_url("ce_eu_x", region="us") == "http://env.local"

    def test_base_url_argument_beats_everything(self, monkeypatch):
        monkeypatch.setenv("COMPLYEDGE_API_URL", "http://env.local/")
        monkeypatch.setenv("COMPLYEDGE_REGION", "eu")
        assert (
            resolve_base_url("ce_eu_x", base_url="http://localhost:8000/", region="us")
            == "http://localhost:8000"
        )

    def test_unknown_region_is_refused_loudly(self):
        with pytest.raises(ValueError, match="Unknown ComplyEdge region"):
            resolve_base_url("ce_x", region="mars")


class TestEveryEntryPointUsesIt:
    def test_simple_client(self):
        assert ComplyEdge("ce_eu_k").base_url == EU
        assert ComplyEdge("ce_eu_k", region="us").base_url == US

    def test_advanced_clients(self):
        assert ComplyEdgeClient("ce_eu_k").base_url == EU
        assert AsyncComplyEdgeClient("ce_eu_k").base_url == EU
        assert ComplyEdgeClient("ce_k", region="eu").base_url == EU

    def test_module_level_check_and_is_safe(self):
        seen = []

        class _Fake:
            def __init__(self, **kw):
                seen.append(kw)

            def check(self, text, sandbox=False, decision_context=None):
                return "checked"

            def is_safe(self, text, decision_context=None):
                return True

            def close(self):
                pass

        with patch.object(complyedge, "ComplyEdge", _Fake):
            complyedge.check("t", api_key="ce_eu_k", region="eu")
            complyedge.is_safe("t", api_key="ce_eu_k")
        assert seen[0]["region"] == "eu" and seen[0]["base_url"] is None
        assert seen[1]["region"] is None

    def test_agents_guardrail_does_not_pin_a_host_at_import(self):
        from complyedge import agents

        assert agents._DEFAULT_BASE_URL is None
        created = []

        class _Fake:
            def __init__(self, api_key, base_url=None, **kw):
                created.append(resolve_base_url(api_key, base_url))

            def check(self, *a, **k):
                raise AssertionError("not called at construction")

        with patch.object(agents, "ComplyEdge", _Fake):
            agents.create_compliance_guardrail(api_key="ce_eu_k")
        assert created == [EU]

    def test_decorator_default_does_not_pin_a_host(self):
        from complyedge import decorators

        assert decorators._DEFAULT_BASE_URL is None


class TestEnvironmentHelpersStillWork:
    def test_env_url_without_key_prefix(self, monkeypatch):
        """A self-hosted / local override needs no key convention at all."""
        monkeypatch.setenv("COMPLYEDGE_API_URL", "http://localhost:8000")
        assert ComplyEdge("anything").base_url == "http://localhost:8000"
