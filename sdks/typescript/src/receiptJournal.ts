/**
 * Local append-only custody for check linkage.
 *
 * Stores eventId, textHash, bundleDigest, timestamps. Never the prompt or
 * answer. Pairing text still needs the caller's copy plus verifyInput.
 * Not an offline chain/anchor verifier.
 */

import { appendFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname } from "node:path";
import type { ComplianceResult } from "./types";

const FORBIDDEN = new Set([
  "text",
  "prompt",
  "output",
  "input",
  "content",
  "message",
  "body",
  "password",
  "api_key",
  "apiKey",
  "secret",
  "token",
]);

export interface ReceiptEntry {
  eventId: string;
  textHash: string;
  textHashAlg?: string;
  bundleDigest?: string;
  allowed: boolean;
  timestamp?: string;
  recordedAt: string;
  auditLogged: boolean;
  sandbox: boolean;
}

export class ReceiptJournal {
  readonly path: string;

  constructor(path: string) {
    this.path = path;
    const parent = dirname(path);
    if (parent && !existsSync(parent)) {
      mkdirSync(parent, { recursive: true });
    }
  }

  appendResult(
    result: ComplianceResult,
    opts: { skipSandbox?: boolean } = {}
  ): ReceiptEntry | undefined {
    const skipSandbox = opts.skipSandbox !== false;
    if (skipSandbox && result.sandbox) return undefined;
    if (!result.eventId) return undefined;
    const entry: ReceiptEntry = {
      eventId: result.eventId,
      textHash: result.textHash || "",
      textHashAlg: result.textHashAlg,
      bundleDigest: result.bundleDigest,
      allowed: result.allowed === true,
      timestamp: result.timestamp,
      recordedAt: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"),
      auditLogged: result.auditLogged === true,
      sandbox: result.sandbox === true,
    };
    this.append(entry);
    return entry;
  }

  append(entry: ReceiptEntry | Record<string, unknown>): void {
    const payload: Record<string, unknown> =
      "eventId" in entry && typeof (entry as ReceiptEntry).eventId === "string"
        ? { ...(entry as ReceiptEntry) }
        : { ...entry };

    for (const key of Object.keys(payload)) {
      if (FORBIDDEN.has(key) || FORBIDDEN.has(key.toLowerCase())) {
        throw new Error(`receipt journal refuses text/secret fields: ${key}`);
      }
    }
    if (!payload.eventId) {
      throw new Error("receipt journal requires eventId");
    }
    if (!payload.recordedAt) {
      payload.recordedAt = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
    }
    const keys = Object.keys(payload).sort();
    const ordered: Record<string, unknown> = {};
    for (const k of keys) ordered[k] = payload[k];
    appendFileSync(this.path, `${JSON.stringify(ordered)}\n`, "utf8");
  }

  get(eventId: string): ReceiptEntry | undefined {
    let found: ReceiptEntry | undefined;
    for (const row of this.entries()) {
      if (row.eventId === eventId) found = row;
    }
    return found;
  }

  latest(n = 1): ReceiptEntry[] {
    if (n < 1) return [];
    const rows = this.entries();
    return rows.slice(-n);
  }

  entries(): ReceiptEntry[] {
    if (!existsSync(this.path)) return [];
    const out: ReceiptEntry[] = [];
    for (const line of readFileSync(this.path, "utf8").split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        const row = JSON.parse(trimmed) as ReceiptEntry;
        if (row && typeof row.eventId === "string") out.push(row);
      } catch {
        /* skip corrupt */
      }
    }
    return out;
  }
}
