import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import {
  CallToolResultSchema,
  ListToolsResultSchema
} from "@modelcontextprotocol/sdk/types.js";
import { createRequire } from "node:module";
import { afterEach, describe, expect, it, vi } from "vitest";
import { mkdirSync, mkdtempSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  BUNDLED_RULES_DIR,
  createServer,
  resolveSandboxBaseUrl,
  type SandboxOptions
} from "../server.js";

const packageJson = createRequire(import.meta.url)("../../package.json");

async function connectedClient(sandbox?: SandboxOptions) {
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const server = createServer(undefined, sandbox);
  const client = new Client(
    { name: "complyedge-mcp-test", version: "1.0.0" },
    { capabilities: {} }
  );
  await server.connect(serverTransport);
  await client.connect(clientTransport);
  return client;
}

describe("ComplyEdge MCP server", () => {
  /**
   * Regression: the version an MCP host is told must be the version it installed.
   *
   * server.ts hardcoded `version: "0.1.1"` while package.json said 0.1.2, so the
   * published 0.1.2 introduced itself to every host as 0.1.1 — and the registry
   * entry advertised a third number. Caught only by driving the published
   * package over real stdio; no static check saw it.
   *
   * Third instance of this class in one codebase: trustlint's CLI held a
   * hardcoded 2.0.0 against package.json 2.0.1, and setup.py carries a note
   * about the Python side hitting it first. Asserts the property (serverInfo
   * equals package.json), not the literal, so it cannot rot into the same bug.
   */
  it("advertises the version this package actually is", async () => {
    const client = await connectedClient();
    expect(client.getServerVersion()?.version).toBe(packageJson.version);
  });

  /**
   * Regression (2026-10-19): createServer() built TrustLintEngine() with no
   * directory, so trustlint loaded ~/.trustlint/rules (the `trustlint update`
   * cache) or a rules/regulations folder above the working directory before
   * its bundled rules. On a machine with an old cache the server ran 52 rules
   * while the package said 63. A decoy rule in both places must not load.
   */
  it("loads the bundled corpus even with a rules cache in HOME and a repo corpus above cwd", async () => {
    const decoyRule = [
      "id: DECOY-001",
      "title: Decoy rule from a local cache",
      "jurisdiction: EU",
      "category: decoy",
      "severity: low",
      "conditions:",
      "- type: regex",
      "  value: decoy"
    ].join("\n");
    const home = mkdtempSync(join(tmpdir(), "mcp-home-"));
    mkdirSync(join(home, ".trustlint", "rules", "eu"), { recursive: true });
    writeFileSync(join(home, ".trustlint", "rules", "eu", "decoy.yaml"), decoyRule);
    const repo = mkdtempSync(join(tmpdir(), "mcp-repo-"));
    mkdirSync(join(repo, "rules", "regulations", "eu"), { recursive: true });
    writeFileSync(join(repo, "rules", "regulations", "eu", "decoy.yaml"), decoyRule);
    vi.stubEnv("HOME", home);
    // Vitest workers cannot chdir; trustlint reads process.cwd().
    const cwd = vi.spyOn(process, "cwd").mockReturnValue(repo);
    try {
      const client = await connectedClient();
      const response = await client.request(
        { method: "tools/call", params: { name: "list_rules", arguments: {} } },
        CallToolResultSchema
      );
      const listed = JSON.parse((response.content[0] as { text: string }).text);
      const ids = listed.rules.map((rule: { id: string }) => rule.id);
      expect(ids).not.toContain("DECOY-001");
      expect(listed.total).toBe(63);
      expect(readdirSync(BUNDLED_RULES_DIR)).toContain("universal");
    } finally {
      cwd.mockRestore();
      vi.unstubAllEnvs();
    }
  });

  it("list_rules uses the same jurisdiction rule as check_compliance", async () => {
    // jurisdiction is where the end user is: EU lists EU and GLOBAL rules, US
    // lists US, its state and city rules, and GLOBAL rules.
    const client = await connectedClient();
    const list = async (jurisdiction: string) => {
      const response = await client.request(
        { method: "tools/call", params: { name: "list_rules", arguments: { jurisdiction } } },
        CallToolResultSchema
      );
      return JSON.parse((response.content[0] as { text: string }).text).rules as Array<{ id: string; jurisdiction: string }>;
    };
    const eu = await list("EU");
    expect(new Set(eu.map((r) => r.jurisdiction))).toEqual(new Set(["EU", "GLOBAL"]));
    const us = await list("US");
    const ids = us.map((r) => r.id);
    expect(ids).toContain("NYC_LL144_AEDT_001");
    expect(ids).toContain("CCPA_CPRA_OPT_OUT_001");
  });

  it("lists only the documented offline tools", async () => {
    const client = await connectedClient();
    const response = await client.request(
      { method: "tools/list", params: {} },
      ListToolsResultSchema
    );

    expect(response.tools.map((tool) => tool.name)).toEqual([
      "check_compliance",
      "list_rules",
      "scan_prompt"
    ]);
    for (const tool of response.tools) {
      expect(tool.description).toContain("EU AI Act");
      expect(tool.description).toContain("Article 5");
      expect(tool.description).toContain("Article 50");
    }
  });

  it("returns cited offline findings for a prohibited social-scoring prompt", async () => {
    const client = await connectedClient();
    const response = await client.request(
      {
        method: "tools/call",
        params: {
          name: "check_compliance",
          arguments: {
            text: "The system uses a social credit score to determine access."
          }
        }
      },
      CallToolResultSchema
    );
    const text = response.content[0];
    expect(text.type).toBe("text");
    const payload = JSON.parse(text.text) as {
      status: string;
      violations: Array<{ ruleId: string; citation: string }>;
    };

    expect(payload.status).toBe("FAIL");
    expect(payload.violations[0].ruleId).toBe("EU_AI_ACT_ART5_SOCIAL_SCORING_001");
    expect(payload.violations[0].citation).toBeTruthy();
  });

  /**
   * sandbox_check is optional and key-gated (Leo, 2026-09-20). Without
   * COMPLYEDGE_API_KEY the server is exactly the offline trio above; with it,
   * a fourth tool calls the hosted POST /v1/sandbox/check, which records
   * nothing.
   */
  describe("sandbox_check (optional, with COMPLYEDGE_API_KEY)", () => {
    afterEach(() => {
      delete process.env.COMPLYEDGE_API_KEY;
      delete process.env.COMPLYEDGE_API_URL;
    });

    it("is absent without a key, present and last with one", async () => {
      const offline = await connectedClient();
      const before = await offline.request({ method: "tools/list", params: {} }, ListToolsResultSchema);
      expect(before.tools.map((t) => t.name)).toEqual(["check_compliance", "list_rules", "scan_prompt"]);

      const withKey = await connectedClient({ apiKey: "ce_test_key" });
      const after = await withKey.request({ method: "tools/list", params: {} }, ListToolsResultSchema);
      expect(after.tools.map((t) => t.name)).toEqual([
        "check_compliance",
        "list_rules",
        "scan_prompt",
        "sandbox_check"
      ]);
      const tool = after.tools[3];
      for (const needle of ["EU AI Act", "Article 5", "Article 50", "COMPLYEDGE_API_KEY", "NOTHING is recorded", "never evidence"]) {
        expect(tool.description).toContain(needle);
      }
    });

    it("reads the key from the environment at call time", async () => {
      process.env.COMPLYEDGE_API_KEY = "ce_env_key";
      const client = await connectedClient();
      const list = await client.request({ method: "tools/list", params: {} }, ListToolsResultSchema);
      expect(list.tools.map((t) => t.name)).toContain("sandbox_check");
    });

    it("calls POST /v1/sandbox/check on the key's region and reports not recorded", async () => {
      const fetchImpl = vi.fn(async () =>
        new Response(
          JSON.stringify({
            allowed: false,
            violations: [
              { rule_id: "rego-art5-1c-001", rule_description: "Regulation (EU) 2024/1689, Article 5(1)(c): ...", severity: "critical", reason: "Remove social scoring" }
            ],
            engine_path: "opa",
            latency_ms: 7.6,
            audit_logged: false,
            sandbox: true
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      );
      const client = await connectedClient({ apiKey: "ce_eu_test_key", fetchImpl: fetchImpl as unknown as typeof fetch });
      const response = await client.request(
        { method: "tools/call", params: { name: "sandbox_check", arguments: { text: "Score users by social behaviour" } } },
        CallToolResultSchema
      );
      expect(response.isError).toBeFalsy();
      const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
      expect(url).toBe("https://eu.api.complyedge.io/v1/sandbox/check");
      expect((init.headers as Record<string, string>).Authorization).toBe("Bearer ce_eu_test_key");
      expect(JSON.parse(String(init.body))).toMatchObject({ text: "Score users by social behaviour", jurisdiction: "EU", agent_id: "mcp-sandbox" });
      const payload = JSON.parse((response.content[0] as { text: string }).text);
      expect(payload.status).toBe("BLOCKED");
      expect(payload.audit_logged).toBe(false);
      expect(payload.sandbox).toBe(true);
      expect(payload.violations[0].rule_id).toBe("rego-art5-1c-001");
      expect(payload.violations[0].citation).toContain("Article 5(1)(c)");
      expect(payload.latency_ms).toBe(7);
      expect(payload.message).toContain("not recorded");
    });

    // DASH-016, 2026-10-19: an allowed check whose matched rules model review
    // cleared was reported as "No rule fired".
    it("names rules model review cleared instead of saying no rule fired", async () => {
      const fetchImpl = vi.fn(async () =>
        new Response(
          JSON.stringify({
            allowed: true,
            violations: [],
            overridden_hits: [{ rule_id: "rego-art5-1a-001", reason: "explains", confidence: 0.92 }],
            engine_path: "opa+llm_confirm",
            latency_ms: 410,
            audit_logged: false,
            sandbox: true
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      );
      const client = await connectedClient({ apiKey: "ce_eu_test_key", fetchImpl: fetchImpl as unknown as typeof fetch });
      const response = await client.request(
        { method: "tools/call", params: { name: "sandbox_check", arguments: { text: "This article explains subliminal techniques" } } },
        CallToolResultSchema
      );
      const payload = JSON.parse((response.content[0] as { text: string }).text);
      expect(payload.status).toBe("ALLOWED");
      expect(payload.cleared_by_model_review).toEqual(["rego-art5-1a-001"]);
      expect(payload.message).toBe("1 rule(s) matched and model review cleared them. Sandbox: not recorded.");
      expect(payload.message).not.toContain("No rule fired");
    });

    it("refuses to report a response the server did not mark as sandbox", async () => {
      const fetchImpl = vi.fn(async () =>
        new Response(JSON.stringify({ allowed: true, violations: [], audit_logged: true }), { status: 200 })
      );
      const client = await connectedClient({ apiKey: "ce_test_key", fetchImpl: fetchImpl as unknown as typeof fetch });
      const response = await client.request(
        { method: "tools/call", params: { name: "sandbox_check", arguments: { text: "x" } } },
        CallToolResultSchema
      );
      expect(response.isError).toBe(true);
      expect((response.content[0] as { text: string }).text).toContain("did not confirm sandbox");
    });

    it("rejects empty text before any network call and is unknown without a key", async () => {
      const fetchImpl = vi.fn();
      const keyed = await connectedClient({ apiKey: "ce_test_key", fetchImpl: fetchImpl as unknown as typeof fetch });
      const empty = await keyed.request(
        { method: "tools/call", params: { name: "sandbox_check", arguments: { text: "  " } } },
        CallToolResultSchema
      );
      expect(empty.isError).toBe(true);
      expect(fetchImpl).not.toHaveBeenCalled();

      const offline = await connectedClient();
      const unknown = await offline.request(
        { method: "tools/call", params: { name: "sandbox_check", arguments: { text: "x" } } },
        CallToolResultSchema
      );
      expect(unknown.isError).toBe(true);
      expect((unknown.content[0] as { text: string }).text).toContain("Unknown tool");
    });

    it("resolves the region from the key prefix, overridable by option or COMPLYEDGE_API_URL", () => {
      expect(resolveSandboxBaseUrl("ce_abc")).toBe("https://api.complyedge.io");
      expect(resolveSandboxBaseUrl("ce_eu_abc")).toBe("https://eu.api.complyedge.io");
      // Anything that is not a legacy ce_ key goes to EU (US is dormant).
      expect(resolveSandboxBaseUrl("sk_other")).toBe("https://eu.api.complyedge.io");
      expect(resolveSandboxBaseUrl("ce_eu_abc", "http://localhost:18310/")).toBe("http://localhost:18310");
      process.env.COMPLYEDGE_API_URL = "http://127.0.0.1:9/";
      expect(resolveSandboxBaseUrl("ce_abc")).toBe("http://127.0.0.1:9");
    });
  });
});
