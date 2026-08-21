import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import {
  CallToolResultSchema,
  ListToolsResultSchema
} from "@modelcontextprotocol/sdk/types.js";
import { createRequire } from "node:module";
import { describe, expect, it } from "vitest";
import { createServer } from "../server.js";

const packageJson = createRequire(import.meta.url)("../../package.json");

async function connectedClient() {
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const server = createServer();
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
});
