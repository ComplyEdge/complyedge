import { createRequire } from "node:module";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema
} from "@modelcontextprotocol/sdk/types.js";
import { TrustLintEngine, type LintResult, type Rule } from "trustlint";

// Single source of truth for the version: package.json. A hardcoded constant
// here read 0.1.1 while package.json said 0.1.2, so the published 0.1.2 server
// introduced itself to every MCP host as 0.1.1. Third instance of this class :
// trustlint's CLI held a hardcoded 2.0.0 against package.json 2.0.1, and
// setup.py records the Python side hitting it first.
//
// This package is ESM, so there is no ambient `require`; createRequire gives one.
// dist/server.js sits one level below the package root, so "../package.json"
// resolves both in this repo and inside node_modules/@complyedge/mcp.
const VERSION: string = createRequire(import.meta.url)("../package.json").version;

const TOOL_NAMES = ["check_compliance", "list_rules", "scan_prompt"] as const;
const JURISDICTIONS = ["EU", "US", "GLOBAL"] as const;

// Optional fourth tool. Listed ONLY when COMPLYEDGE_API_KEY is set: it calls
// the hosted API (POST /v1/sandbox/check), so without a key it does not exist
// and the offline contract of the three tools above is untouched. The hosted
// sandbox evaluates with the tenant's real rules and settings and records
// nothing: no audit entry, no usage, no rate-limit count. Never evidence.
export const SANDBOX_TOOL_NAME = "sandbox_check";
export const API_KEY_ENV = "COMPLYEDGE_API_KEY";
// One stack per region; the key prefix says which (same rule as the SDKs).
const REGION_BASE_URLS = { us: "https://api.complyedge.io", eu: "https://eu.api.complyedge.io" };

type ToolName = (typeof TOOL_NAMES)[number] | typeof SANDBOX_TOOL_NAME;
type Arguments = Record<string, unknown> | undefined;

export interface SandboxOptions {
  /** Injected in tests; defaults to the environment variable. */
  apiKey?: string;
  /** Overrides the region resolved from the key prefix. */
  baseUrl?: string;
  /** Injected in tests; defaults to global fetch. */
  fetchImpl?: typeof fetch;
}

export function resolveSandboxBaseUrl(apiKey: string, override?: string): string {
  if (override) return override.replace(/\/+$/, "");
  const fromEnv = (process.env.COMPLYEDGE_API_URL || "").trim();
  if (fromEnv) return fromEnv.replace(/\/+$/, "");
  // A new account is EU (ce_eu_). A US account, after support moves it, uses ce_.
  // Unknown prefix goes to EU. COMPLYEDGE_API_URL picks a host and does not move the account.
  return apiKey.startsWith("ce_") && !apiKey.startsWith("ce_eu_")
    ? REGION_BASE_URLS.us
    : REGION_BASE_URLS.eu;
}

const sandboxTool = {
  name: SANDBOX_TOOL_NAME,
  description:
    "EU AI Act Article 5 and Article 50. Hosted ComplyEdge enforcement, sandbox mode: the same deterministic rules and tenant settings as production, but NOTHING is recorded : no audit entry, no usage, no rate-limit count. Use it to try a case before wiring an integration or to see what a rule catches; the result is never evidence. Requires COMPLYEDGE_API_KEY (this tool is listed only when it is set) and makes one network call to the ComplyEdge API (POST /v1/sandbox/check). Argument `text` must be non-empty; optional `jurisdiction` defaults to EU. Returns BLOCKED or ALLOWED with rule ID and article citation, engine_path and latency.",
  inputSchema: {
    type: "object",
    properties: {
      text: { type: "string", description: "Non-empty text to evaluate against hosted enforcement." },
      jurisdiction: { type: "string", description: "Regulatory scope, e.g. EU (default), US, US-CA." }
    },
    required: ["text"]
  },
  annotations: { readOnlyHint: true, idempotentHint: true }
} as const;

const tools = [
  {
    name: "check_compliance",
    description:
      "EU AI Act Article 5 and Article 50. TrustLint offline regex: not the hosted policy engine, not a system classifier. Check already-produced text against the offline TrustLint corpus. Returns PASS or FAIL with cited findings. No network call or API key is required.",
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
      "EU AI Act Article 5 and Article 50. TrustLint offline regex: not the hosted policy engine, not a system classifier. List offline TrustLint rules. This discovers rule coverage; it does not evaluate text or return a compliance verdict.",
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
      "EU AI Act Article 5 and Article 50. TrustLint offline regex: not the hosted policy engine, not a system classifier. Scan a candidate prompt before generation against the offline TrustLint corpus. Returns SAFE or RISK_DETECTED. No network call or API key is required.",
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

interface SandboxApiResponse {
  allowed?: unknown;
  violations?: Array<Record<string, unknown>>;
  engine_path?: string;
  latency_ms?: number;
  audit_logged?: unknown;
  sandbox?: unknown;
}

async function sandboxCheck(args: Arguments, apiKey: string, options: SandboxOptions) {
  const text = requireText(args, "text");
  const jurisdictionArg = args?.jurisdiction;
  if (jurisdictionArg !== undefined && (typeof jurisdictionArg !== "string" || !jurisdictionArg.trim())) {
    throw new Error("jurisdiction must be a non-empty string when given");
  }
  const doFetch = options.fetchImpl ?? fetch;
  const response = await doFetch(`${resolveSandboxBaseUrl(apiKey, options.baseUrl)}/v1/sandbox/check`, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      text,
      agent_id: "mcp-sandbox",
      jurisdiction: (jurisdictionArg as string | undefined) ?? "EU",
      direction: "output",
      use_semantic_fallback: false
    })
  });
  if (!response.ok) {
    throw new Error(`ComplyEdge API ${response.status} on /v1/sandbox/check`);
  }
  const data = (await response.json()) as SandboxApiResponse;
  if (data.sandbox !== true) {
    // The server is the only thing allowed to say a decision was not
    // recorded. A response without sandbox=true is not a sandbox result.
    throw new Error("API did not confirm sandbox mode; refusing to report");
  }
  const violations = (data.violations ?? []).map((v) => ({
    rule_id: (v.rule_id as string) ?? "",
    citation: (v.rule_description as string) ?? "",
    severity: (v.severity as string) ?? "",
    remediation: (v.reason as string) ?? ""
  }));
  const blocked = data.allowed !== true;
  return {
    status: blocked ? "BLOCKED" : "ALLOWED",
    violations,
    engine_path: data.engine_path ?? "",
    latency_ms: Math.trunc(data.latency_ms ?? 0),
    audit_logged: false,
    sandbox: true,
    message: violations.length
      ? `${violations.length} rule(s) fired. Sandbox: not recorded.`
      : "No rule fired. Sandbox: not recorded."
  };
}

export function createServer(engine = new TrustLintEngine(), sandbox: SandboxOptions = {}): Server {
  if (engine.rules.length === 0) {
    throw new Error("TrustLint loaded no bundled rules.");
  }

  const server = new Server(
    { name: "io.github.ComplyEdge/complyedge", version: VERSION },
    { capabilities: { tools: {} } }
  );

  // Read at call time, not at import: a host may set the key after start.
  const apiKey = () => (sandbox.apiKey ?? process.env[API_KEY_ENV] ?? "").trim();

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: apiKey() ? [...tools, sandboxTool] : [...tools]
  }));

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

      if (name === SANDBOX_TOOL_NAME && apiKey()) {
        return resultContent(await sandboxCheck(args, apiKey(), sandbox));
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
