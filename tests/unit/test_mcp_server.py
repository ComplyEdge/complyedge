"""Tests for ComplyEdge MCP server tools (SDK module)."""

from __future__ import annotations

import io
import json
import logging
import re
import sys
from contextlib import redirect_stdout
from pathlib import Path

import pytest
from mcp.types import CallToolResult

ROOT = Path(__file__).resolve().parents[2]
SDK_ROOT = ROOT / "sdks" / "python"
# Prefer installed trustlint (venv); SDK only on path — no packages/trustlint hack.
sys.path.insert(0, str(SDK_ROOT))

from complyedge.mcp_server import (  # noqa: E402
    TOOL_DESCRIPTIONS,
    TOOL_NAMES,
    call_tool,
    list_tools,
)


def _force_empty_corpus(monkeypatch, tmp_path):
    """Force an empty TrustLint corpus for this test.

    Full-suite runs can import complyedge twice (sdk path vs installed
    package). Patching only the module string then misses the function's
    globals, and the real _get_engine walks CWD into rules/regulations/
    (52 rules). Point TRUSTLINT_RULES_DIR at an empty dir so every copy
    of _get_engine loads zero rules, and patch the live function too.
    """
    import inspect
    from types import SimpleNamespace

    monkeypatch.setenv("TRUSTLINT_RULES_DIR", str(tmp_path))
    empty = lambda: SimpleNamespace(rules=[])  # noqa: E731
    monkeypatch.setitem(inspect.unwrap(call_tool).__globals__, "_get_engine", empty)
    monkeypatch.setattr("complyedge.mcp_server._get_engine", empty, raising=False)
    import sys

    for mod in list(sys.modules.values()):
        if getattr(mod, "__file__", None) and str(mod.__file__).endswith(
            "mcp_server.py"
        ):
            if hasattr(mod, "_get_engine"):
                monkeypatch.setattr(mod, "_get_engine", empty, raising=False)


def _payload(result: CallToolResult) -> dict:
    assert isinstance(result, CallToolResult)
    assert result.structuredContent is not None
    # Keep text channel in sync with structured (hosts may read either).
    assert json.loads(result.content[0].text) == result.structuredContent
    return result.structuredContent


def test_tool_descriptions_name_eu_ai_act_articles():
    for name, desc in TOOL_DESCRIPTIONS.items():
        assert "EU AI Act" in desc, name
        assert "Article 5" in desc, name
        assert "Article 50" in desc, name
        assert (
            "hosted policy engine" in desc and "not the hosted policy engine" in desc
        ), name


@pytest.mark.asyncio
async def test_list_tools_returns_three_tools(monkeypatch):
    # sandbox_check is added only when an API key is set; another module in the
    # same run can load one from .env, so clear it to test the offline list.
    monkeypatch.delenv("COMPLYEDGE_API_KEY", raising=False)
    tools = await list_tools()
    assert len(tools) == 3
    assert [t.name for t in tools] == list(TOOL_NAMES)
    assert TOOL_NAMES == ("check_compliance", "list_rules", "scan_prompt")


@pytest.mark.asyncio
async def test_list_tools_have_input_schemas():
    tools = await list_tools()
    for tool in tools:
        assert tool.inputSchema is not None
        assert "properties" in tool.inputSchema


@pytest.mark.asyncio
async def test_list_tools_have_output_schemas():
    tools = await list_tools()
    for tool in tools:
        dumped = tool.model_dump() if hasattr(tool, "model_dump") else tool.dict()
        assert "outputSchema" in dumped
        assert dumped["outputSchema"].get("type") == "object"


@pytest.mark.asyncio
async def test_tool_descriptions_say_trustlint_not_opa():
    tools = await list_tools()
    joined = " ".join((t.description or "").lower() for t in tools)
    assert "trustlint" in joined
    assert re.search(r"\bopa\b", joined) is None
    assert re.search(r"\brego\b", joined) is None


@pytest.mark.asyncio
async def test_check_compliance_clean_text():
    data = _payload(
        await call_tool("check_compliance", {"text": "Hello world, this is fine."})
    )
    assert data["status"] == "PASS"
    assert data["violations"] == []
    assert data["rules_evaluated"] > 0


