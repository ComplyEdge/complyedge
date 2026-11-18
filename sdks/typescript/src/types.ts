/**
 * ComplyEdge TypeScript SDK: type definitions
 * Matches the Python SDK interfaces for cross-language consistency.
 */

export interface ComplianceContext {
  agentId?: string;
  jurisdiction?: string;
  /** Person the agent acts for. Recorded on the audit entry as `user_id`. */
  userId?: string;
  /** That person's role. Recorded as `user_role`. */
  userRole?: string;
  /** Conversation, run or job identifier. Recorded as `session_id`. */
  sessionId?: string;
  /**
   * "prompt": text going into the model (the user's message). "output": text
   * coming out (the bot's reply). "action": an action the AI system is about
   * to take. Sent only when given; the API then treats the text as "output".
   * Required when `useCase` is "companion_chatbot".
   */
  direction?: "prompt" | "output" | "action";
  /**
   * "companion_chatbot" turns on the companion chatbot laws for this check.
   * Such a check needs `direction` and `sessionId` (here or on the client) and
   * is refused before sending without them. Sent as `use_case`.
   */
  useCase?: string;
  /**
   * Companion checks with `direction` "output" only: the user's last message
   * before this reply, so the reply judge sees what the reply answers (for
   * example the user saying goodbye, or asking for a product). Context only;
   * never stored. Refused before sending on any other check. Sent as
   * `companion_user_message`, at most 12,000 characters.
   */
  companionUserMessage?: string;
  /**
   * Companion chatbot facts about this message, merged into the request's
   * `context` in the API's snake_case. A key you leave out means unknown.
   */
  companion?: CompanionContext;
  /**
   * Audit record fields only you know, written to the record as ADCR
   * fields (https://complyedge.io/producer-profile/). Sent as
   * `decision_context`, in the API's snake_case. Every key is optional.
   */
  decisionContext?: DecisionContext;
  /**
   * Evaluate without recording: POST /v1/sandbox/check. Same rules, same
   * tenant settings, same verdict as /v1/check; no audit entry, no usage,
   * no count against the plan's daily limit (own caps: 60 a minute, 1,000 a day). For trying cases, never for production traffic.
   */
  sandbox?: boolean;
}

/** `useCase` value that turns on the companion chatbot laws. */
export const COMPANION_USE_CASE = "companion_chatbot";

/** Sent as-is (snake_case) in the request's `context`. Every key is optional. */
export interface CompanionContext {
  age_status?:
    | "known_minor"
    | "child"
    | "reason_to_believe_minor"
    | "adult"
    | "treated_as_child"
    | "unknown";
  age_source?:
    | "os_signal"
    | "sb976_fallback"
    | "self_declared"
    | "operator_known"
    | "age_assurance"
    | "none";
  directed_to_minors?: boolean;
  uses_prior_personal_memory?: boolean;
  under_25?: boolean;
  parent_linked?: boolean;
  parent_changed_time_limit?: boolean;
  fda_regulated_device?: boolean;
  parent_changed_memory_default?: boolean;
  parent_changed_push_default?: boolean;
  child_16_plus?: boolean;
  memory_risk_guardrails?: boolean;
  parent_disabled_access?: boolean;
  /** How an ad in the reply was targeted (California § 21813). */
  ad_targeting?: "none" | "contextual" | "chat_personal_info" | "cross_context";
  ny_art47_excluded?: boolean;
  ny_art48_exempt_purpose?: "customer_service" | "efficiency_research_technical" | "internal";
  ny_art48_off_purpose_refused?: boolean;
  wa_excluded?: boolean;
  or_excluded?: boolean;
  is_session_start?: boolean;
  /** ISO 8601. */
  session_started_at?: string;
  minutes_today?: number;
  referrals_this_session?: number;
}

/** Something a companion check tells your app to do for this message. */
export interface RequiredAction {
  /** Action code, such as "show_crisis_referral" or "show_break_reminder". */
  action: string;
  ruleIds: string[];
  jurisdiction?: string;
  reasonCode?: string;
  /** When it was due, ISO 8601 UTC. */
  dueAt?: string;
  /** Names the due interval; send it back with confirmAction. */
  intervalKey?: string;
  /**
   * false for actions the law recommends but does not count as missed, and for
   * block_reply, disable_prior_personal_memory and disable_push_notifications
   * (applied in the response, never confirmed), and preserve_conversation
   * (recorded with preserve).
   */
  counted: boolean;
}

