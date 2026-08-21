/**
 * ComplyEdge TypeScript SDK — Client
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
} from "./types";

const DEFAULT_BASE_URL = "https://api.complyedge.io";
// Keep in sync with package.json. Hardcoding it here meant the User-Agent
// silently reported a stale version after every release bump, which is the
// one field support uses to tell which client a customer is actually on.
const SDK_VERSION = "0.2.0";

export class ComplyEdgeClient {
  private http: AxiosInstance;
  private agentId: string;
  private jurisdiction?: string;

  constructor(config: ComplyEdgeConfig) {
    const baseUrl = config.baseUrl || process.env.COMPLYEDGE_API_URL || DEFAULT_BASE_URL;

    this.agentId = config.agentId || "default";
    this.jurisdiction = config.jurisdiction;

    this.http = axios.create({
      baseURL: baseUrl.replace(/\/+$/, ""),
      timeout: config.timeout || 30_000,
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json",
        "User-Agent": `complyedge-typescript-sdk/${SDK_VERSION}`,
      },
    });
  }

  /**
   * Run a compliance check on text input.
   *
   * Calls POST /v1/check: the deterministic OPA hot path. A decision here is
   * evaluated against the Rego rule bundle, returns article-cited violations,
   * and is written to the Article 12 audit trail (`auditLogged`).
   */
  async check(text: string, context?: ComplianceContext): Promise<ComplianceResult> {
    const start = Date.now();
    const jurisdiction = context?.jurisdiction || this.jurisdiction || "EU";

    const response = await this.http.post("/v1/check", {
      text,
      agent_id: context?.agentId || this.agentId,
      jurisdiction,
      // Pass the caller's direction through untouched. This previously mapped
      // "prompt" to "input", a value the API's DirectionType enum does not
      // accept ("prompt" | "output"), so every input check 422'd and the
      // wrapped call threw. The SDK's own ComplianceContext type has always
      // declared the correct union; only this line disagreed with it.
      direction: context?.direction ?? "output",
      use_semantic_fallback: false,
      context: context?.userRole ? { user_role: context.userRole } : undefined,
    });

    const data = response.data;
    const processingTimeMs = Date.now() - start;
    const allowed = data.allowed !== false;

    return {
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
      evaluatedRules: data.evaluated_rules || [],
      enginePath: data.engine_path || "opa",
      opaLatencyMs: data.opa_latency_ms,
      auditLogged: data.audit_logged !== false,
      textHash: data.text_hash || "",
      timestamp: data.timestamp,
      jurisdiction,
      processingTimeMs,
    };
  }

  /**
   * Run proactive sensitivity detection on user input.
   *
   * Calls POST /v1/sensitivity/detect, which deliberately stays on the legacy
   * TrustLint + LLM pipeline. It does NOT run OPA and does NOT write the
   * Article 12 audit trail. Use `check()` for runtime EU AI Act enforcement.
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
      user_role: context?.userRole,
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