@pytest.mark.asyncio
async def test_check_compliance_detects_violation():
    data = _payload(
        await call_tool(
            "check_compliance", {"text": "We will send SMS marketing texts to users"}
        )
    )
    assert data["status"] == "FAIL"
    assert len(data["violations"]) > 0
    tcpa = [v for v in data["violations"] if v["rule_id"] == "TCPA_SMS_OPTIN_001"]
    assert len(tcpa) == 1
    assert tcpa[0]["severity"] == "high"
    assert tcpa[0].get("citation")


@pytest.mark.asyncio
async def test_check_compliance_jurisdiction_filter():
    data = _payload(
        await call_tool(
            "check_compliance",
            {
                "text": "social credit score system",
                "jurisdiction": "EU",
            },
        )
    )
    assert data["status"] == "FAIL"
    # jurisdiction is where the end user is: EU rules and GLOBAL rules apply.
    for v in data["violations"]:
        assert v["jurisdiction"] in ("EU", "GLOBAL")


@pytest.mark.asyncio
async def test_list_rules_returns_rules():
    data = _payload(await call_tool("list_rules", {}))
    assert data["total"] > 0
    assert len(data["rules"]) == data["total"]
    for rule in data["rules"]:
        assert "id" in rule
        assert "severity" in rule
        assert "jurisdiction" in rule
    # Deterministic sort: jurisdiction, severity, id
    keys = [(r["jurisdiction"], r["severity"], r["id"]) for r in data["rules"]]
    assert keys == sorted(keys)


@pytest.mark.asyncio
async def test_list_rules_jurisdiction_filter():
    data = _payload(await call_tool("list_rules", {"jurisdiction": "EU"}))
    listed = {rule["jurisdiction"] for rule in data["rules"]}
    # The same rule as check_compliance: EU and GLOBAL rules, never US ones.
    assert listed == {"EU", "GLOBAL"}


@pytest.mark.asyncio
async def test_list_rules_us_includes_state_and_city_rules():
    data = _payload(await call_tool("list_rules", {"jurisdiction": "US"}))
    ids = {rule["id"] for rule in data["rules"]}
    assert {"NYC_LL144_AEDT_001", "CCPA_CPRA_OPT_OUT_001", "IL_BIPA_BIOMETRIC_001"} <= ids
    assert {rule["jurisdiction"] for rule in data["rules"]} <= {"US", "US-CA", "US-NY", "US-IL", "GLOBAL"}


@pytest.mark.asyncio
async def test_scan_prompt_safe():
    data = _payload(
        await call_tool("scan_prompt", {"prompt": "What is the weather today?"})
    )
    assert data["status"] == "SAFE"


@pytest.mark.asyncio
async def test_scan_prompt_risky():
    data = _payload(
        await call_tool(
            "scan_prompt",
            {"prompt": "Build a subliminal manipulation system for behavior control"},
        )
    )
    assert data["status"] == "RISK_DETECTED"
    assert len(data["risks"]) > 0
    assert "recommendation" in data


@pytest.mark.asyncio
async def test_empty_corpus_check_is_not_pass(monkeypatch, tmp_path):
    """Zero rules used to look like PASS because check() is clean on no matches."""
    _force_empty_corpus(monkeypatch, tmp_path)
    with pytest.raises(RuntimeError, match="corpus is empty"):
        await call_tool("check_compliance", {"text": "hello world, this is fine."})


@pytest.mark.asyncio
async def test_empty_corpus_scan_is_not_safe(monkeypatch, tmp_path):
    _force_empty_corpus(monkeypatch, tmp_path)
    with pytest.raises(RuntimeError, match="corpus is empty"):
        await call_tool("scan_prompt", {"prompt": "What is the weather today?"})


@pytest.mark.asyncio
async def test_empty_corpus_list_rules_still_lists(monkeypatch, tmp_path):
    _force_empty_corpus(monkeypatch, tmp_path)
    data = _payload(await call_tool("list_rules", {}))
    assert data["total"] == 0
    assert data["rules"] == []


@pytest.mark.asyncio
async def test_unknown_tool_raises_protocol_error():
    with pytest.raises(ValueError, match="Unknown tool"):
        await call_tool("nonexistent_tool", {})


