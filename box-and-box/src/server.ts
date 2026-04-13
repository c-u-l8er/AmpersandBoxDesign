/**
 * box-and-box MCP server wiring.
 *
 * Constructs the high-level `McpServer`, registers tools + resources, and
 * connects a transport. Supports stdio and HTTP (Streamable HTTP) transports.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import http from "node:http";
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
    await startHttpServer(server, opts);
  }
}

async function startHttpServer(server: McpServer, opts: ServerOptions): Promise<void> {
  const httpServer = http.createServer(async (req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Accept, mcp-session-id");

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    if (req.method === "GET" && req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", name: "box-and-box", version: "0.1.0" }));
      return;
    }

    if (req.method === "POST") {
      try {
        const chunks: Buffer[] = [];
        for await (const chunk of req) chunks.push(chunk as Buffer);
        const body = JSON.parse(Buffer.concat(chunks).toString());

        const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
        res.on("close", () => { transport.close().catch(() => {}); });
        await server.connect(transport);
        await transport.handleRequest(req, res, body);
      } catch (err) {
        if (!res.headersSent) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({
            jsonrpc: "2.0", id: null,
            error: { code: -32700, message: String(err) },
          }));
        }
      }
      return;
    }

    res.writeHead(405);
    res.end("Method not allowed");
  });

  await new Promise<void>((resolve) => {
    httpServer.listen(opts.port, "0.0.0.0", () => {
      opts.log("info", `box-and-box MCP server listening on http://0.0.0.0:${opts.port}`);
      resolve();
    });
  });

  // Keep process alive
  await new Promise<void>(() => {});
}
