/**
 * The README must describe the SDK as it is: the engine paths the API can
 * return, the wrong_region body shape, and the decisionContext option.
 */
import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const README = readFileSync(join(__dirname, "..", "..", "README.md"), "utf-8");

describe("TypeScript SDK README", () => {
  it("lists every engine path", () => {
    for (const path of ["opa", "llm", "hybrid", "fallback_block", "trustlint"]) {
      expect(README).toContain(`\`${path}\``);
    }
  });

  it("shows the wrong_region body nested under detail", () => {
    expect(README).toMatch(/"detail"\s*:\s*\{\s*"error"\s*:\s*"wrong_region"/);
  });

  it("documents decisionContext on check and on the middleware", () => {
    expect(README).toContain("decisionContext");
    expect(README).toMatch(/withCompliance\([\s\S]*?decisionContext[\s\S]*?\n\);/);
  });

  it("carries no em dash", () => {
    expect(README.includes(String.fromCharCode(0x2014))).toBe(false);
  });
});
