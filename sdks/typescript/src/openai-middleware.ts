/**
 * ComplyEdge OpenAI Middleware
 *
 * Wraps an OpenAI client to run compliance checks on messages
 * before they are sent to the model.
 *
 * Usage:
 *   import OpenAI from "openai";
 *   import { ComplyEdgeClient } from "@complyedge/sdk";
 *   import { withCompliance } from "@complyedge/sdk/openai-middleware";
 *
 *   const ce = new ComplyEdgeClient({ apiKey: "..." });
 *   const openai = withCompliance(new OpenAI(), ce);
 *   // Now openai.chat.completions.create() runs compliance checks automatically
 */

import type { ComplyEdgeClient } from "./client";
import type { ComplianceViolation } from "./types";

export class ComplianceError extends Error {
  public violations: ComplianceViolation[];

  constructor(message: string, violations: ComplianceViolation[]) {
    super(message);
    this.name = "ComplianceError";
    this.violations = violations;
  }
}

/**
 * Wrap an OpenAI client with ComplyEdge compliance checks.
 * The returned object proxies chat.completions.create() to check
 * user messages before sending to OpenAI.
 */
export function withCompliance<T extends Record<string, unknown>>(
  openaiClient: T,
  ceClient: ComplyEdgeClient,
  options?: {
    checkInput?: boolean;
    checkOutput?: boolean;
    jurisdiction?: string;
    blockOnViolation?: boolean;
  }
): T {
  const opts = {
    checkInput: true,
    checkOutput: false,
    blockOnViolation: true,
    ...options,
  };

  const chat = openaiClient.chat as Record<string, unknown> | undefined;
  if (!chat || !chat.completions) {
    return openaiClient; // Not an OpenAI-shaped client, return as-is
  }

  const completions = chat.completions as Record<string, unknown>;
  const originalCreate = completions.create as (...args: unknown[]) => Promise<unknown>;

  if (typeof originalCreate !== "function") {
    return openaiClient;
  }

  completions.create = async function (...args: unknown[]) {
    const params = args[0] as Record<string, unknown> | undefined;

    if (opts.checkInput && params?.messages) {
      const messages = params.messages as Array<{ role: string; content: unknown }>;
      // Check EVERY user turn, not just the last one. A violation in an earlier
      // message is still sent to the model verbatim, so checking only the tail
      // left the majority of a multi-turn conversation unenforced.
      for (const message of messages) {
        if (message.role !== "user") continue;
        for (const text of extractText(message.content)) {
          const result = await ceClient.check(text, {
            direction: "prompt",
            jurisdiction: opts.jurisdiction,
          });
          if (!result.allowed && opts.blockOnViolation) {
            throw new ComplianceError(
              `Compliance violation detected: ${result.violations.map((v) => v.ruleId).join(", ")}`,
              result.violations
            );
          }
        }
      }
    }

    const response = await originalCreate.apply(this, args);

    if (opts.checkOutput) {
      // Previously declared in the options type and never read, so the README's
      // "runs compliance checks automatically" was half true: inputs were
      // checked, model output never was, silently.
      for (const text of extractCompletionText(response)) {
        const result = await ceClient.check(text, {
          direction: "output",
          jurisdiction: opts.jurisdiction,
        });
        if (!result.allowed && opts.blockOnViolation) {
          throw new ComplianceError(
            `Compliance violation in model output: ${result.violations.map((v) => v.ruleId).join(", ")}`,
            result.violations
          );
        }
      }
    }

    return response;
  };

  return openaiClient;
}

/**
 * Pull checkable strings out of a message `content` field.
 *
 * OpenAI accepts either a plain string or an array of typed content parts.
 * The array form was previously passed to the API as a non-string and 422'd,
 * so multimodal callers could not use the middleware at all.
 */
function extractText(content: unknown): string[] {
  if (typeof content === "string") {
    return content.trim() ? [content] : [];
  }
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        const p = part as Record<string, unknown> | null;
        return p && typeof p.text === "string" ? p.text : "";
      })
      .filter((t) => t.trim().length > 0);
  }
  return [];
}

/** Pull assistant message text out of a chat completion response. */
function extractCompletionText(response: unknown): string[] {
  const r = response as { choices?: Array<{ message?: { content?: unknown } }> } | null;
  if (!r?.choices) return [];
  return r.choices.flatMap((choice) => extractText(choice?.message?.content));
}
