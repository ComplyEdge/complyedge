/**
 * ComplyEdge TypeScript SDK
 *
 * Runtime EU AI Act enforcement for AI agents.
 *
 * @example
 * ```typescript
 * import { ComplyEdgeClient } from "@complyedge/sdk";
 *
 * const ce = new ComplyEdgeClient({ apiKey: process.env.COMPLYEDGE_API_KEY! });
 * const result = await ce.check("Your AI prompt here");
 *
 * if (result.status === "violation") {
 *   console.log("Blocked:", result.violations);
 * }
 * ```
 */

export { ComplyEdgeClient } from "./client";
export { withCompliance, ComplianceError } from "./openai-middleware";
export type {
  ComplyEdgeConfig,
  ComplianceContext,
  ComplianceResult,
  ComplianceViolation,
  SeverityLevel,
  SensitivityResult,
  SensitivityDetection,
  PreDeploymentInput,
  PreDeploymentResult,
} from "./types";
