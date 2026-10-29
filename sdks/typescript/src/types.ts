/**
 * ComplyEdge TypeScript SDK — Type definitions
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
  /** "action": an action the AI system is about to take. */
  direction?: "prompt" | "output" | "action";
  /**
   * Audit record fields only you know, written to the record as ADCR 0.1.0
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

export interface ProvisionRef {
  /** ELI in the Official Journal form; exactly one of `eli` or `url`. */
  eli?: string;
  url?: string;
  label: string;
}

/** Sent as-is (snake_case) in the request's `decision_context`. */
/**
 * ADCR 0.1.0 facts about the decision that only you know. Optional on a check:
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
  /** ADCR RGT-01; required when `subject` is set. */
  decision_mode?: "solely_automated" | "decisive" | "advisory" | "human";
  /** ADCR RGT-02; required when `subject` is set. */
  notice?: {
    given: boolean;
    /** RFC 3339 timestamp. */
    given_at: string;
    notice_ref: string;
    /** Required when the person is an employee. */
    workers_informed_at?: string;
  };
  /** ADCR RGT-04; required when `subject` is set. Codes and references, never values. */
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
