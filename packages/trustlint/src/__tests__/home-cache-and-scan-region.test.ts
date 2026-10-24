/**
 * The engine reads the rule set it ships, and scan calls the key's region.
 *
 * Until 2026-10-19 `trustlint rules update` installed a 2026-07 GitHub release
 * (64 rules, one withdrawn) into ~/.trustlint/rules and the engine read it before
 * the bundled rules, so every later check used it; and scan always called the EU
 * host, even with a US key.
 */
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TrustLintEngine } from "../engine.js";
import { scanUrl } from "../scan-url.js";

const REPO = path.resolve(__dirname, "../../../..");
const DECOY =
  "id: DECOY-HOME-001\ntitle: decoy\nseverity: high\njurisdiction: EU\nconditions:\n  - type: regex\n    value: decoy\n";

describe("home rules cache", () => {
  const savedHome = process.env.HOME;
  afterEach(() => {
    process.env.HOME = savedHome;
    vi.restoreAllMocks();
  });

  it("is not read", () => {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), "tl-home-"));
    fs.mkdirSync(path.join(home, ".trustlint", "rules"), { recursive: true });
    fs.writeFileSync(path.join(home, ".trustlint", "rules", "decoy.yaml"), DECOY);
    process.env.HOME = home;
    vi.spyOn(process, "cwd").mockReturnValue(REPO);
    const engine = new TrustLintEngine();
    const ids = engine.rules.map((r) => r.id);
    expect(ids).not.toContain("DECOY-HOME-001");
    expect(ids.length).toBeGreaterThan(50);
  });
});

describe("scanUrl", () => {
  it("routes by key prefix", () => {
    expect(scanUrl("ce_eu_abc")).toBe("https://eu.api.complyedge.io/v1/check");
    expect(scanUrl("ce_abc")).toBe("https://api.complyedge.io/v1/check");
  });
});
