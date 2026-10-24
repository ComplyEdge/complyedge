/**
 * Every bundled rule gives its findings a citation.
 *
 * Regression (2026-10-19): PCI_DSS_INPUT_001 and UNIVERSAL_PII_INPUT_001 rest
 * on no legal article (an industry standard and a detection control). They
 * carry provision_label but no citation, and the engine read only citation /
 * citations, so a card number came back with citation "" while the MCP copy
 * promised a citation on every finding.
 */

import { describe, expect, it } from "vitest";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { TrustLintEngine } from "../engine.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const CANONICAL = path.resolve(here, "../../../../rules/regulations");

describe("citation on every rule", () => {
  const engine = new TrustLintEngine(CANONICAL);

  it("loads the corpus", () => {
    expect(engine.rules.length).toBeGreaterThan(50);
  });

  it("gives every rule a non-empty citation", () => {
    const empty = engine.rules.filter((r) => !r.citation.trim()).map((r) => r.id);
    expect(empty).toEqual([]);
  });

  it("names the standard on a card-number finding", () => {
    const hit = engine
      .check("Charge card 4111111111111111 for the order.")
      .violations.find((v) => v.ruleId === "PCI_DSS_INPUT_001");
    expect(hit?.citation).toContain("PCI DSS");
    expect(hit?.citation).toContain("not law");
  });
});
