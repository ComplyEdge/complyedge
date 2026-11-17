import { describe, it, expect, vi, beforeEach } from "vitest";
import { ComplyEdgeClient } from "../client";

// One axios double that records the error interceptor, so the test can run the
// real rejection path the client installs.
let onError: ((err: unknown) => Promise<never>) | undefined;
const mockPost = vi.fn();
const mockGet = vi.fn();

vi.mock("axios", () => ({
  default: {
    create: vi.fn(() => ({
      post: mockPost,
      get: mockGet,
      interceptors: {
        response: {
          use: (_ok: unknown, err: (e: unknown) => Promise<never>) => {
            onError = err;
          },
        },
      },
    })),
  },
}));

const client = () => new ComplyEdgeClient({ apiKey: "k", baseUrl: "https://example.test" });

describe("appeals", () => {
  beforeEach(() => {
    mockPost.mockReset();
    mockGet.mockReset();
  });

  it("recordAppeal needs only the decision id and the kind; the API reads the rest from the decision", async () => {
    mockPost.mockResolvedValue({ data: { event_id: "req-1", already_recorded: false } });
    await expect(client().recordAppeal({ decisionId: "dec-1", kind: "contest" })).resolves.toBe("req-1");
    const [path, body] = mockPost.mock.calls[0];
    expect(path).toBe("/v1/audit/contest");
    expect(body).toMatchObject({ decision_ref: "dec-1", request_kind: "contest" });
    expect(body).not.toHaveProperty("agent_id");
    expect(body).not.toHaveProperty("deciding_system");
    expect(typeof body.requested_at).toBe("string");
  });

  it("listAppeals reads open appeals with the API's due dates", async () => {
    mockGet.mockResolvedValue({
      data: {
        status: "open",
        count: 1,
        reviews: [
          {
            request_id: "req-1",
            decision_ref: "dec-1",
            request_kind: "human_intervention",
            requested_at: "2026-11-13T08:44:00Z",
            agent_id: "agent-hr",
            deciding_system_version: "2026.10.1",
            status: "open",
            answer: null,
            due_at: "2026-12-14T23:59:59Z",
            answer_due_at: "2026-12-14T23:59:59Z",
            extended_in_time: false,
            late: false,
            answered_late: false,
          },
        ],
      },
    });
    const [a] = await client().listAppeals();
    expect(mockGet).toHaveBeenCalledWith("/v1/audit/reviews", { params: { status: "open" } });
    expect(a).toMatchObject({
      requestId: "req-1",
      decisionId: "dec-1",
      kind: "human_intervention",
      dueAt: "2026-12-14T23:59:59Z",
      late: false,
      answer: null,
    });
  });

  it("returns every answer and extension, oldest first, with the extension's in-time flag", async () => {
    const upheld = { responded_at: "2026-11-20T10:00:00Z", review_outcome: "upheld", statement_ref: "ticket:1", reviewer: "p1" };
    const rectified = { responded_at: "2026-12-01T10:00:00Z", review_outcome: "rectified", statement_ref: "ticket:2", reviewer: "p1", rectified_at: "2026-12-01T10:00:00Z" };
    const extended = { responded_at: "2026-11-15T10:00:00Z", review_outcome: "extended", statement_ref: "ticket:0", reviewer: "p1" };
    mockGet.mockResolvedValue({
      data: {
        reviews: [
          {
            request_id: "req-1", decision_ref: "dec-1", request_kind: "contest", requested_at: "2026-11-13T08:44:00Z",
            status: "answered", answer: rectified, extension: extended,
            answers: [upheld, rectified], extensions: [{ ...extended, in_time: true }],
            due_at: "2027-02-15T23:59:59Z", extended_in_time: true, late: false, answered_late: false,
          },
        ],
      },
    });
    const [a] = await client().listAppeals("all");
    expect(a.answers.map((x) => x.outcome)).toEqual(["upheld", "rectified"]);
    expect(a.answer?.outcome).toBe("rectified");
    expect(a.extensions).toEqual([expect.objectContaining({ outcome: "extended", inTime: true, statementRef: "ticket:0" })]);
  });

  it("an API without the lists gives the newest answer and extension as one-item lists", async () => {
    const upheld = { responded_at: "2026-11-20T10:00:00Z", review_outcome: "upheld", statement_ref: "ticket:1", reviewer: "p1" };
    mockGet.mockResolvedValue({
      data: { reviews: [{ request_id: "r", decision_ref: "d", request_kind: "contest", requested_at: "x", status: "answered", answer: upheld }] },
    });
    const [a] = await client().listAppeals("all");
    expect(a.answers.map((x) => x.outcome)).toEqual(["upheld"]);
    expect(a.extensions).toEqual([]);
  });

  it("getAppeal reads one appeal by its escaped id, with its decision, as the Python SDK does", async () => {
    mockGet.mockResolvedValue({
      data: {
        review: { request_id: "req/1", decision_ref: "d", request_kind: "review", requested_at: "x", status: "open", due_at: null },
        decision: { event_id: "d", allowed: false },
        decision_missing: false,
      },
    });
    const { appeal, decision, decisionMissing } = await client().getAppeal("req/1");
    expect(mockGet).toHaveBeenCalledWith("/v1/audit/reviews/req%2F1");
    expect(appeal.dueAt).toBeNull();
    expect(decision).toEqual({ event_id: "d", allowed: false });
    expect(decisionMissing).toBe(false);
  });

  it("puts the API's own message in the error", async () => {
    client();
    const err = { message: "Request failed with status code 422", response: { status: 422, data: { detail: { code: "decision_facts_missing", message: "Send agent_id and deciding_system.version: the decision was not found on your account." } } } };
    await expect(onError!(err)).rejects.toMatchObject({
      message: "API error (422): Send agent_id and deciding_system.version: the decision was not found on your account.",
    });
    const field = { message: "x", response: { status: 422, data: { detail: [{ loc: ["body", "request_kind"], msg: "Input should be 'contest'" }] } } };
    await expect(onError!(field)).rejects.toMatchObject({ message: "API error (422): request_kind: Input should be 'contest'" });
  });
});
