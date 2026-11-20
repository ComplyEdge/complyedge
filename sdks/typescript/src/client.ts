/**
 * ComplyEdge TypeScript SDK: Client
 */

import axios, { AxiosInstance } from "axios";
import type {
  ComplyEdgeConfig,
  ComplianceContext,
  ComplianceResult,
  ComplianceViolation,
  SensitivityDetection,
  SensitivityResult,
  PreDeploymentInput,
  PreDeploymentResult,
  AppealInput,
  AppealAnswerInput,
  AppealAnswerResult,
  Appeal,
  AppealKind,
  AppealDetail,
  AppealResponse,
  RequiredAction,
  ConfirmActionInput,
  ConfirmActionResult,
  ConversationMessage,
  PreserveInput,
  PreserveResult,
} from "./types";
import { COMPANION_USE_CASE } from "./types";
import { ReceiptJournal } from "./receiptJournal";

// ComplyEdge runs two regions. A tenant lives in exactly one of them.
// The key says which host to call. It does not move the account.
// `ce_eu_` -> EU (eu.api.complyedge.io). `ce_` -> US (api.complyedge.io).
// The region is chosen when the API key is created (EU preselected); changing
// it later goes through support and issues a new key.
// No key or an unknown prefix goes to EU.
// `baseUrl` and COMPLYEDGE_API_URL pick a host. They do not move the account.
export type Region = "us" | "eu";

export const REGION_BASE_URLS: Record<Region, string> = {
  us: "https://api.complyedge.io",
  eu: "https://eu.api.complyedge.io",
};

/** Region an API key was issued in, read from its prefix; undefined if unknown. */
export function regionFromApiKey(apiKey?: string): Region | undefined {
  if (!apiKey) return undefined;
  // Longest prefix first: `ce_eu_` also starts with `ce_`.
  if (apiKey.startsWith("ce_eu_")) return "eu";
  if (apiKey.startsWith("ce_")) return "us";
  return undefined;
}

/**
 * Pick the API host. Precedence, highest first:
 *   1. `baseUrl` option
 *   2. `COMPLYEDGE_API_URL` environment variable
 *   3. `region` option, else `COMPLYEDGE_REGION` environment variable
 *   4. the region encoded in the API key prefix (`ce_eu_` -> EU, `ce_` -> US)
 *   5. EU
 */
export function resolveBaseUrl(opts: {
  apiKey?: string;
  baseUrl?: string;
  region?: Region;
}): string {
  if (opts.baseUrl) return opts.baseUrl.replace(/\/+$/, "");
  const envUrl = process.env.COMPLYEDGE_API_URL;
  if (envUrl) return envUrl.replace(/\/+$/, "");
  const chosen = (opts.region || process.env.COMPLYEDGE_REGION || "").trim().toLowerCase();
  if (chosen) {
    if (!(chosen in REGION_BASE_URLS)) {
      throw new Error(
        `Unknown ComplyEdge region "${chosen}"; expected one of ${Object.keys(REGION_BASE_URLS).join(", ")}`
      );
    }
    return REGION_BASE_URLS[chosen as Region];
  }
  return REGION_BASE_URLS[regionFromApiKey(opts.apiKey) || "eu"];
}
// Keep in sync with package.json. Hardcoding it here meant the User-Agent
// silently reported a stale version after every release bump, which is the
// one field support uses to tell which client a customer is actually on.
const SDK_VERSION = "0.2.11";

/** The audit record's user attribution, in the API's field names. */
export interface AttributionFields {
  user_id?: string;
  user_role?: string;
  session_id?: string;
}

export class ComplyEdgeClient {
  private http: AxiosInstance;
  private agentId: string;
  private jurisdiction?: string;
  private userId?: string;
  private userRole?: string;
  private sessionId?: string;
  private receiptJournal?: ReceiptJournal;

