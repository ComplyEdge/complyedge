import { defineConfig } from "tsup";

export default defineConfig([
  {
    entry: { cli: "src/cli.ts" },
    format: ["cjs"],
    dts: true,
    clean: true,
    splitting: false,
    shims: true,
  },
  {
    entry: { index: "src/index.ts" },
    format: ["cjs"],
    dts: true,
    splitting: false,
  },
]);
