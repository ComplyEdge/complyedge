import { createRequire } from "node:module";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema
} from "@modelcontextprotocol/sdk/types.js";
import { TrustLintEngine, type LintResult, type Rule } from "trustlint";

// Single source of truth for the version: package.json. A hardcoded constant
// here read 0.1.1 while package.json said 0.1.2, so the published 0.1.2 server
// introduced itself to every MCP host as 0.1.1. Third instance of this class —
// trustlint's CLI held a hardcoded 2.0.0 against package.json 2.0.1, and
// setup.py records the Python side hitting it first.
//
// This package is ESM, so there is no ambient `require`; createRequire gives one.
// dist/server.js sits one level below the package root, so "../package.json"
// resolves both in this repo and inside node_modules/@complyedge/mcp.
const VERSION: string = createRequire(import.meta.url)("../package.json").version;

const TOOL_NAMES = ["check_compliance", "list_rules", "scan_prompt"] as const;
const JURISDICTIONS = ["EU", "US", "GLOBAL"] as const;

type ToolName = (typeof TOOL_NAMES)[number];
type Arguments = Record<string, unknown> | undefined;

const tools = [
  {
    name: "check_compliance",
    description:
      "Check already-produced text against the offline TrustLint corpus. Returns PASS or FAIL with cited findings. No network call or API key is required.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Non-empty text to evaluate." },
        jurisdiction: {
          type: "string",
          enum: JURISDICTIONS,
          description: "Optional corpus scope."
        }
      },
      required: ["text"]
    },
    annotations: { readOnlyHint: true, idempotentHint: true }
  },
  {
    name: "list_rules",
    description:
      "List offline TrustLint rules. This discovers rule coverage; it does not evaluate text or return a compliance verdict.",
    inputSchema: {
      type: "object",
      properties: {
        jurisdiction: {
          type: "string",
          enum: JURISDICTIONS,
          description: "Optional corpus scope."
        }
      }
    },
    annotations: { readOnlyHint: true, idempotentHint: true }
  },
  {
    name: "scan_prompt",
    description:
      "Scan a candidate prompt before generation against the offline TrustLint corpus. Returns SAFE or RISK_DETECTED. No network call or API key is required.",
    inputSchema: {
      type: "object",
      properties: {
        prompt: { type: "string", description: "Non-empty prompt to evaluate." }
      },
      required: ["prompt"]
    },
    annotations: { readOnlyHint: true, idempotentHint: true }
  }
] as const;

function requireText(args: Arguments, key: string): string {
  const value = args?.[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Missing or empty required argument: ${key}`);
  }
  return value;
}

function optionalJurisdiction(args: Arguments): string | undefined {
  const value = args?.jurisdiction;
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== "string" || !JURISDICTIONS.includes(value as "EU")) {
    throw new Error(`Invalid jurisdiction: ${String(value)}. Expected EU, US, or GLOBAL.`);
  }
  return value;
}

function resultContent(payload: Record<string, unknown>) {
  return { content: [{ type: "text" as const, text: JSON.stringify(payload) }] };
}

function compliancePayload(result: LintResult) {
  return {
    status: result.clean ? "PASS" : "FAIL",
    violations: result.violations,
    rules_evaluated: result.rulesEvaluated,
    has_critical: result.hasCritical,
    message: result.clean
      ? "No offline TrustLint rules matched."
      : `${result.violations.length} offline TrustLint rule(s) matched.`
  };
}

function promptPayload(result: LintResult) {
  return {
    status: result.clean ? "SAFE" : "RISK_DETECTED",
    risks: result.violations,
    rules_evaluated: result.rulesEvaluated,
    message: result.clean
      ? "No offline TrustLint rules matched."
      : `${result.violations.length} offline TrustLint rule(s) matched.`,
    recommendation: result.clean
      ? "Continue with the prompt under your normal review process."
      : "Review the cited findings before sending the prompt."
  };
}

export function createServer(engine = new TrustLintEngine()): Server {
  if (engine.rules.length === 0) {
    throw new Error("TrustLint loaded no bundled rules.");
  }

  const server = new Server(
    { name: "io.github.ComplyEdge/complyedge", version: VERSION },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const name = request.params.name as ToolName;
    const args = request.params.arguments as Arguments;

    try {
      if (name === "check_compliance") {
        return resultContent(
          compliancePayload(engine.check(requireText(args, "text"), optionalJurisdiction(args)))
        );
      }

      if (name === "list_rules") {
        const jurisdiction = optionalJurisdiction(args);
        const rules = engine.rules
          .filter((rule: Rule) => !jurisdiction || rule.jurisdiction === jurisdiction)
          .map((rule: Rule) => ({
            id: rule.id,
            title: rule.title,
            severity: rule.severity,
            jurisdiction: rule.jurisdiction,
            category: rule.category
          }));
        return resultContent({ total: rules.length, rules });
      }

      if (name === "scan_prompt") {
        return resultContent(promptPayload(engine.check(requireText(args, "prompt"))));
      }

      throw new Error(`Unknown tool: ${request.params.name}`);
    } catch (error) {
      return {
        content: [
          {
            type: "text" as const,
            text: error instanceof Error ? error.message : String(error)
          }
        ],
        isError: true
      };
    }
  });

  return server;
}