  constructor(config: ComplyEdgeConfig) {
    const baseUrl = resolveBaseUrl({
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      region: config.region,
    });

    this.agentId = config.agentId || "default";
    this.jurisdiction = config.jurisdiction;
    this.userId = config.userId;
    this.userRole = config.userRole;
    this.sessionId = config.sessionId;
    if (config.receiptJournalPath) {
      this.receiptJournal = new ReceiptJournal(config.receiptJournalPath);
    }

    this.http = axios.create({
      baseURL: baseUrl,
      timeout: config.timeout || 30_000,
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json",
        "User-Agent": `complyedge-typescript-sdk/${SDK_VERSION}`,
      },
    });
    // Put the API's own words in the error message ("requested_at is in the
    // future", "No such review request."). Still the same AxiosError.
    // Optional chaining: test doubles of axios often carry no interceptors.
    this.http.interceptors?.response?.use(undefined, (err) => {
      const status = err?.response?.status;
      const detail = apiErrorDetail(err?.response?.data?.detail);
      if (status && detail) err.message = `API error (${status}): ${detail}`;
      return Promise.reject(err);
    });
  }

  /**
   * user_id / user_role / session_id for the audit record: the per-call
   * context wins, then the client defaults. Only userRole used to be sent, so
   * no SDK caller could fill the user and session columns of its records.
   * Undefined when there is nothing to send.
   */
  attribution(context?: ComplianceContext): AttributionFields | undefined {
    const fields: AttributionFields = {};
    const userId = context?.userId ?? this.userId;
    const userRole = context?.userRole ?? this.userRole;
    const sessionId = context?.sessionId ?? this.sessionId;
    if (userId) fields.user_id = userId;
    if (userRole) fields.user_role = userRole;
    if (sessionId) fields.session_id = sessionId;
    return Object.keys(fields).length ? fields : undefined;
  }

  /**
   * Run a compliance check on text input.
   *
   * Calls POST /v1/check. Phrase rules (Rego) run on every check. On a paid plan a
   * clean pass then runs an injection check when the month's model budget covers it, which can block. The wider review
   * runs only when you turn it on and that budget covers it. A rule block cites the article. The
   * decision is written to the audit trail (`auditLogged`).
   *
   * With `context.sandbox: true` it calls POST /v1/sandbox/check instead:
   * same verdict, nothing recorded (`auditLogged` false, `sandbox` true).
   */
  async check(text: string, context?: ComplianceContext): Promise<ComplianceResult> {
    const start = Date.now();
    const jurisdiction = context?.jurisdiction || this.jurisdiction || "EU";
    const path = context?.sandbox ? "/v1/sandbox/check" : "/v1/check";

    const attribution = this.attribution(context);
    const requestContext =
      context?.companion || attribution
        ? { ...(context?.companion ?? {}), ...(attribution ?? {}) }
        : undefined;
    if (
      context?.companionUserMessage !== undefined &&
      (context.useCase !== COMPANION_USE_CASE || context.direction !== "output")
    ) {
      throw new Error(
        "companionUserMessage is accepted only with useCase \"companion_chatbot\" and direction \"output\"; nothing was sent."
      );
    }
    if (context?.useCase === COMPANION_USE_CASE) {
      const missing: string[] = [];
      if (!context.direction) {
        missing.push("direction (\"prompt\" for the user's message, \"output\" for the bot's reply)");
      }
      if (!requestContext?.session_id) missing.push("sessionId");
      if (missing.length) {
        throw new Error(
          `A companion_chatbot check needs ${missing.join(" and ")}; nothing was sent.`
        );
      }
    }

    const response = await this.postCheck(path, {
      text,
      agent_id: context?.agentId || this.agentId,
      jurisdiction,
      // Pass the caller's direction through untouched, and only when given.
      // It used to default to "output", so a caller who forgot it had every
      // user message judged as a bot reply. The API still treats a missing
      // direction as "output" on ordinary checks.
      ...(context?.direction ? { direction: context.direction } : {}),
      ...(context?.useCase !== undefined ? { use_case: context.useCase } : {}),
      ...(context?.companionUserMessage !== undefined
        ? { companion_user_message: context.companionUserMessage }
        : {}),
      use_semantic_fallback: false,
      context: requestContext,
      decision_context: context?.decisionContext,
    });

    const data = response.data;
    const processingTimeMs = Date.now() - start;
    // Missing `allowed` is a block. `!== false` treated a truncated 200 as a pass.
    const allowed = data.allowed === true;

    const result: ComplianceResult = {
      eventId: data.event_id || "",
      allowed,
      status: allowed ? "safe" : "violation",
      violations: (data.violations || []).map((v: Record<string, unknown>) => ({
        ruleId: (v.rule_id as string) || "",
        ruleDescription: (v.rule_description as string) || "",
        severity: (v.severity as ComplianceViolation["severity"]) || "medium",
        reason: (v.reason as string) || "",
        confidence: (v.confidence as number) ?? 1.0,
        textExcerpt: v.text_excerpt as string | undefined,
      })),
      latencyMs: data.latency_ms || 0,
      bundleVersion: data.bundle_version || "",
      bundleDigest: data.bundle_digest ?? undefined,
      evaluatedRules: data.evaluated_rules || [],
      enginePath: data.engine_path || "opa",
      opaLatencyMs: data.opa_latency_ms,
      auditLogged: data.audit_logged === true,
      sandbox: data.sandbox === true,
      textHash: data.text_hash || "",
      textHashAlg: data.text_hash_alg ?? undefined,
      timestamp: data.timestamp,
      jurisdiction,
      processingTimeMs,
      // Absent on non-companion checks and on an older API: null / false / [].
      companionAssessment: data.companion_assessment ?? null,
      companionNotAssessedReason: data.companion_not_assessed_reason ?? null,
      companionFallback: data.companion_fallback === true,
      requiredActions: parseRequiredActions(data.required_actions),
      upcomingActions: parseRequiredActions(data.upcoming_actions),
    };
    this.receiptJournal?.appendResult(result);
    return result;
  }

  /**
   * POST a check. A refused check (daily cap 429, 503) is rethrown as the
   * same error, with `refusal` set when the API's body holds the companion
   * fields. They used to stay unparsed on `err.response.data`, so an app that
   * caught the error could not show the crisis referral it was owed.
   */
  private async postCheck(path: string, body: unknown) {
    try {
      return await this.http.post(path, body);
    } catch (err) {
      const refusal = checkRefusal(err);
      if (refusal && typeof err === "object" && err !== null) {
        (err as { refusal?: CheckRefusal }).refusal = refusal;
      }
      throw err;
    }
  }

  /**
   * Run proactive sensitivity detection on user input.
   *
   * Calls POST /v1/sensitivity/detect, which deliberately stays on the legacy
   * TrustLint + LLM pipeline. It does NOT run OPA. It does write an audit
   * record, attributed like check(). Use `check()` for the hosted check
   * against AI laws.
   */
  async detectSensitivity(
    text: string,
    context?: ComplianceContext
  ): Promise<SensitivityResult> {
    const start = Date.now();
    // "EU" matches the Python SDK and the server default. This read "US",
    // so the two SDKs enforced different rule sets for identical code.
    const jurisdiction = context?.jurisdiction || this.jurisdiction || "EU";

    const response = await this.http.post("/v1/sensitivity/detect", {
      input_text: text,
      agent_id: context?.agentId || this.agentId,
      jurisdiction,
      direction: context?.direction || "prompt",
      // The API reads attribution from `context` (SensitivityContext). A
      // top-level user_role was silently dropped by the request model.
      context: this.attribution(context),
    });

    const data = response.data;

    return {
      eventId: data.event_id || "",
      status: data.overall_risk_assessment === "safe" ? "safe" : "violation",
      detections: (data.detections || []).map((d: Record<string, unknown>) => ({
        ruleId: (d.rule_id as string) || "",
        severity: (d.severity as SensitivityDetection["severity"]) || "medium",
        regulation: (d.regulation as string) || "",
        description: (d.description as string) || "",
        article: d.article as string | undefined,
        remediation: d.remediation as string | undefined,
      })),
      riskScore: data.overall_risk_score || 0,
      jurisdiction,
      processingTimeMs: Date.now() - start,
    };
  }

  /**
   * True when the audit record `eventId` was a decision about exactly `text`.
   *
   * The record's textHash is keyed with the account's key, which never leaves
   * ComplyEdge, so the comparison runs server-side (POST /v1/audit/verify).
   * The text is used for that request only: not stored, not logged. False also
   * when the account's key was destroyed. An unknown eventId rejects (404).
   */
  async verifyInput(eventId: string, text: string): Promise<boolean> {
    const response = await this.http.post("/v1/audit/verify", { event_id: eventId, text });
    return response.data?.match === true;
  }

  /**
   * Record that a person asked about a decision (Enterprise plan). Returns the
   * request id: keep it on your support ticket and pass it to recordAnswer.
   * The agent and system version are read from the decision unless given.
   * Safe to retry with the same requestedAt: the request is recorded once and
   * the same id comes back. Calls POST /v1/audit/contest.
   */
  async recordAppeal(input: AppealInput): Promise<string> {
    const body: Record<string, unknown> = {
      decision_ref: input.decisionId,
      request_kind: input.kind,
      requested_at: isoUtc(input.requestedAt),
    };
    if (input.agentId) body.agent_id = input.agentId;
    if (input.systemVersion) body.deciding_system = { version: input.systemVersion };
    const response = await this.http.post("/v1/audit/contest", body);
    return String(response.data.event_id);
  }

  /**
   * Record your answer to an appeal by the id recordAppeal returned
   * (POST /v1/audit/reviews/{id}/answer). Sending the same answer twice, as a
   * webhook retry does, records it once.
   */
  async recordAnswer(requestId: string, answer: AppealAnswerInput): Promise<AppealAnswerResult> {
    const body: Record<string, string> = {
      review_outcome: answer.outcome,
      statement_ref: answer.statementRef,
      reviewer: answer.reviewer,
    };
    if (answer.respondedAt !== undefined) body.responded_at = isoUtc(answer.respondedAt);
    if (answer.rectifiedAt !== undefined) body.rectified_at = isoUtc(answer.rectifiedAt);
    const response = await this.http.post(
      `/v1/audit/reviews/${encodeURIComponent(requestId)}/answer`,
      body
    );
    const data = response.data ?? {};
    return {
      eventId: data.event_id ?? null,
      requestId: data.request_id ?? requestId,
      alreadyRecorded: data.already_recorded === true,
    };
  }

  /**
   * Appeals on your account, late ones first (GET /v1/audit/reviews).
   * status: "open" (no answer yet, oldest first), "answered" or "all".
   * Each has dueAt (end of the last day to answer; null for "review"),
   * late and answeredLate. Use it for a job that flags late appeals.
   */
  async listAppeals(status: "open" | "answered" | "all" = "open"): Promise<Appeal[]> {
    const response = await this.http.get("/v1/audit/reviews", { params: { status } });
    return ((response.data?.reviews ?? []) as RawAppeal[]).map(toAppeal);
  }

  /** One appeal by its request id, with the decision it is about (GET /v1/audit/reviews/{id}). */
  async getAppeal(requestId: string): Promise<AppealDetail> {
    const response = await this.http.get(`/v1/audit/reviews/${encodeURIComponent(requestId)}`);
    return {
      appeal: toAppeal(response.data.review as RawAppeal),
      decision: (response.data.decision as Record<string, unknown> | null) ?? null,
      decisionMissing: response.data.decision_missing === true,
    };
  }

  /**
   * Record that your app showed a companion notice (POST /v1/companion/action).
   * Pass `requiredAction` and `check` and the call fills action, checkEventId,
   * checkTimestamp, intervalKey, jurisdiction and ruleId (the entry's first
   * rule id) from them; any of those given explicitly wins.
   *
   * The check is recorded a moment after it returns. While it is not there
   * yet the API answers 409 check_not_written_yet; this call retries with
   * growing waits until 10 minutes after the check's timestamp, then throws.
   */
  async confirmAction(input: ConfirmActionInput): Promise<ConfirmActionResult> {
    const entry = input.requiredAction;
    const raw: Record<string, string | undefined> = {
      confirmation_id: input.confirmationId,
      action: input.action ?? entry?.action,
      source: input.source,
      shown_at: isoUtc(input.shownAt),
      session_id: input.sessionId ?? this.sessionId,
      agent_id: input.agentId ?? this.agentId,
      jurisdiction: input.jurisdiction ?? entry?.jurisdiction,
      rule_id: input.ruleId ?? entry?.ruleIds?.[0],
      format: input.format,
      deciding_system_version: input.decidingSystemVersion,
      language: input.language,
      check_event_id: input.checkEventId ?? input.check?.eventId,
      check_timestamp: input.checkTimestamp ?? input.check?.timestamp,
      interval_key: input.intervalKey ?? entry?.intervalKey,
    };
    const body: Record<string, string> = {};
    for (const [k, v] of Object.entries(raw)) if (v !== undefined && v !== "") body[k] = v;
    for (const key of ["action", "session_id"]) {
      if (!body[key]) throw new Error(`confirmAction needs ${key}; nothing was sent.`);
    }

    const deadline = body.check_timestamp
      ? Date.parse(body.check_timestamp) + CONFIRM_RETRY_WINDOW_MS
      : undefined;
    let delay = 1000;
    for (;;) {
      try {
        const response = await this.http.post("/v1/companion/action", body);
        const data = response.data ?? {};
        return {
          eventId: String(data.event_id),
          eventType: data.event_type ?? "notice",
          confirmKey: data.confirm_key ?? undefined,
          duplicate: data.duplicate === true,
        };
      } catch (err) {
        const res = (err as { response?: { status?: number; data?: unknown } }).response;
        if (res?.status !== 409 || errorCode(res.data) !== "check_not_written_yet") throw err;
        const remaining = deadline === undefined ? 0 : deadline - this.now();
        if (!(remaining > 0)) {
          throw new Error(
            "API error (409): check_not_written_yet; the check was not recorded within 10 minutes of its timestamp"
          );
        }
        await this.sleep(Math.min(delay, remaining));
        delay = Math.min(delay * 2, 30_000);
      }
    }
  }

  /**
   * Commit a conversation you must keep (POST /v1/companion/preservation).
   * ComplyEdge keeps a keyed hash of it, never its text. The conversation is
   * put in one canonical form first (see canonicalConversation), so the copy
   * you keep verifies later whatever its whitespace or key order.
   */
  async preserve(input: PreserveInput): Promise<PreserveResult> {
    const conversation = JSON.parse(canonicalConversation(input.conversation));
    const raw: Record<string, unknown> = {
      agent_id: input.agentId ?? this.agentId,
      conversation,
      deciding_system_version: input.decidingSystemVersion,
      preserved_at: isoUtc(input.preservedAt),
      session_id: input.sessionId ?? this.sessionId,
      trigger: input.trigger,
      user_id: input.userId ?? this.userId,
    };
    const body: Record<string, unknown> = {};
    for (const key of Object.keys(raw).sort()) {
      if (raw[key] !== undefined) body[key] = raw[key];
    }
    // Sent as a string so the conversation bytes on the wire are exactly the
    // canonical bytes: keys inserted in sorted order, so JSON.stringify writes
    // RFC 8785 for these string-only values.
    const response = await this.http.post("/v1/companion/preservation", JSON.stringify(body), {
      headers: { "Content-Type": "application/json" },
    });
    const data = response.data ?? {};
    return {
      eventId: String(data.event_id),
      timestamp: data.timestamp ?? undefined,
      eventType: data.event_type ?? "preservation",
      accountDuties: Array.isArray(data.account_duties) ? data.account_duties.map(String) : [],
    };
  }

  /** Waits between confirmation retries; replaced in tests. */
  protected sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /** Wall clock in ms; replaced in tests. */
  protected now(): number {
    return Date.now();
  }

  /**
   * Run a pre-deployment assessment on an AI system configuration.
   */
  async assessPreDeployment(input: PreDeploymentInput): Promise<PreDeploymentResult> {
    const response = await this.http.post("/v1/assessment/pre-deployment", {
      system_prompt: input.systemPrompt,
      model_config: input.modelConfig
        ? {
            provider: input.modelConfig.provider,
            model_id: input.modelConfig.modelId,
            temperature: input.modelConfig.temperature,
          }
        : undefined,
      agent_pipeline: input.agentPipeline
        ? {
            tools: input.agentPipeline.tools,
            memory: input.agentPipeline.memory,
            autonomy_level: input.agentPipeline.autonomyLevel,
            human_oversight: input.agentPipeline.humanOversight,
          }
        : undefined,
      jurisdiction: input.jurisdiction || "EU",
    });

    const data = response.data;
    return {
      complianceScore: data.compliance_score,
      riskTier: data.risk_tier,
      violations: (data.violations || []).map((v: Record<string, unknown>) => ({
        ruleId: v.rule_id as string,
        article: v.article as string,
        description: v.description as string,
        requiredAction: v.required_action as string,
      })),
      requiredDisclosures: data.required_disclosures || [],
      euAiActCategory: data.eu_ai_act_category || "",
      estimatedDeadline: data.estimated_deadline || "",
    };
  }
}