export interface ConfirmActionInput {
  /** Your own id for this confirmation. Sending it again records nothing new. */
  confirmationId: string;
  /** "complyedge": ComplyEdge's text was shown. "operator": your own text. */
  source: "complyedge" | "operator";
  /** When the user saw it. */
  shownAt: Date | string;
  /** Defaults to requiredAction.action. "minors_notice" needs no check. */
  action?: string;
  /** The required_actions entry this confirms. */
  requiredAction?: RequiredAction;
  /** The check result the entry came from: fills checkEventId and checkTimestamp. */
  check?: Pick<ComplianceResult, "eventId" | "timestamp">;
  /** Defaults to the client's sessionId. Required. */
  sessionId?: string;
  /** Defaults to requiredAction.jurisdiction. */
  jurisdiction?: string;
  /** Defaults to the entry's first rule id. */
  ruleId?: string;
  /** How the user reached the chatbot. */
  format?: "app" | "browser" | "other";
  /** Defaults to the client's agentId. */
  agentId?: string;
  decidingSystemVersion?: string;
  language?: string;
  checkEventId?: string;
  checkTimestamp?: string;
  intervalKey?: string;
}

export interface ConfirmActionResult {
  eventId: string;
  eventType: string;
  confirmKey?: string;
  /** True when this confirmation was already recorded: nothing new was written. */
  duplicate: boolean;
}

export interface ConversationMessage {
  role: string;
  text: string;
  /** A Date is written as Date.toISOString(); a string is kept as given. */
  sent_at: string | Date;
}

export interface PreserveInput {
  /** List of {role, text, sent_at}, or that list as a JSON string. */
  conversation: ConversationMessage[] | string;
  trigger: "parent_notified" | "child_died" | "serious_self_harm";
  preservedAt: Date | string;
  /** Version of the chatbot's AI system. */
  decidingSystemVersion: string;
  /** Defaults to the client's agentId. */
  agentId?: string;
  /** Defaults to the client's sessionId; sent when set. */
  sessionId?: string;
  /** Defaults to the client's userId; sent when set. */
  userId?: string;
}

export interface PreserveResult {
  eventId: string;
  timestamp?: string;
  eventType: string;
  /**
   * What California § 21812.5 still asks of you: "retain_account", and for a
   * death or serious self-harm "notify_parent_if_practicable".
   */
  accountDuties: string[];
}

export interface ProvisionRef {
  /** ELI in the Official Journal form; exactly one of `eli` or `url`. */
  eli?: string;
  url?: string;
  label: string;
}

/** Sent as-is (snake_case) in the request's `decision_context`. */
/**
 * ADCR facts about the decision that only you know. Optional on a check:
 * without it the check runs and is recorded, but the record does not meet ADCR
 * class Record. When sent, the API requires the first three fields. When
 * `subject` is set it also requires `decision_mode`, `notice` and
 * `explanation_inputs`.
 */
export interface DecisionContext {
  /** Version of the AI system that was checked, e.g. the model id. */
  deciding_system: { version: string };
  /** Reference to the purpose of the processing in your own records. */
  purpose_ref: string;
  /** Categories of personal data the decision used; [] when none. */
  data_categories: string[];
  /** Shared by the input and output checks of one exchange. Stored as a pseudonym. */
  correlation_id?: string;
  /** Stable reference to the person the decision is about. Stored as a pseudonym. */
  subject?: string;
  subject_is_employee?: boolean;
  works_agreement_ref?: string;
  legal_basis?: { provision: ProvisionRef; art22_exception?: "22(2)(a)" | "22(2)(b)" | "22(2)(c)" };
  /** Opaque locator of the checked text in your systems. Never the text. */
  source_ref?: string;
  /** How much the AI decided: solely_automated, decisive (a human relies strongly on the output), advisory or human, set by your documented process (ADCR RGT-01). Required when `subject` is set. */
  decision_mode?: "solely_automated" | "decisive" | "advisory" | "human";
  /** That the person was told the AI system was used, and when (ADCR RGT-02). Required when `subject` is set. */
  notice?: {
    given: boolean;
    /** RFC 3339 timestamp. */
    given_at: string;
    notice_ref: string;
    /** Required when the person is an employee. */
    workers_informed_at?: string;
  };
  /** References that let an explanation be produced later without the content (ADCR RGT-04). Required when `subject` is set. Codes and references, never values. */
  explanation_inputs?: {
    logic_ref: string;
    procedure_ref: string;
    main_factors: { code: string; importance: "high" | "medium" | "low" }[];
    data_categories: string[];
    risks_ref: string;
    main_elements: { outcome_code: string; effect_code: string; effective_date: string };
  };
  /** Trade-secret or third-party withhold of disclosure (ADCR RGT-05). */
  withheld?: boolean;
  /** Where withheld material can be produced; required when `withheld` is true. */
  escrow_ref?: string;
}

