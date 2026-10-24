/**
 * `trustlint check` reads piped stdin, as the README shows and the Python CLI does.
 * Until 2026-10-19 the npm CLI answered "provide --text or a file path" and exited 2.
 */
import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { buildSync } from "esbuild";
import { describe, expect, it } from "vitest";

const PKG = path.resolve(__dirname, "../..");
const REPO = path.resolve(PKG, "../..");

describe("check from stdin", () => {
  it("lints piped text", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-cli-"));
    const out = path.join(root, "dist", "cli.cjs");
    buildSync({
      entryPoints: [path.join(PKG, "src", "cli.ts")],
      bundle: true,
      platform: "node",
      format: "cjs",
      outfile: out,
      logLevel: "silent",
    });
    // the CLI reads ../package.json for --version
    fs.copyFileSync(path.join(PKG, "package.json"), path.join(root, "package.json"));
    const r = spawnSync(
      process.execPath,
      [out, "--rules-dir", path.join(REPO, "rules", "regulations"), "check"],
      { input: "Deploy social credit score for citizens", encoding: "utf-8" }
    );
    fs.rmSync(root, { recursive: true, force: true });
    expect(r.stdout + r.stderr).toContain("EU_AI_ACT_ART5_SOCIAL_SCORING_001");
    expect(r.status).toBe(1);
  });
});