/** How long after a check's timestamp a confirmation keeps retrying a 409. */
const CONFIRM_RETRY_WINDOW_MS = 10 * 60 * 1000;

function parseRequiredActions(value: unknown): RequiredAction[] {
  if (!Array.isArray(value)) return [];
  const out: RequiredAction[] = [];
  for (const e of value as Record<string, unknown>[]) {
    if (!e || typeof e !== "object" || !e.action) continue;
    out.push({
      action: String(e.action),
      ruleIds: Array.isArray(e.rule_ids) ? e.rule_ids.map(String) : [],
      jurisdiction: (e.jurisdiction as string | undefined) ?? undefined,
      reasonCode: (e.reason_code as string | undefined) ?? undefined,
      dueAt: (e.due_at as string | undefined) ?? undefined,
      intervalKey: (e.interval_key as string | undefined) ?? undefined,
      counted: e.counted === true,
    });
  }
  return out;
}

/** The API's error code, at the top level or under FastAPI's `detail`. */
function errorCode(data: unknown): string | undefined {
  if (!data || typeof data !== "object") return undefined;
  const d = data as Record<string, unknown>;
  if (typeof d.code === "string") return d.code;
  const detail = d.detail as Record<string, unknown> | undefined;
  if (detail && typeof detail === "object") {
    const code = detail.code ?? detail.error;
    return typeof code === "string" ? code : undefined;
  }
  return undefined;
}

