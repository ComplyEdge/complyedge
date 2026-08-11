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
from mcp.types import CallToolResult, TextContent, Tool, ToolAnnotations
from trustlint.engine import TrustLintEngine

logger = logging.getLogger("complyedge.mcp")

# Deterministic tools/list order (load-bearing for hosts + registry copy).
TOOL_NAMES = ("check_compliance", "list_rules", "scan_prompt")

# TrustLint offline tools are read-only and idempotent (TDR-04 / Glama TD-03).
TOOL_ANNOTATIONS = ToolAnnotations(readOnlyHint=True, idempotentHint=True)

# Shared with mcp_http so stdio/HTTP surfaces cannot drift (Glama A1–A5).
TOOL_DESCRIPTIONS: dict[str, str] = {
    "check_compliance": (
        "Check already-produced text (model input or output) against "
        "ComplyEdge TrustLint offline YAML rules (regex corpus). Use "
        "for post-hoc evaluation of text that already exists; for "
        "pre-generation screening of a prompt about to be sent, use "
        "scan_prompt. Argument `text` must be non-empty content to "
        "evaluate (empty/whitespace is rejected before any rule "
        "runs; this is not a system-risk questionnaire). Optional "
        "`jurisdiction` is EU, US, or GLOBAL; omit it to evaluate "
        "the full corpus. GLOBAL is a separate corpus tag, not the "
        "union of EU and US — reuse the same token you used with "
        "list_rules for a scoped check. Runs fully offline — no "
        "network call, no API key, no credentials stored, no writes "
        "outside the process, read-only and idempotent; "
        "deterministic regex match against the bundled corpus; does "
        "not classify AI-system risk tiers or call any remote API. "
        "Returns PASS/FAIL with rule ID, severity, citation, and "
        "remediation."
    ),
    "list_rules": (
        "List TrustLint offline compliance rules in the ComplyEdge "
        "corpus — the discovery tool; returns no PASS/FAIL or "
        "SAFE/RISK verdict. Use it to scope a jurisdiction before "
        "calling check_compliance; do not use it to evaluate text. "
        "Optional `jurisdiction` is EU, US, or GLOBAL; omit it to "
        "list the full corpus. GLOBAL is a separate corpus tag, not "
        "EU∪US — pass that exact token into check_compliance next "
        "for a consistent scoped evaluation. Returned `total` is "
        "the post-filter count. Runs fully offline — no network "
        "call, no API key, no credentials stored, no writes outside "
        "the process, read-only and idempotent. Returns rule IDs, "
        "titles, severities, jurisdictions, and categories."
    ),
    "scan_prompt": (
        "Scan an AI prompt with ComplyEdge TrustLint offline YAML "
        "rules (regex corpus) before generation — pre-generation "
        "only. Use when the prompt is about to be sent; for post-hoc "
        "evaluation of already-produced text, use check_compliance. "
        "Argument `prompt` must be a non-empty candidate prompt "
        "about to be sent to a model (empty/whitespace is rejected; "
        "not already-produced output). This tool has no "
        "jurisdiction filter — it always evaluates the full "
        "bundled corpus. Runs fully offline — no network call, no "
        "API key, no credentials stored, no writes outside the "
        "process, read-only and idempotent; deterministic regex "
        "match against the bundled corpus; does not classify "
        "AI-system risk tiers or call any remote API. Returns SAFE "
        "or RISK_DETECTED with cited findings from the offline "
        "regex corpus."
    ),
}

_JURISDICTION_ENUM = ["EU", "US", "GLOBAL"]

_CHECK_COMPLIANCE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "text": {
            "type": "string",
            "description": (
                "Non-empty already-produced content to evaluate "
                "(model input or output). Empty/whitespace is "
                "rejected before rules run; not a system-risk "
                "questionnaire."
            ),
        },
        "jurisdiction": {
            "type": "string",
            "description": (
                "Corpus scope: EU, US, or GLOBAL. Omit to evaluate "
                "the full corpus. GLOBAL is a separate tag, not "
                "EU∪US — reuse the same token from list_rules."
            ),
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
            "description": (
                "Corpus scope: EU, US, or GLOBAL. Omit to list the "
                "full corpus. GLOBAL is a separate tag, not EU∪US — "
                "pass the same token into check_compliance next."
            ),
            "enum": _JURISDICTION_ENUM,
        },
    },
}

_SCAN_PROMPT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "prompt": {
            "type": "string",
            "description": (
                "Non-empty candidate prompt about to be sent to a "
                "model (pre-generation). Empty/whitespace is "
                "rejected; not already-produced output."
            ),
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
        annotations=TOOL_ANNOTATIONS,
    )


@server.list_tools()
async def list_tools() -> list[Tool]:
    """Return tools in fixed order: check_compliance → list_rules → scan_prompt."""
    return [
        _tool(
            "check_compliance",
            TOOL_DESCRIPTIONS["check_compliance"],
            _CHECK_COMPLIANCE_SCHEMA,
            _CHECK_COMPLIANCE_OUTPUT,
        ),
        _tool(
            "list_rules",
            TOOL_DESCRIPTIONS["list_rules"],
            _LIST_RULES_SCHEMA,
            _LIST_RULES_OUTPUT,
        ),
        _tool(
            "scan_prompt",
            TOOL_DESCRIPTIONS["scan_prompt"],
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
