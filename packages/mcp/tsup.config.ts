import { defineConfig } from "tsup";

export default defineConfig({
  entry: { cli: "src/cli.ts", server: "src/server.ts" },
  format: ["esm"],
  dts: true,
  clean: true,
  splitting: false,
  shims: true
});
