/**
 * ComplyEdge TypeScript SDK
 *
 * The evidence AI laws ask for, collected on every AI call.
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

export {
  ComplyEdgeClient,
  REGION_BASE_URLS,
  regionFromApiKey,
  resolveBaseUrl,
} from "./client";
export type { Region, AttributionFields } from "./client";
export { ReceiptJournal } from "./receiptJournal";
export type { ReceiptEntry } from "./receiptJournal";
export { withCompliance, ComplianceError } from "./openai-middleware";
export { COMPANION_USE_CASE } from "./types";
export { canonicalConversation } from "./client";
export type {
  CompanionContext,
  RequiredAction,
  ConfirmActionInput,
  ConfirmActionResult,
  ConversationMessage,
  PreserveInput,
  PreserveResult,
  ComplyEdgeConfig,
  ComplianceContext,
  ComplianceResult,
  DecisionContext,
  ProvisionRef,
  ComplianceViolation,
  SeverityLevel,
  SensitivityResult,
  SensitivityDetection,
  PreDeploymentInput,
  PreDeploymentResult,
  AppealKind,
  AppealInput,
  AppealAnswerInput,
  AppealAnswerResult,
  Appeal,
  AppealDetail,
  AppealExtension,
  AppealResponse,
} from "./types";
