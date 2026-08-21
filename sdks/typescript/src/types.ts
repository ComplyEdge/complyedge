/**
 * ComplyEdge TypeScript SDK — Type definitions
 * Matches the Python SDK interfaces for cross-language consistency.
 */

export interface ComplianceContext {
  agentId?: string;
  jurisdiction?: string;
  userRole?: string;
  direction?: "prompt" | "output";
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
 * Result of POST /v1/check (the deterministic OPA enforcement path).
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
  evaluatedRules: string[];
  enginePath: string;
  opaLatencyMs?: number;
  auditLogged: boolean;
  /**
   * SHA-256 of the evaluated text as a bare hex digest, byte-identical to this
   * event's Article 12 audit entry. Binds the decision to its exact input
   * without a second call to the audit endpoint. The text is never stored.
   */
  textHash: string;
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
  baseUrl?: string;
  agentId?: string;
  jurisdiction?: string;
  timeout?: number;
}