export type SeverityLevel =
  | "critical"
  | "high"
  | "medium"
  | "low"
  | "informational";

export interface ComplianceViolation {
  ruleId: string;
  ruleDescription: string;
  severity: SeverityLevel;
  reason: string;
  confidence: number;
  textExcerpt?: string;
}

/**
 * Result of POST /v1/check. Phrase rules run first. On a paid plan a clean
 * pass also runs an injection check when the month's model budget covers it.
 * Field names mirror the Python SDK's ComplianceResult.
 */
export interface ComplianceResult {
  eventId: string;
  allowed: boolean;
  /** Convenience mirror of `allowed`, for branch-on-string call sites. */
  status: "safe" | "violation";
  violations: ComplianceViolation[];
  latencyMs: number;
  bundleVersion: string;
  /**
   * SHA-256 digest of the rule set that decided, byte-identical to the audit
   * entry's `bundle_digest` and the ADCR record's `rule_set.digest`; the rule
   * set's page is https://complyedge.io/rule-set/<digest>/. Undefined on
   * responses from an API that does not return it.
   */
  bundleDigest?: string;
  evaluatedRules: string[];
  enginePath: string;
  opaLatencyMs?: number;
  auditLogged: boolean;
  /** True when the decision came from /v1/sandbox/check. Never evidence. */
  sandbox: boolean;
  /**
   * Keyed hash (HMAC-SHA-256 under the account's own key) of the evaluated
   * text as a bare hex digest, byte-identical to this event's Article 12 audit
   * entry. The key never leaves ComplyEdge, so it cannot be reversed by
   * hashing guesses; check a text against it with `verifyInput()`. The text is
   * never stored.
   */
  textHash: string;
  /**
   * "hmac-sha256-1" (HMAC over "commitment:" and the text). Undefined on
   * responses from an API deployed before the keyed hash (plain SHA-256).
   */
  textHashAlg?: string;
  /** UTC instant the evaluation started, matching the audit entry. */
  timestamp?: string;
  jurisdiction: string;
  /** Client-measured round trip, including network. */
  processingTimeMs: number;
  /**
   * Companion checks only: "assessed" or "not_assessed" (never a clean pass).
   * null on every other check and on an API that predates it.
   */
  companionAssessment: "assessed" | "not_assessed" | null;
  /** "plan", "budget", "unavailable", "no_direction" or "no_session"; else null. */
  companionNotAssessedReason: string | null;
  /** true when ComplyEdge could not work out the actions: apply your own protocol. */
  companionFallback: boolean;
  /** What your app must do for this message; [] when none or not a companion check. */
  requiredActions: RequiredAction[];
  /**
   * Periodic notices (break reminder, repeated not-human notice) this session
   * will owe that are not due yet. Show each one by its dueAt even when no
   * message arrives; when a later check lists it in requiredActions, confirm it
   * with the time it was shown. No intervalKey until then.
   */
  upcomingActions: RequiredAction[];
}

export interface SensitivityDetection {
  ruleId: string;
  severity: SeverityLevel;
  regulation: string;
  description: string;
  article?: string;
  remediation?: string;
}

/**
 * Result of POST /v1/sensitivity/detect (legacy TrustLint + LLM pipeline).
 * This path does NOT run OPA and does NOT write the Article 12 audit trail.
 */
export interface SensitivityResult {
  eventId: string;
  status: "safe" | "violation";
  detections: SensitivityDetection[];
  riskScore: number;
  jurisdiction: string;
  processingTimeMs: number;
}

export interface PreDeploymentInput {
  systemPrompt: string;
  modelConfig?: {
    provider?: string;
    modelId?: string;
    temperature?: number;
  };
  agentPipeline?: {
    tools?: string[];
    memory?: boolean;
    autonomyLevel?: string;
    humanOversight?: boolean;
  };
  jurisdiction?: string;
}

export interface PreDeploymentResult {
  complianceScore: number;
  riskTier: "unacceptable" | "high" | "limited" | "minimal";
  violations: Array<{
    ruleId: string;
    article: string;
    description: string;
    requiredAction: string;
  }>;
  requiredDisclosures: string[];
  euAiActCategory: string;
  estimatedDeadline: string;
}

