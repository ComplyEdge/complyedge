/**
 * T9 (TypeScript): companion chatbot support in the SDK.
 *
 * Spec: docs/architecture/companion-chatbot-laws-tech-spec.md X10, X4, X5, X9.
 * axios is mocked; the tests assert the path and body the client issues.
 *
 * - the SDK sends what it is given and nothing else; `direction` is absent
 *   unless the caller gives it (it used to default to "output")
 * - a companion check without direction or sessionId is refused before any
 *   HTTP call
 * - the new response fields parse, and parse as empty on an older API
 * - confirmAction retries on 409 check_not_written_yet, then succeeds; stops
 *   10 minutes after the check's timestamp
 * - preserve sends RFC 8785 bytes that do not depend on the caller's formatting
 */
import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("axios", () => ({
  default: {
    create: vi.fn(() => ({ post: vi.fn() })),
  },
}));

import axios from "axios";
import { ComplyEdgeClient, canonicalConversation, checkRefusal } from "../src/client";
import type { ComplianceResult } from "../src/types";

const CHECK_OK = {
  event_id: "evt-1",
  allowed: true,
  violations: [],
  timestamp: "2026-11-14T20:00:00.000000Z",
  audit_logged: true,
};

const COMPANION_FIELDS = {
  companion_assessment: "assessed",
  companion_not_assessed_reason: null,
  companion_fallback: false,
  required_actions: [
    {
      action: "show_crisis_referral",
      rule_ids: ["us-ca-22602b-crisis-referral", "us-ca-21812-crisis"],
      jurisdiction: "US-CA",
      reason_code: "expresses_self_harm",
      due_at: "2026-11-14T20:00:00Z",
      interval_key: "ab".repeat(32),
      counted: true,
    },
    {
      action: "block_reply",
      rule_ids: ["us-ca-21812-block"],
      jurisdiction: "US-CA",
      reason_code: "minor_sexual_content",
      due_at: "2026-11-14T20:00:00Z",
      interval_key: "cd".repeat(32),
      counted: false,
    },
  ],
};

const RECEIPT = { event_id: "ntc-1", event_type: "notice", confirm_key: "ck", duplicate: false };

function conflict(data: unknown) {
  return Object.assign(new Error("Request failed with status code 409"), {
    response: { status: 409, data },
  });
}

