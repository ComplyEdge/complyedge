import { describe, it, expect, vi, beforeEach } from "vitest";
import { withCompliance, ComplianceError } from "../openai-middleware";
import type { ComplyEdgeClient } from "../client";

describe("withCompliance", () => {
  let mockCeClient: ComplyEdgeClient;
  let mockOpenAI: Record<string, unknown>;
  let mockCreate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockCeClient = {
      check: vi.fn().mockResolvedValue({
        allowed: true,
        status: "safe",
        violations: [],
      }),
    } as unknown as ComplyEdgeClient;

    mockCreate = vi.fn().mockResolvedValue({ choices: [{ message: { content: "response" } }] });

    mockOpenAI = {
      chat: {
        completions: {
          create: mockCreate,
        },
      },
    };
  });

  it("passes through when no violations", async () => {
    const wrapped = withCompliance(mockOpenAI, mockCeClient);
    const completions = (wrapped.chat as Record<string, unknown>).completions as Record<string, unknown>;
    const create = completions.create as (...args: unknown[]) => Promise<unknown>;

    await create({
      model: "gpt-4",
      messages: [{ role: "user", content: "Hello" }],
    });

    expect(mockCeClient.check).toHaveBeenCalledWith("Hello", expect.any(Object));
    expect(mockCreate).toHaveBeenCalled();
  });

  it("blocks on violation", async () => {
    vi.mocked(mockCeClient.check).mockResolvedValue({
      allowed: false,
      status: "violation",
      violations: [
        {
          ruleId: "rego-art5-1c-001",
          ruleDescription: "Social scoring prohibited under Article 5(1)(c)",
          severity: "critical",
          reason: "Behaviour-based classification of natural persons",
          confidence: 1.0,
        },
      ],
    } as never);

    const wrapped = withCompliance(mockOpenAI, mockCeClient);
    const completions = (wrapped.chat as Record<string, unknown>).completions as Record<string, unknown>;
    const create = completions.create as (...args: unknown[]) => Promise<unknown>;

    await expect(
      create({
        model: "gpt-4",
        messages: [{ role: "user", content: "Revenue increase 25%" }],
      })
    ).rejects.toThrow(ComplianceError);

    expect(mockCreate).not.toHaveBeenCalled();
  });

  it("allows through when blockOnViolation is false", async () => {
    vi.mocked(mockCeClient.check).mockResolvedValue({
      allowed: false,
      status: "violation",
      violations: [
        {
          ruleId: "rego-art5-1c-001",
          ruleDescription: "Social scoring prohibited under Article 5(1)(c)",
          severity: "medium",
          reason: "test",
          confidence: 0.9,
        },
      ],
    } as never);

    const wrapped = withCompliance(mockOpenAI, mockCeClient, { blockOnViolation: false });
    const completions = (wrapped.chat as Record<string, unknown>).completions as Record<string, unknown>;
    const create = completions.create as (...args: unknown[]) => Promise<unknown>;

    await create({
      model: "gpt-4",
      messages: [{ role: "user", content: "test" }],
    });

    expect(mockCreate).toHaveBeenCalled();
  });

  it("returns non-OpenAI clients unchanged", () => {
    const nonOpenAI = { foo: "bar" };
    const result = withCompliance(nonOpenAI, mockCeClient);
    expect(result).toBe(nonOpenAI);
  });

  it("checks only the last user message", async () => {
    const wrapped = withCompliance(mockOpenAI, mockCeClient);
    const completions = (wrapped.chat as Record<string, unknown>).completions as Record<string, unknown>;
    const create = completions.create as (...args: unknown[]) => Promise<unknown>;

    await create({
      model: "gpt-4",
      messages: [
        { role: "user", content: "first message" },
        { role: "assistant", content: "reply" },
        { role: "user", content: "second message" },
      ],
    });

    expect(mockCeClient.check).toHaveBeenCalledWith("second message", expect.any(Object));
  });
});