const CONVERSATION_KEYS = ["role", "sent_at", "text"];

/**
 * The conversation in the one form ComplyEdge commits to: a JSON array of
 * {role, text, sent_at}, text in Unicode NFC, serialised by RFC 8785 (keys
 * sorted, no insignificant whitespace; JSON.stringify's string escaping is
 * RFC 8785's). Accepts the list or a JSON string; whitespace, key order and
 * Unicode composition in the input do not change the result. Any key other
 * than role, text and sent_at is refused rather than dropped.
 */
export function canonicalConversation(conversation: ConversationMessage[] | string): string {
  const list: unknown = typeof conversation === "string" ? JSON.parse(conversation) : conversation;
  if (!Array.isArray(list)) throw new Error("conversation must be a list of {role, text, sent_at}");
  const entries = list.map((m: unknown, i: number) => {
    if (!m || typeof m !== "object" || Array.isArray(m)) {
      throw new Error(`conversation[${i}] must be an object`);
    }
    const msg = m as Record<string, unknown>;
    const extra = Object.keys(msg).filter((k) => !CONVERSATION_KEYS.includes(k)).sort();
    const missing = CONVERSATION_KEYS.filter((k) => !(k in msg));
    if (extra.length || missing.length) {
      throw new Error(
        `conversation[${i}] must have exactly role, text and sent_at` +
          (extra.length ? `; unexpected: ${extra.join(", ")}` : "") +
          (missing.length ? `; missing: ${missing.join(", ")}` : "")
      );
    }
    const sentAt = msg.sent_at instanceof Date ? msg.sent_at.toISOString() : msg.sent_at;
    for (const [key, val] of [["role", msg.role], ["text", msg.text], ["sent_at", sentAt]]) {
      if (typeof val !== "string") throw new Error(`conversation[${i}].${key} must be a string`);
    }
    // Insertion order role < sent_at < text is the sorted order.
    return { role: msg.role, sent_at: sentAt, text: (msg.text as string).normalize("NFC") };
  });
  return JSON.stringify(entries);
}