describe("companion chatbot support", () => {
  let mockPost: ReturnType<typeof vi.fn>;
  let client: ComplyEdgeClient;

  function makeClient(extra: Record<string, string> = {}) {
    return new ComplyEdgeClient({ apiKey: "k", baseUrl: "https://example.test", ...extra });
  }

  beforeEach(() => {
    mockPost = vi.fn();
    vi.mocked(axios.create).mockReturnValue({
      post: mockPost,
    } as unknown as ReturnType<typeof axios.create>);
    client = makeClient();
  });

  describe("direction is sent only when given", () => {
    it("a check without direction sends no direction", async () => {
      mockPost.mockResolvedValue({ data: CHECK_OK });
      await client.check("hello");
      const body = mockPost.mock.calls[0][1];
      expect("direction" in body).toBe(false);
      expect(JSON.parse(JSON.stringify(body))).toEqual({
        text: "hello",
        agent_id: "default",
        jurisdiction: "EU",
        use_semantic_fallback: false,
      });
    });

    it("a check sends the direction it is given", async () => {
      mockPost.mockResolvedValue({ data: CHECK_OK });
      await client.check("hello", { direction: "prompt" });
      expect(mockPost.mock.calls[0][1].direction).toBe("prompt");
    });
  });

  describe("companion check", () => {
    it("sends use_case and the companion context, and nothing else", async () => {
      mockPost.mockResolvedValue({ data: { ...CHECK_OK, ...COMPANION_FIELDS } });
      const companion = {
        age_status: "known_minor" as const,
        age_source: "os_signal" as const,
        is_session_start: true,
        session_started_at: "2026-11-14T19:00:00Z",
        minutes_today: 42,
        referrals_this_session: 0,
        parent_linked: false,
      };
      await makeClient({ agentId: "pal" }).check("I want to hurt myself", {
        jurisdiction: "US-CA",
        direction: "prompt",
        useCase: "companion_chatbot",
        sessionId: "sess-1",
        userId: "u-9",
        companion,
      });
      expect(mockPost.mock.calls[0][0]).toBe("/v1/check");
      expect(JSON.parse(JSON.stringify(mockPost.mock.calls[0][1]))).toEqual({
        text: "I want to hurt myself",
        agent_id: "pal",
        jurisdiction: "US-CA",
        direction: "prompt",
        use_case: "companion_chatbot",
        use_semantic_fallback: false,
        context: { ...companion, session_id: "sess-1", user_id: "u-9" },
      });
    });

    it("takes the session from the client default", async () => {
      mockPost.mockResolvedValue({ data: CHECK_OK });
      await makeClient({ sessionId: "sess-c" }).check("hi", {
        direction: "output",
        useCase: "companion_chatbot",
      });
      expect(mockPost.mock.calls[0][1].context).toEqual({ session_id: "sess-c" });
    });

    it.each([
      [{ sessionId: "s" }, /direction/],
      [{ direction: "prompt" as const }, /sessionId/],
      [{}, /direction .* and sessionId/],
    ])("is refused before sending when incomplete (%o)", async (ctx, message) => {
      await expect(client.check("hi", { useCase: "companion_chatbot", ...ctx })).rejects.toThrow(
        message
      );
      expect(mockPost).not.toHaveBeenCalled();
    });
  });

  describe("response parsing", () => {
    it("parses the companion fields", async () => {
      mockPost.mockResolvedValue({
        data: { ...CHECK_OK, ...COMPANION_FIELDS, companion_fallback: true },
      });
      const r = await client.check("x", {
        direction: "prompt",
        useCase: "companion_chatbot",
        sessionId: "s",
      });
      expect(r.companionAssessment).toBe("assessed");
      expect(r.companionNotAssessedReason).toBeNull();
      expect(r.companionFallback).toBe(true);
      expect(r.requiredActions).toEqual([
        {
          action: "show_crisis_referral",
          ruleIds: ["us-ca-22602b-crisis-referral", "us-ca-21812-crisis"],
          jurisdiction: "US-CA",
          reasonCode: "expresses_self_harm",
          dueAt: "2026-11-14T20:00:00Z",
          intervalKey: "ab".repeat(32),
          counted: true,
        },
        {
          action: "block_reply",
          ruleIds: ["us-ca-21812-block"],
          jurisdiction: "US-CA",
          reasonCode: "minor_sexual_content",
          dueAt: "2026-11-14T20:00:00Z",
          intervalKey: "cd".repeat(32),
          counted: false,
        },
      ]);
    });

    it("parses not_assessed with its reason", async () => {
      mockPost.mockResolvedValue({
        data: {
          ...CHECK_OK,
          companion_assessment: "not_assessed",
          companion_not_assessed_reason: "budget",
          required_actions: [],
        },
      });
      const r = await client.check("x", {
        direction: "prompt",
        useCase: "companion_chatbot",
        sessionId: "s",
      });
      expect([r.companionAssessment, r.companionNotAssessedReason]).toEqual([
        "not_assessed",
        "budget",
      ]);
      expect(r.requiredActions).toEqual([]);
    });

    it("parses warnings and operator_asserted, and sends operator_labels", async () => {
      mockPost.mockResolvedValue({
        data: {
          ...CHECK_OK,
          ...COMPANION_FIELDS,
          companion_assessment: "operator_asserted",
          companion_warnings: ["age_status_missing"],
        },
      });
      const r = await client.check("x", {
        direction: "prompt",
        useCase: "companion_chatbot",
        sessionId: "s",
        companion: { operator_labels: ["expresses_self_harm"] },
      });
      expect(r.companionAssessment).toBe("operator_asserted");
      expect(r.companionWarnings).toEqual(["age_status_missing"]);
      expect(mockPost.mock.calls[0][1].context.operator_labels).toEqual(["expresses_self_harm"]);
    });

    it("a refused check keeps its warnings", () => {
      const refusal = checkRefusal({
        response: { status: 429, data: { detail: { companion_warnings: ["session_start_changed"] } } },
      });
      expect(refusal?.companionWarnings).toEqual(["session_start_changed"]);
    });

    it("an older API without the fields parses as empty", async () => {
      mockPost.mockResolvedValue({ data: CHECK_OK });
      const r = await client.check("x");
      expect(r.companionWarnings).toEqual([]);
      expect(r.companionAssessment).toBeNull();
      expect(r.companionNotAssessedReason).toBeNull();
      expect(r.companionFallback).toBe(false);
      expect(r.requiredActions).toEqual([]);
    });
  });

  describe("confirmAction", () => {
    async function companionCheck(timestamp: string): Promise<ComplianceResult> {
      mockPost.mockResolvedValueOnce({ data: { ...CHECK_OK, ...COMPANION_FIELDS, timestamp } });
      return client.check("x", { direction: "prompt", useCase: "companion_chatbot", sessionId: "s" });
    }

    it("fills the body from the required action and the check", async () => {
      client = makeClient({ agentId: "pal", sessionId: "sess-1" });
      const check = await companionCheck("2026-11-14T20:00:00.000000Z");
      mockPost.mockResolvedValueOnce({ data: RECEIPT });
      const receipt = await client.confirmAction({
        requiredAction: check.requiredActions[0],
        check,
        confirmationId: "conf-1",
        source: "complyedge",
        shownAt: "2026-11-14T20:00:01Z",
        format: "app",
        decidingSystemVersion: "pal-3",
        language: "en",
      });
      expect(mockPost.mock.calls[1][0]).toBe("/v1/companion/action");
      expect(mockPost.mock.calls[1][1]).toEqual({
        confirmation_id: "conf-1",
        action: "show_crisis_referral",
        source: "complyedge",
        shown_at: "2026-11-14T20:00:01Z",
        session_id: "sess-1",
        agent_id: "pal",
        jurisdiction: "US-CA",
        rule_id: "us-ca-22602b-crisis-referral",
        format: "app",
        deciding_system_version: "pal-3",
        language: "en",
        check_event_id: "evt-1",
        check_timestamp: "2026-11-14T20:00:00.000000Z",
        interval_key: "ab".repeat(32),
      });
      expect(receipt).toEqual({
        eventId: "ntc-1",
        eventType: "notice",
        confirmKey: "ck",
        duplicate: false,
      });
    });

    it("an operator-only notice sends no check fields", async () => {
      mockPost.mockResolvedValueOnce({ data: { ...RECEIPT, duplicate: true } });
      const receipt = await makeClient({ agentId: "pal" }).confirmAction({
        action: "minors_notice",
        confirmationId: "op-1",
        source: "operator",
        shownAt: "2026-11-14T20:00:01Z",
        sessionId: "sess-1",
        jurisdiction: "US-CA",
        format: "browser",
      });
      expect(mockPost.mock.calls[0][1]).toEqual({
        confirmation_id: "op-1",
        action: "minors_notice",
        source: "operator",
        shown_at: "2026-11-14T20:00:01Z",
        session_id: "sess-1",
        agent_id: "pal",
        jurisdiction: "US-CA",
        format: "browser",
      });
      expect(receipt.duplicate).toBe(true);
    });

    it("is refused before sending without a session", async () => {
      await expect(
        client.confirmAction({
          action: "minors_notice",
          confirmationId: "x",
          source: "operator",
          shownAt: "t",
        })
      ).rejects.toThrow(/session_id/);
      expect(mockPost).not.toHaveBeenCalled();
    });

    it("retries on 409 check_not_written_yet, then succeeds", async () => {
      const check = await companionCheck(new Date().toISOString());
      const waits: number[] = [];
      vi.spyOn(client as unknown as { sleep: (ms: number) => Promise<void> }, "sleep").mockImplementation(
        async (ms: number) => {
          waits.push(ms);
        }
      );
      mockPost
        .mockRejectedValueOnce(conflict({ detail: { code: "check_not_written_yet" } }))
        .mockRejectedValueOnce(conflict({ code: "check_not_written_yet" }))
        .mockResolvedValueOnce({ data: RECEIPT });
      const receipt = await client.confirmAction({
        requiredAction: check.requiredActions[0],
        check,
        confirmationId: "c",
        source: "complyedge",
        shownAt: new Date(),
        sessionId: "s",
      });
      expect(receipt.eventId).toBe("ntc-1");
      expect(mockPost).toHaveBeenCalledTimes(4); // the check, then three confirmation attempts
      expect(waits).toEqual([1000, 2000]);
      const bodies = mockPost.mock.calls.slice(1).map((c) => c[1]);
      expect(bodies[0]).toEqual(bodies[1]);
      expect(bodies[1]).toEqual(bodies[2]);
    });

    it("gives up 10 minutes after the check's timestamp", async () => {
      const checkMs = Date.parse("2026-11-14T20:00:00Z");
      let clock = checkMs + 9 * 60_000 + 58_000;
      const waits: number[] = [];
      const internals = client as unknown as {
        sleep: (ms: number) => Promise<void>;
        now: () => number;
      };
      vi.spyOn(internals, "now").mockImplementation(() => clock);
      vi.spyOn(internals, "sleep").mockImplementation(async (ms: number) => {
        waits.push(ms);
        clock += ms;
      });
      mockPost.mockRejectedValue(conflict({ code: "check_not_written_yet" }));
      await expect(
        client.confirmAction({
          action: "show_break_reminder",
          intervalKey: "ef".repeat(32),
          checkEventId: "evt-1",
          checkTimestamp: "2026-11-14T20:00:00Z",
          confirmationId: "c",
          source: "complyedge",
          shownAt: "2026-11-14T20:09:58Z",
          sessionId: "s",
        })
      ).rejects.toThrow(/409/);
      expect(waits).toEqual([1000, 1000]);
      expect(mockPost).toHaveBeenCalledTimes(3);
    });

    it("does not retry other errors", async () => {
      const err = Object.assign(new Error("422"), {
        response: { status: 422, data: { detail: { code: "action_not_asked" } } },
      });
      mockPost.mockRejectedValueOnce(err);
      await expect(
        client.confirmAction({
          action: "show_crisis_referral",
          checkEventId: "evt-1",
          checkTimestamp: "2026-11-14T20:00:00Z",
          confirmationId: "c",
          source: "complyedge",
          shownAt: "t",
          sessionId: "s",
        })
      ).rejects.toBe(err);
      expect(mockPost).toHaveBeenCalledTimes(1);
    });
  });

  describe("preserve: RFC 8785 canonical bytes", () => {
    const CONVO_A = [
      { role: "user", text: "café", sent_at: "2026-11-14T19:59:00.000Z" },
      { role: "assistant", text: "I hear you.\nCall 988.", sent_at: "2026-11-14T19:59:05.000Z" },
    ];
    // Same conversation: other key order, other whitespace, "e" + combining accent.
    const CONVO_B_JSON = `
[ { "sent_at" : "2026-11-14T19:59:00.000Z",  "text": "café", "role": "user" },
  {"text":"I hear you.\\nCall 988.","role":"assistant","sent_at":"2026-11-14T19:59:05.000Z"} ]
`;
    const EXPECTED =
      '[{"role":"user","sent_at":"2026-11-14T19:59:00.000Z","text":"café"},' +
      '{"role":"assistant","sent_at":"2026-11-14T19:59:05.000Z","text":"I hear you.\\nCall 988."}]';

    it("gives the same bytes for two differently formatted inputs", () => {
      const a = canonicalConversation(CONVO_A);
      const b = canonicalConversation(CONVO_B_JSON);
      expect(Buffer.from(a, "utf8").equals(Buffer.from(b, "utf8"))).toBe(true);
      expect(a).toBe(EXPECTED);
    });

    it("writes a Date with toISOString", () => {
      const out = canonicalConversation([
        { role: "user", text: "hi", sent_at: new Date("2026-11-14T19:59:00.123Z") },
      ]);
      expect(out).toBe('[{"role":"user","sent_at":"2026-11-14T19:59:00.123Z","text":"hi"}]');
    });

    it("refuses extra keys", () => {
      expect(() =>
        canonicalConversation([
          { role: "user", text: "hi", sent_at: "t", id: "1" } as unknown as {
            role: string;
            text: string;
            sent_at: string;
          },
        ])
      ).toThrow(/unexpected: id/);
    });

    it("sends the canonical bytes, whatever the input formatting", async () => {
      mockPost.mockResolvedValue({
        data: { event_id: "prs-1", timestamp: "2026-11-14T20:00:02Z", event_type: "preservation" },
      });
      const c = makeClient({ agentId: "pal", sessionId: "sess-1" });
      const base = {
        trigger: "parent_notified" as const,
        preservedAt: "2026-11-14T20:00:00Z",
        decidingSystemVersion: "pal-3",
      };
      const r = await c.preserve({ ...base, conversation: CONVO_A });
      await c.preserve({ ...base, conversation: CONVO_B_JSON });
      const [first, second] = mockPost.mock.calls.map((call) => call[1]);
      expect(mockPost.mock.calls[0][0]).toBe("/v1/companion/preservation");
      expect(typeof first).toBe("string");
      expect(first).toBe(second);
      expect(first).toContain(EXPECTED);
      expect(first).toBe(
        `{"agent_id":"pal","conversation":${EXPECTED},"deciding_system_version":"pal-3",` +
          `"preserved_at":"2026-11-14T20:00:00Z","session_id":"sess-1","trigger":"parent_notified"}`
      );
      expect(r).toEqual({
        eventId: "prs-1",
        timestamp: "2026-11-14T20:00:02Z",
        eventType: "preservation",
        accountDuties: [],
      });
    });

    it("returns California's account duties", async () => {
      mockPost.mockResolvedValue({
        data: {
          event_id: "prs-2",
          timestamp: "2026-11-14T20:00:02Z",
          event_type: "preservation",
          account_duties: ["notify_parent_if_practicable", "retain_account"],
        },
      });
      const r = await makeClient({ agentId: "pal", sessionId: "sess-1" }).preserve({
        trigger: "serious_self_harm",
        preservedAt: "2026-11-14T20:00:00Z",
        decidingSystemVersion: "pal-3",
        conversation: CONVO_A,
      });
      expect(r.accountDuties).toEqual(["notify_parent_if_practicable", "retain_account"]);
    });
  });
  // The API puts the companion fields in the 429 and 503 body (spec X4). They
  // used to stay unparsed on err.response.data, so an app that caught the
  // error could not show the crisis referral it was owed.
  describe("a refused check still carries what the law asks", () => {
    const detail = {
      error: "daily_limit_exceeded",
      message: "Daily limit reached.",
      ...COMPANION_FIELDS,
      companion_assessment: "not_assessed",
      companion_not_assessed_reason: "unavailable",
    };

    it.each([429, 503])("a %i keeps its required actions on the same error", async (status) => {
      const err = Object.assign(new Error(`Request failed with status code ${status}`), {
        response: { status, data: { detail } },
      });
      mockPost.mockRejectedValueOnce(err);
      const thrown = await client
        .check("I keep thinking about ending it.", {
          jurisdiction: "US-CA",
          direction: "prompt",
          useCase: "companion_chatbot",
          sessionId: "s-1",
        })
        .catch((e) => e);
      expect(thrown).toBe(err);
      expect(thrown.refusal.status).toBe(status);
      expect(thrown.refusal.requiredActions.map((a: { action: string }) => a.action)).toEqual(
        COMPANION_FIELDS.required_actions.map((a) => a.action)
      );
      expect(thrown.refusal.companionAssessment).toBe("not_assessed");
      expect(thrown.refusal.companionNotAssessedReason).toBe("unavailable");
      expect(checkRefusal(thrown)).toEqual(thrown.refusal);
    });

    it("a refusal without companion fields parses as empty", () => {
      const refusal = checkRefusal({ response: { status: 429, data: { detail: "Daily limit reached." } } });
      expect(refusal?.status).toBe(429);
      expect(refusal?.requiredActions).toEqual([]);
      expect(refusal?.companionAssessment).toBeNull();
    });

    it("an error with no HTTP answer has no refusal", () => {
      expect(checkRefusal(new Error("timeout"))).toBeNull();
    });
  });
});