export interface ComplyEdgeConfig {
  apiKey: string;
  /** Overrides region and key inference. Also settable via COMPLYEDGE_API_URL. */
  baseUrl?: string;
  /**
   * "us" | "eu". Defaults to the region encoded in the API key prefix
   * (`ce_eu_` -> EU, `ce_` -> US), else EU. Also settable via COMPLYEDGE_REGION.
   * This picks a host. It does not move the account.
   */
  region?: "us" | "eu";
  agentId?: string;
  jurisdiction?: string;
  timeout?: number;
  /** Default `userId` for every call; a per-call context value overrides it. */
  userId?: string;
  /** Default `userRole` for every call; a per-call context value overrides it. */
  userRole?: string;
  /** Default `sessionId` for every call; a per-call context value overrides it. */
  sessionId?: string;
  /**
   * Optional path to an append-only JSONL file of check linkage
   * (eventId, textHash, digests). Never stores the prompt. See ReceiptJournal.
   */
  receiptJournalPath?: string;
}

/** What a person asked for about a decision. */
export type AppealKind =
  | "human_intervention"
  | "express_view"
  | "contest"
  | "explanation"
  | "correction"
  | "review";

export interface AppealInput {
  /** The eventId ComplyEdge returned for the decision. */
  decisionId: string;
  /**
   * What the person asked for. human_intervention: a person should look at
   * it. express_view: give their side. contest: they dispute it.
   * explanation: how and why the AI decided. correction: data it used is
   * wrong. review: a review under another law, which sets its own deadline.
   * If unsure, human_intervention.
   */
  kind: AppealKind;
  /**
   * When the person asked, such as your ticket's created time. The one-month
   * deadline runs from here. Defaults to now. Retrying with the same value
   * returns the same request id.
   */
  requestedAt?: Date | string;
  /** Version of the AI system that decided. Read from the decision when omitted. */
  systemVersion?: string;
  /** The agent that decided. Read from the decision when omitted. */
  agentId?: string;
}

export interface AppealAnswerInput {
  /**
   * upheld: the decision stands. rectified: you corrected the decision or the
   * data it used. withdrawn: the person withdrew. refused: you will not act on
   * it (your reasons must tell the person they can complain to a supervisory
   * authority and go to court). extended: you told the person you need more
   * time, with the reasons; not the answer, so send the real one later.
   */
  outcome: "upheld" | "rectified" | "withdrawn" | "refused" | "extended";
  /** Reference to the reply you sent the person, such as "ticket:88213". Never the text itself. */
  statementRef: string;
  /** Who reviewed it, such as "staff:4471". An id, not an email address. Stored as a keyed pseudonym. */
  reviewer: string;
  /** When you answered. Defaults to now. */
  respondedAt?: Date | string;
  /** When the decision was corrected. Required when outcome is "rectified". */
  rectifiedAt?: Date | string;
}

export interface AppealAnswerResult {
  /** The answer's audit event id; null when this exact answer was already recorded. */
  eventId: string | null;
  requestId: string;
  /** True when the same answer had been sent before (a webhook retry): nothing new was written. */
  alreadyRecorded: boolean;
}

/** An answer or an extension as recorded. Times are as your app sent them; recordedAt is when ComplyEdge saved it. */
export interface AppealResponse {
  outcome: AppealAnswerInput["outcome"];
  respondedAt: string | null;
  statementRef: string | null;
  rectifiedAt: string | null;
  /** The keyed pseudonym, never the id you sent. */
  reviewer: string | null;
  recordedAt: string | null;
}

/** An extension as recorded, and whether it was sent within the first month. */
export interface AppealExtension extends AppealResponse {
  /** Sent within the first month, so it moves the due date. Null for kind "review", which has no GDPR month. */
  inTime: boolean | null;
}

/** One appeal with the decision it is about, as getAppeal returns it. */
export interface AppealDetail {
  appeal: Appeal;
  /** The decision record, or null when it is gone (older than your retention) or was never logged. */
  decision: Record<string, unknown> | null;
  decisionMissing: boolean;
}

/** One appeal as listAppeals and getAppeal return it. */
export interface Appeal {
  requestId: string;
  decisionId: string;
  kind: AppealKind;
  requestedAt: string;
  recordedAt: string | null;
  agentId: string | null;
  systemVersion: string | null;
  status: "open" | "answered";
  /** The answer recorded last. */
  answer: AppealResponse | null;
  /** The extension recorded last: the person was told the answer needs more time (GDPR Art. 12(3)). Not an answer. */
  extension: AppealResponse | null;
  /** Every answer, oldest first by respondedAt. answeredLate is judged on the first: a later correction does not change it. */
  answers: AppealResponse[];
  /** Every extension, oldest first. Any one sent within the first month counts for dueAt. */
  extensions: AppealExtension[];
  /** End of the last day to answer (UTC). Null for kind "review": that law sets its own date. */
  dueAt: string | null;
  /** The date the recorded answer was measured against (a refusal: one month). */
  answerDueAt: string | null;
  extendedInTime: boolean;
  /** No answer and the due date has passed. */
  late: boolean;
  answeredLate: boolean;
}

