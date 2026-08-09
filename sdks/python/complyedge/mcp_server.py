"""ComplyEdge MCP stdio server — TrustLint offline compliance tools.

Install-true entrypoints (after ``pip install 'complyedge[mcp]'``)::

    python -m complyedge.mcp_server
    complyedge-mcp

Protocol: stdout = JSON-RPC only; logs go to stderr. Tools use the TrustLint
offline YAML corpus (not the REST API policy engine).
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import CallToolResult, TextContent, Tool
from trustlint.engine import TrustLintEngine

logger = logging.getLogger("complyedge.mcp")

# Deterministic tools/list order (load-bearing for hosts + registry copy).
TOOL_NAMES = ("check_compliance", "list_rules", "scan_prompt")

_JURISDICTION_ENUM = ["EU", "US", "GLOBAL"]

_CHECK_COMPLIANCE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "text": {
            "type": "string",
            "description": "The text to check for compliance violations",
        },
        "jurisdiction": {
            "type": "string",
            "description": "Filter by jurisdiction: EU, US, or GLOBAL. Omit for all.",
            "enum": _JURISDICTION_ENUM,
        },
    },
    "required": ["text"],
}

_LIST_RULES_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "jurisdiction": {
            "type": "string",
            "description": "Filter by jurisdiction: EU, US, or GLOBAL. Omit for all.",
            "enum": _JURISDICTION_ENUM,
        },
    },
}

_SCAN_PROMPT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "prompt": {
            "type": "string",
            "description": "The prompt text to scan before generation",
        },
    },
    "required": ["prompt"],
}

# JSON Schema 2020-12 output shapes (TR-02). Attached via Tool extra=allow.
_CHECK_COMPLIANCE_OUTPUT: dict[str, Any] = {
    "type": "object",
    "properties": {
        "status": {"type": "string", "enum": ["PASS", "FAIL"]},
        "violations": {"type": "array"},
        "rules_evaluated": {"type": "integer"},
        "message": {"type": "string"},
        "has_critical": {"type": "boolean"},
    },
    "required": ["status", "violations", "rules_evaluated"],
}

_LIST_RULES_OUTPUT: dict[str, Any] = {
    "type": "object",
    "properties": {
        "total": {"type": "integer"},
        "rules": {"type": "array"},
    },
    "required": ["total", "rules"],
}

_SCAN_PROMPT_OUTPUT: dict[str, Any] = {
    "type": "object",
    "properties": {
        "status": {"type": "string", "enum": ["SAFE", "RISK_DETECTED"]},
        "message": {"type": "string"},
        "risks": {"type": "array"},
        "rules_evaluated": {"type": "integer"},
        "recommendation": {"type": "string"},
    },
    "required": ["status", "rules_evaluated"],
}

server = Server("complyedge")


def _configure_logging() -> None:
    """Route logging to stderr so stdout stays JSON-RPC-clean."""
    root = logging.getLogger()
    if root.handlers:
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    )
    root.addHandler(handler)
    root.setLevel(logging.INFO)


def _get_engine() -> TrustLintEngine:
    """TrustLint with package-bundled rules (optional TRUSTLINT_RULES_DIR)."""
    rules_dir = os.environ.get("TRUSTLINT_RULES_DIR") or None
    return TrustLintEngine(rules_dir=rules_dir)


def _require_str(arguments: dict[str, Any], key: str) -> str:
    value = arguments.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or empty required argument: {key}")
    return value


def _optional_jurisdiction(arguments: dict[str, Any]) -> str | None:
    value = arguments.get("jurisdiction")
    if value is None:
        return None
    if not isinstance(value, str) or value not in _JURISDICTION_ENUM:
        raise ValueError(
            f"Invalid jurisdiction: {value!r}. Expected one of {_JURISDICTION_ENUM}"
        )
    return value


def _tool_result(payload: dict[str, Any]) -> CallToolResult:
    """Return structured + text content (required when Tool.outputSchema is set).

    MCP Server validates structuredContent against outputSchema. Returning only
    TextContent triggers \"outputSchema defined but no structured output returned\".
    Returning a bare dict is unsafe on older SDKs that treat dict as an iterable
    of content blocks (keys like \"status\"). CallToolResult is unambiguous.
    """
    return CallToolResult(
        content=[TextContent(type="text", text=json.dumps(payload))],
        structuredContent=payload,
    )


def _tool(
    name: str,
    description: str,
    input_schema: dict[str, Any],
    output_schema: dict[str, Any],
) -> Tool:
    # outputSchema via pydantic extra=allow on mcp>=1.1 (serializes in tools/list).
    return Tool(
        name=name,
        description=description,
        inputSchema=input_schema,
        outputSchema=output_schema,
    )


@server.list_tools()
async def list_tools() -> list[Tool]:
    """Return tools in fixed order: check_compliance → list_rules → scan_prompt."""
    return [
        _tool(
            "check_compliance",
            (
                "Check text against ComplyEdge TrustLint offline YAML rules "
                "(regex corpus). Returns PASS/FAIL with rule ID, severity, "
                "citation, and remediation."
            ),
            _CHECK_COMPLIANCE_SCHEMA,
            _CHECK_COMPLIANCE_OUTPUT,
        ),
        _tool(
            "list_rules",
            (
                "List TrustLint offline compliance rules in the ComplyEdge "
                "corpus. Returns rule IDs, titles, severities, jurisdictions, "
                "and categories."
            ),
            _LIST_RULES_SCHEMA,
            _LIST_RULES_OUTPUT,
        ),
        _tool(
            "scan_prompt",
            (
                "Pre-generation TrustLint scan of an AI prompt. Returns SAFE "
                "or RISK_DETECTED with cited findings from the offline regex "
                "corpus."
            ),
            _SCAN_PROMPT_SCHEMA,
            _SCAN_PROMPT_OUTPUT,
        ),
    ]


async def _check_compliance(
    engine: TrustLintEngine, arguments: dict[str, Any]
) -> CallToolResult:
    text = _require_str(arguments, "text")
    jurisdiction = _optional_jurisdiction(arguments)
    result = engine.check(text, jurisdiction=jurisdiction)

    if result.clean:
        return _tool_result(
            {
                "status": "PASS",
                "violations": [],
                "rules_evaluated": result.rules_evaluated,
                "message": "No compliance violations detected.",
            }
        )

    violations = [
        {
            "rule_id": v.rule_id,
            "title": v.title,
            "severity": v.severity,
            "jurisdiction": v.jurisdiction,
            "pattern_matched": v.pattern_matched,
            "citation": v.citation,
            "remediation": v.remediation,
        }
        for v in result.violations
    ]
    return _tool_result(
        {
            "status": "FAIL",
            "violations": violations,
            "rules_evaluated": result.rules_evaluated,
            "has_critical": result.has_critical,
        }
    )


async def _list_rules(
    engine: TrustLintEngine, arguments: dict[str, Any]
) -> CallToolResult:
    jurisdiction = _optional_jurisdiction(arguments)
    rules = engine.rules
    if jurisdiction:
        rules = [r for r in rules if r.jurisdiction.upper() == jurisdiction.upper()]

    rules_list = [
        {
            "id": r.id,
            "title": r.title,
            "jurisdiction": r.jurisdiction,
            "severity": r.severity,
            "category": r.category,
        }
        for r in sorted(rules, key=lambda r: (r.jurisdiction, r.severity, r.id))
    ]
    return _tool_result({"total": len(rules_list), "rules": rules_list})


async def _scan_prompt(
    engine: TrustLintEngine, arguments: dict[str, Any]
) -> CallToolResult:
    prompt = _require_str(arguments, "prompt")
    result = engine.check(prompt)

    if result.clean:
        return _tool_result(
            {
                "status": "SAFE",
                "message": "Prompt contains no detectable compliance risks.",
                "rules_evaluated": result.rules_evaluated,
            }
        )

    risks = [
        {
            "rule_id": v.rule_id,
            "severity": v.severity,
            "risk": v.title,
            "recommendation": v.remediation
            or f"Review prompt for {v.jurisdiction} {v.rule_id} compliance.",
        }
        for v in result.violations
    ]
    return _tool_result(
        {
            "status": "RISK_DETECTED",
            "risks": risks,
            "rules_evaluated": result.rules_evaluated,
            "recommendation": (
                "Modify the prompt to avoid the flagged regulatory risks "
                "before generating a response."
            ),
        }
    )


@server.call_tool()
async def call_tool(
    name: str, arguments: dict[str, Any] | None
) -> CallToolResult:
    """Dispatch a tool call. Unknown tools and bad args raise (isError=True)."""
    args = arguments or {}
    # Never log user text/prompt payloads (protocol_hygiene_stdio).
    engine = _get_engine()

    if name == "check_compliance":
        return await _check_compliance(engine, args)
    if name == "list_rules":
        return await _list_rules(engine, args)
    if name == "scan_prompt":
        return await _scan_prompt(engine, args)

    raise ValueError(
        f"Unknown tool: {name!r}. Available: {', '.join(TOOL_NAMES)}"
    )


async def run_stdio() -> None:
    """Serve MCP over stdio until the host closes stdin (EOF)."""
    _configure_logging()
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream, write_stream, server.create_initialization_options()
        )


def main() -> None:
    """Console-script / ``python -m`` entrypoint."""
    asyncio.run(run_stdio())


if __name__ == "__main__":
    main()
