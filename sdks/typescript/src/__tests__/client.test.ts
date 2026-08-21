import { describe, it, expect, vi, beforeEach } from "vitest";
import { ComplyEdgeClient } from "../client";

// Mock axios
vi.mock("axios", () => ({
  default: {
    create: vi.fn(() => ({
      post: vi.fn(),
    })),
  },
}));

import axios from "axios";

describe("ComplyEdgeClient", () => {
  let client: ComplyEdgeClient;
  let mockPost: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockPost = vi.fn();
    vi.mocked(axios.create).mockReturnValue({
      post: mockPost,
    } as unknown as ReturnType<typeof axios.create>);

    client = new ComplyEdgeClient({
      apiKey: "test-key-123",
      baseUrl: "https://test.api.complyedge.io",
    });
  });

  describe("constructor", () => {
    it("creates client with config", () => {
      expect(axios.create).toHaveBeenCalledWith(
        expect.objectContaining({
          baseURL: "https://test.api.complyedge.io",
          headers: expect.objectContaining({
            Authorization: "Bearer test-key-123",
          }),
        })
      );
    });

    it("strips trailing slashes from baseUrl", () => {
      new ComplyEdgeClient({ apiKey: "key", baseUrl: "https://api.test.io///" });
      expect(axios.create).toHaveBeenCalledWith(
        expect.objectContaining({ baseURL: "https://api.test.io" })
      );
    });
  });

  describe("check", () => {
    it("targets the OPA enforcement endpoint, not the legacy path", async () => {
      mockPost.mockResolvedValue({
        data: {
          event_id: "evt-123",
          allowed: true,
          violations: [],
          latency_ms: 12,
          bundle_version: "rego-corpus-2026.07.09",
          evaluated_rules: ["rego-art5-1c-001"],
          engine_path: "opa",
          audit_logged: true,
        },
      });

      const result = await client.check("Hello world");

      expect(mockPost).toHaveBeenCalledWith("/v1/check", {
        text: "Hello world",
        agent_id: "default",
        jurisdiction: "EU",
        direction: "output",
        use_semantic_fallback: false,
        context: undefined,
      });
      expect(result.allowed).toBe(true);
      expect(result.status).toBe("safe");
      expect(result.violations).toHaveLength(0);
      expect(result.auditLogged).toBe(true);
      expect(result.enginePath).toBe("opa");
      expect(result.bundleVersion).toBe("rego-corpus-2026.07.09");
    });

    it("surfaces the evidence fields that bind a decision to its input", async () => {
      mockPost.mockResolvedValue({
        data: {
          event_id: "evt-dd04",
          allowed: false,
          violations: [],
          text_hash: "498946c2f74704fcb1b41edf871b76a070f16853ed5b4b2c5516e63bffce91fc",
          timestamp: "2026-07-22T20:30:00+00:00",
          audit_logged: true,
        },
      });

      const result = await client.check("Score users based on their social behavior");

      // Bare hex digest, matching the Article 12 audit entry. A "sha256:" prefix
      // appears only in the synthetic DD sample and must not leak into the SDK.
      expect(result.textHash).toMatch(/^[a-f0-9]{64}$/);
      expect(result.timestamp).toBe("2026-07-22T20:30:00+00:00");
    });

    it("tolerates an API response without the evidence fields", async () => {
      mockPost.mockResolvedValue({ data: { event_id: "e", allowed: true, violations: [] } });

      const result = await client.check("test");

      expect(result.textHash).toBe("");
      expect(result.timestamp).toBeUndefined();
    });

    it("defaults to EU jurisdiction", async () => {
      mockPost.mockResolvedValue({ data: { event_id: "e", allowed: true, violations: [] } });

      await client.check("test");

      expect(mockPost).toHaveBeenCalledWith(
        "/v1/check",
        expect.objectContaining({ jurisdiction: "EU" })
      );
    });

    it("maps article-cited violations from the Rego bundle", async () => {
      mockPost.mockResolvedValue({
        data: {
          event_id: "evt-456",
          allowed: false,
          violations: [
            {
              rule_id: "rego-art5-1c-001",
              rule_description: "Social scoring prohibited under Article 5(1)(c)",
              severity: "critical",
              reason: "Behaviour-based classification of natural persons",
              confidence: 1.0,
              text_excerpt: "score users based on their social behavior",
            },
          ],
          latency_ms: 38,
          engine_path: "opa",
          opa_latency_ms: 3.2,
          audit_logged: true,
        },
      });

      const result = await client.check("Score users based on their social behavior");

      expect(result.allowed).toBe(false);
      expect(result.status).toBe("violation");
      expect(result.violations).toHaveLength(1);
      expect(result.violations[0].ruleId).toBe("rego-art5-1c-001");
      expect(result.violations[0].severity).toBe("critical");
      expect(result.violations[0].confidence).toBe(1.0);
      expect(result.violations[0].ruleDescription).toContain("Article 5(1)(c)");
      expect(result.opaLatencyMs).toBe(3.2);
    });

    // Renamed: the client no longer maps "prompt" to "input". It used to, and
    // the server enum accepts only prompt/output, so every withCompliance call
    // 422'd. This test asserted the mapping that was the bug, and stayed red
    // after the fix because the TS SDK suite is not part of the Python
    // regression run.
    it("passes the caller's direction through unchanged", async () => {
      mockPost.mockResolvedValue({ data: { event_id: "e", allowed: true, violations: [] } });

      await client.check("test", {
        jurisdiction: "US",
        direction: "prompt",
        agentId: "my-agent",
        userRole: "analyst",
      });

      expect(mockPost).toHaveBeenCalledWith(
        "/v1/check",
        expect.objectContaining({
          jurisdiction: "US",
          direction: "prompt",
          agent_id: "my-agent",
          context: { user_role: "analyst" },
        })
      );
    });

    it("includes processing time", async () => {
      mockPost.mockResolvedValue({ data: { event_id: "e", allowed: true, violations: [] } });

      const result = await client.check("test");
      expect(result.processingTimeMs).toBeGreaterThanOrEqual(0);
    });
  });

  describe("detectSensitivity", () => {
    it("keeps the legacy TrustLint pipeline reachable", async () => {
      mockPost.mockResolvedValue({
        data: {
          event_id: "evt-789",
          overall_risk_assessment: "violation",
          overall_risk_score: 0.9,
          detections: [
            {
              rule_id: "SOX_001",
              severity: "critical",
              regulation: "SOX",
              description: "Material disclosure",
            },
          ],
        },
      });

      const result = await client.detectSensitivity("Revenue will increase 25%");

      expect(mockPost).toHaveBeenCalledWith("/v1/sensitivity/detect", {
        input_text: "Revenue will increase 25%",
        agent_id: "default",
        // EU is the default across the API and both SDKs: the EU AI Act
        // prohibitions are EU-scoped, so a US default silently ran none of them.
        jurisdiction: "EU",
        direction: "prompt",
        user_role: undefined,
      });
      expect(result.status).toBe("violation");
      expect(result.detections[0].regulation).toBe("SOX");
    });
  });

  describe("assessPreDeployment", () => {
    it("sends pre-deployment assessment", async () => {
      mockPost.mockResolvedValue({
        data: {
          compliance_score: 0.8,
          risk_tier: "high",
          violations: [{ rule_id: "r1", article: "Art 5", description: "d", required_action: "a" }],
          required_disclosures: ["Disclosure 1"],
          eu_ai_act_category: "employment-workers",
          // Annex III application date per Reg (EU) 2026/1744, mirroring the API.
          estimated_deadline: "2027-12-02",
        },
      });

      const result = await client.assessPreDeployment({
        systemPrompt: "CV screening tool",
        jurisdiction: "EU",
      });

      expect(result.riskTier).toBe("high");
      expect(result.complianceScore).toBe(0.8);
      expect(result.violations).toHaveLength(1);
      expect(result.requiredDisclosures).toContain("Disclosure 1");
      expect(result.estimatedDeadline).toBe("2027-12-02");
    });
  });
});
