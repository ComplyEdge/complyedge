import * as fs from "node:fs";
import * as path from "node:path";
import { describe, expect, it } from "vitest";
import { TrustLintEngine } from "../engine.js";

const PACKAGED_RULES = path.resolve(__dirname, "../../dist/rules");

describe("npm package corpus", () => {
  it("copies the offline corpus into the publishable dist directory", () => {
    expect(fs.existsSync(PACKAGED_RULES)).toBe(true);
    expect(
      fs.existsSync(
        path.join(PACKAGED_RULES, "eu", "eu_ai_act_article5_social_scoring.yaml")
      )
    ).toBe(true);
  });

  it("loads bundled rules and detects social scoring without a repository cwd", () => {
    const engine = new TrustLintEngine(PACKAGED_RULES);
    const result = engine.check(
      "The system uses a social credit score to determine access."
    );

    expect(engine.rules.length).toBeGreaterThan(0);
    expect(
      result.violations.some(
        (violation) => violation.ruleId === "EU_AI_ACT_ART5_SOCIAL_SCORING_001"
      )
    ).toBe(true);
  });
});
