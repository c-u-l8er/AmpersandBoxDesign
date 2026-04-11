/**
 * box-and-box MCP server wiring.
 *
 * Constructs the high-level `McpServer`, registers tools + resources, and
 * connects a transport. v0.1.0 only supports stdio; an HTTP transport is
 * declared but not wired.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { Handle } from "./db.js";
import { AmpersandValidator } from "./validate.js";
import { registerTools } from "./tools.js";
import { registerResources } from "./resources.js";

export interface ServerOptions {
  db: Handle;
  transport: "stdio" | "http";
  port: number;
  schemaVersion: string;
  log: (level: string, msg: string) => void;
}

export async function startServer(opts: ServerOptions): Promise<void> {
  const validator = new AmpersandValidator(opts.schemaVersion);
  opts.log("info", `loaded [&] schema from ${validator.artifacts.ampersandSchema}`);

  const server = new McpServer({
    name: "box-and-box",
    version: "0.1.0",
  });

  registerTools(server, { db: opts.db, validator, log: opts.log });
  registerResources(server, { db: opts.db, validator });

  if (opts.transport === "stdio") {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    opts.log("info", "box-and-box MCP server ready on stdio transport");
  } else {
    throw new Error(
      `HTTP transport is declared but not implemented in v0.1.0 — use --transport stdio`,
    );
  }
}
