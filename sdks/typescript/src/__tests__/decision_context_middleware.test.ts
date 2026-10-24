/**
 * withCompliance() must accept a class instance such as `new OpenAI()` and
 * send `decisionContext` on every check it makes.
 *
 * Its bound was `Record<string, unknown>`, which a class instance does not
 * satisfy, so the README's `withCompliance(new OpenAI(), ce)` did not compile,
 * and the middleware had no way to pass the decision context at all.
 * The compile half of this is checked by `npx tsc --noEmit` on this file.
 */
import { describe, it, expect, vi } from "vitest";
import { withCompliance } from "../openai-middleware";
import type { ComplyEdgeClient } from "../client";
import type { DecisionContext } from "../types";

class FakeOpenAI {
  chat = {
    completions: {
      create: vi.fn().mockResolvedValue({
        choices: [{ message: { content: "model answer" } }],
      }),
    },
  };
}

const CTX: DecisionContext = {
  deciding_system: { version: "1.4.0" },
  purpose_ref: "customer-support",
  data_categories: ["contact"],
};

describe("withCompliance with a class instance", () => {
  it("sends decisionContext on the input and the output check", async () => {
    const check = vi.fn().mockResolvedValue({ allowed: true, status: "safe", violations: [] });
    const ce = { check } as unknown as ComplyEdgeClient;
    const openai = withCompliance(new FakeOpenAI(), ce, { checkOutput: true, decisionContext: CTX });

    await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: "Hello" }],
    });

    expect(check).toHaveBeenCalledTimes(2);
    expect(check.mock.calls[0][1]).toMatchObject({ direction: "prompt", decisionContext: CTX });
    expect(check.mock.calls[1][0]).toBe("model answer");
    expect(check.mock.calls[1][1]).toMatchObject({ direction: "output", decisionContext: CTX });
  });

  it("sends no decisionContext when none is given", async () => {
    const check = vi.fn().mockResolvedValue({ allowed: true, status: "safe", violations: [] });
    const ce = { check } as unknown as ComplyEdgeClient;
    const openai = withCompliance(new FakeOpenAI(), ce, { checkOutput: true });

    await openai.chat.completions.create({ messages: [{ role: "user", content: "Hi" }] });

    for (const call of check.mock.calls) {
      expect(call[1].decisionContext).toBeUndefined();
    }
  });
});
