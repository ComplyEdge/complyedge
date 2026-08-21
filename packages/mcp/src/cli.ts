#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./server.js";

async function main(): Promise<void> {
  const server = createServer();
  await server.connect(new StdioServerTransport());
}

main().catch((error) => {
  console.error(
    error instanceof Error ? error.message : "Unable to start ComplyEdge MCP server."
  );
  process.exitCode = 1;
});
