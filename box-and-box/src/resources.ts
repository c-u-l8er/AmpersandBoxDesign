/**
 * MCP resource registrations for box-and-box.
 *
 * Read-only projections of the SQLite database and bundled registry,
 * addressable by `ampersand://` URIs.
 */
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Handle } from "./db.js";
import { loadRegistry } from "./registry.js";
import type { AmpersandValidator } from "./validate.js";

export interface ResourceContext {
  db: Handle;
  validator: AmpersandValidator;
}

function jsonResource(uri: string, value: unknown) {
  return {
    contents: [
      {
        uri,
        mimeType: "application/json",
        text: JSON.stringify(value, null, 2),
      },
    ],
  };
}

export function registerResources(server: McpServer, ctx: ResourceContext): void {
  server.resource(
    "health",
    "ampersand://runtime/health",
    { mimeType: "application/json" },
    async (uri) => {
      const specCount = (ctx.db.prepare("SELECT COUNT(*) AS c FROM specs").get() as { c: number }).c;
      const validationCount = (
        ctx.db.prepare("SELECT COUNT(*) AS c FROM validations").get() as { c: number }
      ).c;
      return jsonResource(uri.href, {
        status: "ok",
        package: "box-and-box",
        version: "0.1.0",
        schema_version: "v0.1.0",
        schema_path: ctx.validator.artifacts.ampersandSchema,
        counts: { specs: specCount, validations: validationCount },
        timestamp: new Date().toISOString(),
      });
    },
  );

  server.resource(
    "recent-specs",
    "ampersand://specs/recent",
    { mimeType: "application/json" },
    async (uri) => {
      const rows = ctx.db
        .prepare(
          `SELECT id, agent, version, schema_version, source_path, registered_at
           FROM specs ORDER BY registered_at DESC LIMIT 20`,
        )
        .all();
      return jsonResource(uri.href, { count: rows.length, specs: rows });
    },
  );

  server.resource(
    "registry-capabilities",
    "ampersand://registry/capabilities",
    { mimeType: "application/json" },
    async (uri) => {
      const registry = loadRegistry(ctx.validator.artifacts.registryFile);
      return jsonResource(uri.href, registry);
    },
  );
}
