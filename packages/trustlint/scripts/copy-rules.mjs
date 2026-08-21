// Bundle the canonical rule corpus into the published npm package.
//
// Mirrors what the Python package already does: deploy-pip.sh copies
// rules/regulations/ into trustlint/rules/, and MANIFEST.in ships only
// *.yaml/*.yml from it. This is the npm half of that same contract, so
// `npm install trustlint` is install-true on a machine with no rules/ dir.
//
// Runs AFTER tsup (see the build script) because tsup cleans dist/.
//
// The *.yaml/*.yml filter is not cosmetic. rules/regulations/ carries
// .complyedge-public — an internal export-gate marker whose text cites an
// internal planning card — and a README. A recursive copy publishes both to
// npm. Internal planning identifiers must never reach a public surface, and
// the Python MANIFEST has always filtered for exactly this reason.

import { cpSync, existsSync, readdirSync, rmSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sourceRules = resolve(packageRoot, "../../rules/regulations");
const outputRules = resolve(packageRoot, "dist/rules");

if (!existsSync(sourceRules)) {
  throw new Error(`TrustLint rule corpus is missing: ${sourceRules}`);
}

const isRuleFile = (p) => p.endsWith(".yaml") || p.endsWith(".yml");

rmSync(outputRules, { recursive: true, force: true });
cpSync(sourceRules, outputRules, {
  recursive: true,
  filter: (src) => statSync(src).isDirectory() || isRuleFile(src),
});

const countYaml = (dir) =>
  readdirSync(dir, { withFileTypes: true }).reduce(
    (n, e) =>
      n +
      (e.isDirectory()
        ? countYaml(resolve(dir, e.name))
        : isRuleFile(e.name)
          ? 1
          : 0),
    0,
  );

const copied = countYaml(outputRules);
const canonical = countYaml(sourceRules);

// A bundle that silently comes out empty or short is the failure mode that
// matters: the package still installs, the CLI still runs, and it simply
// finds nothing to enforce.
if (copied === 0) {
  throw new Error(`no rule files copied from ${sourceRules}`);
}
if (copied !== canonical) {
  throw new Error(
    `bundled ${copied} rule files but canonical corpus has ${canonical}`,
  );
}

console.log(`bundled ${copied} rule files into dist/rules`);
