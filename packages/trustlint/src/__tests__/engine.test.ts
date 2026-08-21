import { describe, it, expect } from "vitest";
import * as path from "node:path";
import { TrustLintEngine } from "../engine.js";

const RULES_DIR = path.resolve(__dirname, "../../../../rules/regulations");

describe("TrustLintEngine", () => {
  it("loads rules from directory", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    expect(engine.rules.length).toBeGreaterThan(0);
  });

  it("each rule has required fields", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    for (const rule of engine.rules) {
      expect(rule.id).toBeTruthy();
      expect(rule.jurisdiction).toBeTruthy();
      expect(rule.severity).toBeTruthy();
      expect(rule.regexPatterns.length).toBeGreaterThan(0);
    }
  });

  it("returns clean result for benign text", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    const result = engine.check("Hello world, nothing to see here.");
    expect(result.clean).toBe(true);
    expect(result.violations).toHaveLength(0);
    expect(result.hasCritical).toBe(false);
  });

  it("detects TCPA SMS violation", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    const result = engine.check(
      "We will send SMS marketing texts to all users"
    );
    expect(result.clean).toBe(false);
    const tcpa = result.violations.find((v) => v.ruleId === "TCPA_SMS_OPTIN_001");
    expect(tcpa).toBeDefined();
    expect(tcpa!.severity).toBe("high");
    expect(tcpa!.jurisdiction).toBe("US");
  });

  it("detects EU AI Act social scoring violation", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    const result = engine.check(
      "The system uses a social credit score to determine access"
    );
    expect(result.clean).toBe(false);
    const ss = result.violations.find(
      (v) => v.ruleId === "EU_AI_ACT_ART5_SOCIAL_SCORING_001"
    );
    expect(ss).toBeDefined();
    expect(ss!.severity).toBe("critical");
  });

  it("filters by jurisdiction", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    const result = engine.check(
      "We will send SMS marketing texts and use social credit scoring",
      "EU"
    );
    // TCPA is US-only, should not appear
    const tcpa = result.violations.find((v) => v.ruleId === "TCPA_SMS_OPTIN_001");
    expect(tcpa).toBeUndefined();
  });

  it("hasCritical is true when critical violation found", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    const result = engine.check("subliminal manipulation of behavior");
    expect(result.hasCritical).toBe(true);
  });

  it("returns empty rules when no directory found", () => {
    const engine = new TrustLintEngine("/nonexistent/path");
    expect(engine.rules).toHaveLength(0);
  });

  it("rulesEvaluated reflects jurisdiction filter", () => {
    const engine = new TrustLintEngine(RULES_DIR);
    const allResult = engine.check("test");
    const euResult = engine.check("test", "EU");
    expect(euResult.rulesEvaluated).toBeLessThan(allResult.rulesEvaluated);
  });
});
