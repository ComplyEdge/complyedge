/**
 * The audit record's user columns can be filled from the SDK.
 *
 * Leo, 2026-09-29: a live export had user_id, user_role and session_id blank
 * on all 235 rows. check() sent only user_role, detectSensitivity() sent it at
 * the top level where the API's request model drops it, and neither could send
 * user_id or session_id at all.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("axios", () => ({ default: { create: vi.fn() } }));

import axios from "axios";
import { ComplyEdgeClient } from "../client";
import { withCompliance } from "../openai-middleware";

const OK = { data: { allowed: true, event_id: "e1", violations: [] } };
let post: ReturnType<typeof vi.fn>;

beforeEach(() => {
  post = vi.fn().mockResolvedValue(OK);
  vi.mocked(axios.create).mockReturnValue({ post } as unknown as ReturnType<typeof axios.create>);
});

const body = (i = 0) => post.mock.calls[i][1];

describe("check() attribution", () => {
  it("sends all three fields from per-call context", async () => {
    const ce = new ComplyEdgeClient({ apiKey: "k" });
    await ce.check("t", { userId: "emp_1", userRole: "analyst", sessionId: "s1" });
    expect(body().context).toEqual({ user_id: "emp_1", user_role: "analyst", session_id: "s1" });
  });

  it("falls back to client defaults, per-call wins", async () => {
    const ce = new ComplyEdgeClient({ apiKey: "k", userId: "u0", userRole: "r0", sessionId: "s0" });
    await ce.check("t", { userId: "u1" });
    expect(body().context).toEqual({ user_id: "u1", user_role: "r0", session_id: "s0" });
  });

  it("sends no context when there is no attribution", async () => {
    const ce = new ComplyEdgeClient({ apiKey: "k" });
    await ce.check("t");
    expect(body().context).toBeUndefined();
  });
});

describe("detectSensitivity() attribution", () => {
  it("sends attribution inside context, never top-level", async () => {
    post.mockResolvedValue({ data: { overall_risk_assessment: "safe" } });
    const ce = new ComplyEdgeClient({ apiKey: "k", sessionId: "s0" });
    await ce.detectSensitivity("t", { userId: "emp_1", userRole: "analyst" });
    expect(body().context).toEqual({ user_id: "emp_1", user_role: "analyst", session_id: "s0" });
    expect(body()).not.toHaveProperty("user_role");
  });
});

describe("OpenAI middleware attribution", () => {
  it("records the OpenAI `user` as userId, with client defaults for the rest", async () => {
    const ce = new ComplyEdgeClient({ apiKey: "k", userRole: "support", sessionId: "run-7" });
    const create = vi.fn().mockResolvedValue({ choices: [] });
    const openai = withCompliance({ chat: { completions: { create } } } as Record<string, unknown>, ce);
    await (openai.chat as any).completions.create({
      model: "m",
      user: "cust_42",
      messages: [{ role: "user", content: "hello" }],
    });
    expect(body().context).toEqual({ user_id: "cust_42", user_role: "support", session_id: "run-7" });
  });
});
