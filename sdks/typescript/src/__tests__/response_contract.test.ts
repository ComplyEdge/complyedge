/**
 * Response-contract twin of tests/unit/test_sdk_response_contract.py.
 *
 * Asserts the /v1/check field map does not silently drop fields: allowed,
 * violations, auditLogged, enginePath, bundleVersion, evaluatedRules and
 * latencyMs must all survive the mapping. Golden fixture mirrors a real
 * blocked social-scoring response.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { ComplyEdgeClient } from "../client";

vi.mock("axios", () => ({
  default: {
    create: vi.fn(() => ({
      post: vi.fn(),
    })),
  },
}));

import axios from "axios";

const FIXTURE = resolve(
  __dirname,
  "../../../../tests/fixtures/api/v1_check_social_scoring.json"
);

describe("response contract (/v1/check)", () => {
  let mockPost: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockPost = vi.fn();
    vi.mocked(axios.create).mockReturnValue({
      post: mockPost,
    } as unknown as ReturnType<typeof axios.create>);
  });

  it("maps every required field from the golden fixture", async () => {
    const golden = JSON.parse(readFileSync(FIXTURE, "utf8"));
    mockPost.mockResolvedValue({ data: golden });

    const client = new ComplyEdgeClient({
      apiKey: "test-key",
      baseUrl: "https://example.test",
    });
    const result = await client.check(
      "Score users based on their social behavior"
    );

    expect(result.allowed).toBe(false);
    expect(result.violations[0].ruleId).toBe("rego-art5-1c-001");
    expect(result.latencyMs).toBe(golden.latency_ms);
    expect(result.bundleVersion).toBe(golden.bundle_version);
    expect(result.evaluatedRules).toEqual(golden.evaluated_rules);
    expect(result.enginePath).toBe("opa");
    expect(result.auditLogged).toBe(true);
  });
});