/** An ISO 8601 UTC stamp; now when value is undefined. */
function isoUtc(value?: Date | string): string {
  if (value === undefined) return new Date().toISOString();
  return typeof value === "string" ? value : value.toISOString();
}

/**
 * What a refused check still says. Read it from a caught error with
 * `checkRefusal(err)`, or from `err.refusal` on an error thrown by `check()`.
 */
export interface CheckRefusal {
  /** HTTP status of the refusal, for example 429 or 503. */
  status: number;
  /** The API's parsed JSON body. */
  body: unknown;
  companionAssessment: string | null;
  companionNotAssessedReason: string | null;
  companionFallback: boolean;
  /** What the law asks for this message; empty when the body names none. */
  requiredActions: RequiredAction[];
  upcomingActions: RequiredAction[];
}

/**
 * The refusal carried by an error from `check()`, or null when the error is
 * not an HTTP answer. A refused companion check (daily cap, service
 * unavailable) still lists `requiredActions`: show them.
 */
export function checkRefusal(err: unknown): CheckRefusal | null {
  const response = (err as { response?: { status?: unknown; data?: unknown } } | null)?.response;
  if (!response || typeof response.status !== "number") return null;
  const raw = (response.data as { detail?: unknown } | null | undefined)?.detail;
  const detail = (raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}) as Record<
    string,
    unknown
  >;
  return {
    status: response.status,
    body: response.data,
    companionAssessment: (detail.companion_assessment as string | undefined) ?? null,
    companionNotAssessedReason:
      (detail.companion_not_assessed_reason as string | undefined) ?? null,
    companionFallback: detail.companion_fallback === true,
    requiredActions: parseRequiredActions(detail.required_actions),
    upcomingActions: parseRequiredActions(detail.upcoming_actions),
  };
}

