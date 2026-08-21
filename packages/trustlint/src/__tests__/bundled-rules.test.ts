/**
 * The npm package must ship the rule corpus, and ship only the corpus.
 *
 * Two incidents shape these assertions:
 *
 * 1. `npm install trustlint` used to land a linter with no rules at all. The
 *    Python wheel bundles the corpus via package_data; the npm package shipped
 *    ["dist","README.md"] and nothing else, so on a clean machine the CLI
 *    printed "No rules loaded" and exited 2. Verified only after redirecting
 *    HOME — a local ~/.trustlint/rules had been making it look healthy.
 *
 * 2. A recursive copy of rules/regulations/ pulls in `.complyedge-public`, an
 *    internal export-gate marker whose text cites an internal planning card.
 *    Publishing it would put an internal planning identifier on a public
 *    surface. The Python MANIFEST has always filtered to *.yaml/*.yml; the npm
 *    bundler must too.
 *
 * These mirror tests/unit/test_trustlint_bundle_is_fresh.py, which guards the
 * same property on the Python side.
 */

import { describe, expect, it } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.resolve(here, "../..");
const CANONICAL = path.resolve(packageRoot, "../../rules/regulations");
const BUNDLED = path.resolve(packageRoot, "dist/rules");

function walk(dir: string): string[] {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const full = path.join(dir, e.name);
    return e.isDirectory() ? walk(full) : [full];
  });
}

const relYaml = (root: string) =>
  walk(root)
    .filter((p) => p.endsWith(".yaml") || p.endsWith(".yml"))
    .map((p) => path.relative(root, p))
    .sort();

describe("bundled rule corpus", () => {
  it("canonical corpus exists", () => {
    expect(relYaml(CANONICAL).length).toBeGreaterThan(0);
  });

  // Skipped rather than failed when dist/ has not been built: `npm run test`
  // is run standalone in dev, and the bundle is a build output.
  const built = fs.existsSync(BUNDLED);
  const whenBuilt = built ? it : it.skip;

  whenBuilt("ships every canonical rule file, exactly", () => {
    expect(relYaml(BUNDLED)).toEqual(relYaml(CANONICAL));
  });

  whenBuilt("ships ONLY rule files — no internal markers, no docs", () => {
    const strays = walk(BUNDLED).filter(
      (p) => !p.endsWith(".yaml") && !p.endsWith(".yml"),
    );
    expect(
      strays.map((p) => path.relative(BUNDLED, p)),
      "non-rule files in the published bundle; .complyedge-public cites an " +
        "internal planning card and must never ship",
    ).toEqual([]);
  });

  whenBuilt("the engine actually loads the bundled corpus", async () => {
    const { TrustLintEngine } = await import("../engine.js");
    const engine = new TrustLintEngine(BUNDLED);
    expect(engine.rules.length).toBe(relYaml(BUNDLED).length);
  });
});