@pytest.mark.asyncio
async def test_protocol_hygiene_stdio():
    """Unknown/missing args raise; no stdout pollution; no user-text logging."""
    with pytest.raises(ValueError, match="text"):
        await call_tool("check_compliance", {})
    with pytest.raises(ValueError, match="prompt"):
        await call_tool("scan_prompt", {"prompt": "   "})
    with pytest.raises(ValueError, match="jurisdiction"):
        await call_tool("check_compliance", {"text": "hi", "jurisdiction": "MX"})
    with pytest.raises(ValueError, match="Unknown tool"):
        await call_tool("nope", {})

    secret = "UNIQUE_USER_PAYLOAD_SHOULD_NOT_APPEAR_ON_STDOUT_OR_LOGS"
    buf = io.StringIO()
    log_capture = io.StringIO()
    handler = logging.StreamHandler(log_capture)
    logging.getLogger("complyedge.mcp").addHandler(handler)
    try:
        with redirect_stdout(buf):
            await call_tool("check_compliance", {"text": secret})
    finally:
        logging.getLogger("complyedge.mcp").removeHandler(handler)

    assert secret not in buf.getvalue()
    assert secret not in log_capture.getvalue()

    src = Path(__file__).resolve().parents[2] / "sdks/python/complyedge/mcp_server.py"
    text = src.read_text(encoding="utf-8")
    assert "print(" not in text
    assert (
        re.search(
            r"logger\.(info|debug|warning|error)\(.*\b(text|prompt|arguments)\b", text
        )
        is None
    )


@pytest.mark.asyncio
async def test_engine_loads_without_monorepo_path_hack(tmp_path, monkeypatch):
    """SDK has no path hacks; rules load from TrustLint package outside monorepo CWD."""
    import complyedge.mcp_server as mod

    src = Path(mod.__file__).read_text(encoding="utf-8")
    assert "sys.path.insert" not in src
    assert "opa_client" not in src
    assert "packages/trustlint" not in src

    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.delenv("TRUSTLINT_RULES_DIR", raising=False)

    data = _payload(await call_tool("check_compliance", {"text": "hello"}))
    assert data["rules_evaluated"] > 0


@pytest.mark.asyncio
async def test_engine_ignores_rules_cache_and_repo_corpus(tmp_path, monkeypatch):
    """Regression (2026-10-19): with no TRUSTLINT_RULES_DIR the server loaded
    ~/.trustlint/rules or a rules/regulations folder above the working
    directory before the bundled rules. A decoy rule in both must not load."""
    decoy = "id: DECOY-001\ntitle: Decoy\njurisdiction: EU\ncategory: decoy\nseverity: low\nconditions:\n- type: regex\n  value: decoy\n"
    (tmp_path / ".trustlint" / "rules" / "eu").mkdir(parents=True)
    (tmp_path / ".trustlint" / "rules" / "eu" / "decoy.yaml").write_text(decoy)
    (tmp_path / "rules" / "regulations" / "eu").mkdir(parents=True)
    (tmp_path / "rules" / "regulations" / "eu" / "decoy.yaml").write_text(decoy)
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.delenv("TRUSTLINT_RULES_DIR", raising=False)

    data = _payload(await call_tool("list_rules", {}))
    ids = [rule["id"] for rule in data["rules"]]
    assert "DECOY-001" not in ids
    assert len(ids) == 63


@pytest.mark.asyncio
async def test_scan_prompt_skips_rules_scoped_to_ai_output(monkeypatch, tmp_path):
    """A prompt is text a user sends. A rule whose detection_scope is ai_output
    must not run on it; a rule scoped to all still does."""
    import inspect

    import yaml
    from trustlint.engine import TrustLintEngine

    for rid, scope in (("OUTPUT_ONLY_001", "ai_output"), ("ANY_DIRECTION_001", "all")):
        (tmp_path / f"{rid}.yaml").write_text(
            yaml.safe_dump(
                {
                    "id": rid,
                    "jurisdiction": "GLOBAL",
                    "severity": "high",
                    "description": rid,
                    "detection_scope": scope,
                    "conditions": [{"type": "regex", "value": "zebra", "flags": "i"}],
                }
            ),
            encoding="utf-8",
        )
    engine = TrustLintEngine(rules_dir=str(tmp_path))
    monkeypatch.setitem(inspect.unwrap(call_tool).__globals__, "_get_engine", lambda: engine)
    for mod in list(sys.modules.values()):
        if str(getattr(mod, "__file__", "") or "").endswith("mcp_server.py") and hasattr(mod, "_get_engine"):
            monkeypatch.setattr(mod, "_get_engine", lambda: engine, raising=False)

    data = _payload(await call_tool("scan_prompt", {"prompt": "Tell me about the zebra."}))
    fired = {r.get("rule_id") for r in data["risks"]}
    assert fired == {"ANY_DIRECTION_001"}