/** The API's error detail as one line: a message, or each field and its problem. */
function apiErrorDetail(detail: unknown): string | null {
  if (!detail) return null;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    return (
      detail
        .map((e: { loc?: unknown[]; msg?: string }) =>
          `${(e.loc ?? []).slice(1).join(".") || "body"}: ${e.msg ?? ""}`
        )
        .join("; ") || null
    );
  }
  const msg = (detail as { message?: unknown }).message;
  return typeof msg === "string" ? msg : JSON.stringify(detail);
}

type RawAnswer = {
  responded_at?: string;
  review_outcome?: string;
  statement_ref?: string;
  rectified_at?: string;
  reviewer?: string;
  recorded_at?: string;
} | null;

type RawAppeal = {
  request_id: string;
  decision_ref: string;
  request_kind: string;
  requested_at: string;
  recorded_at?: string;
  agent_id?: string;
  deciding_system_version?: string;
  status: "open" | "answered";
  answer: RawAnswer;
  extension?: RawAnswer;
  answers?: RawAnswer[];
  extensions?: (RawAnswer & { in_time?: boolean | null })[];
  due_at?: string | null;
  answer_due_at?: string | null;
  extended_in_time?: boolean;
  late?: boolean;
  answered_late?: boolean;
};

function toAnswer(a: RawAnswer | undefined): AppealResponse | null {
  if (!a) return null;
  return {
    outcome: a.review_outcome as AppealAnswerInput["outcome"],
    respondedAt: a.responded_at ?? null,
    statementRef: a.statement_ref ?? null,
    rectifiedAt: a.rectified_at ?? null,
    reviewer: a.reviewer ?? null,
    recordedAt: a.recorded_at ?? null,
  };
}

function toAppeal(r: RawAppeal): Appeal {
  return {
    requestId: r.request_id,
    decisionId: r.decision_ref,
    kind: r.request_kind as AppealKind,
    requestedAt: r.requested_at,
    recordedAt: r.recorded_at ?? null,
    agentId: r.agent_id ?? null,
    systemVersion: r.deciding_system_version ?? null,
    status: r.status,
    answer: toAnswer(r.answer),
    extension: toAnswer(r.extension),
    // An API older than these lists returns only the newest answer and extension.
    answers: (r.answers ?? (r.answer ? [r.answer] : [])).map((a) => toAnswer(a) as AppealResponse),
    extensions: (r.extensions ?? (r.extension ? [r.extension] : [])).map((e) => ({
      ...(toAnswer(e) as AppealResponse),
      inTime: (e as { in_time?: boolean | null }).in_time ?? null,
    })),
    dueAt: r.due_at ?? null,
    answerDueAt: r.answer_due_at ?? null,
    extendedInTime: r.extended_in_time === true,
    late: r.late === true,
    answeredLate: r.answered_late === true,
  };
}
