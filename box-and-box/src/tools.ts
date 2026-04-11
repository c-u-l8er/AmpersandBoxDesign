/**
 * MCP tool registrations for box-and-box.
 *
 * Each tool accepts a zod-validated input schema, runs the underlying
 * validate/compose/check/generate logic, and returns a JSON payload as
 * MCP text content. Tools that mutate state also persist a row into the
 * SQLite database.
 */
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Handle } from "./db.js";
import {
  AmpersandValidator,
  type AmpersandDeclaration,
} from "./validate.js";
import { composeDocuments } from "./compose.js";
import { checkPipeline } from "./check.js";
import { generateMcp, generateA2a } from "./generate.js";
import { inspectSpec, diffSpecs } from "./inspect.js";
import { loadRegistry, listCapabilities, providersForCapability } from "./registry.js";

export interface ToolContext {
  db: Handle;
  validator: AmpersandValidator;
  log: (level: string, msg: string) => void;
}

function sha256(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

function json(content: unknown): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [{ type: "text", text: JSON.stringify(content, null, 2) }],
  };
}

function loadDocFromInput(input: {
  path?: string;
  document?: unknown;
}): { doc: AmpersandDeclaration; raw: string; source_path: string | null } {
  if (input.path) {
    const raw = readFileSync(input.path, "utf8");
    return { doc: JSON.parse(raw) as AmpersandDeclaration, raw, source_path: input.path };
  }
  if (input.document) {
    const raw = JSON.stringify(input.document);
    return { doc: input.document as AmpersandDeclaration, raw, source_path: null };
  }
  throw new Error("either `path` or `document` is required");
}

export function registerTools(server: McpServer, ctx: ToolContext): void {
  // validate — schema-validate an ampersand.json and (optionally) persist it.
  server.registerTool(
    "validate",
    {
      title: "Validate ampersand.json",
      description:
        "Validate an [&] Protocol spec against ampersand.schema.json (draft 2020-12). " +
        "If `persist` is true, the spec is stored in the box-and-box database.",
      inputSchema: {
        path: z.string().optional().describe("Filesystem path to an ampersand.json file"),
        document: z.unknown().optional().describe("Inline spec JSON object"),
        persist: z.boolean().optional().default(false),
      },
    },
    async (input) => {
      const { doc, raw, source_path } = loadDocFromInput(input);
      const result = ctx.validator.validateSpec(doc);

      if (input.persist && result.valid) {
        const specId = sha256(raw);
        const now = Date.now();
        ctx.db
          .prepare(
            `INSERT OR REPLACE INTO specs
             (id, agent, version, schema_version, source_path, source_hash, spec_json, registered_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          )
          .run(
            specId,
            doc.agent,
            doc.version,
            "v0.1.0",
            source_path,
            specId,
            raw,
            now,
          );
        ctx.db
          .prepare(
            `INSERT INTO validations (spec_id, validator, status, errors_json, validated_at)
             VALUES (?, 'schema', 'pass', NULL, ?)`,
          )
          .run(specId, now);
        return json({ valid: true, spec_id: specId, agent: doc.agent, version: doc.version });
      }

      return json({
        valid: result.valid,
        agent: doc.agent,
        version: doc.version,
        errors: result.errors,
      });
    },
  );

  // validate_contract
  server.registerTool(
    "validate_contract",
    {
      title: "Validate capability contract",
      description: "Validate a JSON file against capability-contract.schema.json.",
      inputSchema: {
        path: z.string().optional(),
        document: z.unknown().optional(),
      },
    },
    async (input) => {
      const { doc } = loadDocFromInput(input);
      const result = ctx.validator.validateContract(doc);
      return json(result);
    },
  );

  // validate_registry
  server.registerTool(
    "validate_registry",
    {
      title: "Validate capability registry",
      description: "Validate a JSON file against registry.schema.json.",
      inputSchema: {
        path: z.string().optional(),
        document: z.unknown().optional(),
      },
    },
    async (input) => {
      const { doc } = loadDocFromInput(input);
      const result = ctx.validator.validateRegistry(doc);
      return json(result);
    },
  );

  // compose
  server.registerTool(
    "compose",
    {
      title: "Compose specs",
      description:
        "Compose N ampersand.json specs into one. Conflicting capability bindings are " +
        "reported as errors; duplicate bindings collapse (idempotent).",
      inputSchema: {
        paths: z.array(z.string()).min(1),
      },
    },
    async (input) => {
      const docs: AmpersandDeclaration[] = input.paths.map((p: string) => {
        const raw = readFileSync(p, "utf8");
        return JSON.parse(raw) as AmpersandDeclaration;
      });
      // Validate each first
      const invalid = docs
        .map((d, i) => ({ doc: d, i, result: ctx.validator.validateSpec(d) }))
        .filter((x) => !x.result.valid);
      if (invalid.length > 0) {
        return json({
          ok: false,
          stage: "validate",
          invalid: invalid.map((x) => ({ path: input.paths[x.i], errors: x.result.errors })),
        });
      }
      const result = composeDocuments(docs);
      return json(result);
    },
  );

  // check
  server.registerTool(
    "check",
    {
      title: "Check pipeline",
      description:
        "Check a pipeline (by name or |>-expression) against a spec's declared capabilities.",
      inputSchema: {
        path: z.string().optional(),
        document: z.unknown().optional(),
        pipelineName: z.string().optional(),
        pipelineExpression: z.string().optional(),
      },
    },
    async (input) => {
      const { doc } = loadDocFromInput(input);
      const result = checkPipeline(doc, {
        pipelineName: input.pipelineName,
        pipelineExpression: input.pipelineExpression,
      });
      return json(result);
    },
  );

  // generate_mcp
  server.registerTool(
    "generate_mcp",
    {
      title: "Generate MCP config",
      description:
        "Generate MCP server configuration from an ampersand.json spec. " +
        "`format=zed` produces `context_servers`, `format=generic` produces `mcpServers`.",
      inputSchema: {
        path: z.string().optional(),
        document: z.unknown().optional(),
        format: z.enum(["zed", "generic"]).optional().default("zed"),
      },
    },
    async (input) => {
      const { doc } = loadDocFromInput(input);
      const registry = loadRegistry(ctx.validator.artifacts.registryFile);
      const result = generateMcp(doc, registry, { format: input.format });
      return json(result);
    },
  );

  // generate_a2a
  server.registerTool(
    "generate_a2a",
    {
      title: "Generate A2A card",
      description: "Generate an A2A agent card from an ampersand.json spec.",
      inputSchema: {
        path: z.string().optional(),
        document: z.unknown().optional(),
      },
    },
    async (input) => {
      const { doc } = loadDocFromInput(input);
      return json(generateA2a(doc));
    },
  );

  // inspect_spec
  server.registerTool(
    "inspect_spec",
    {
      title: "Inspect spec",
      description: "Return a structured capability graph for an ampersand.json spec.",
      inputSchema: {
        path: z.string().optional(),
        document: z.unknown().optional(),
      },
    },
    async (input) => {
      const { doc } = loadDocFromInput(input);
      return json(inspectSpec(doc));
    },
  );

  // diff
  server.registerTool(
    "diff",
    {
      title: "Diff specs",
      description: "Return added / removed / changed capabilities between two specs.",
      inputSchema: {
        from_path: z.string(),
        to_path: z.string(),
      },
    },
    async (input) => {
      const fromRaw = readFileSync(input.from_path, "utf8");
      const toRaw = readFileSync(input.to_path, "utf8");
      const fromDoc = JSON.parse(fromRaw) as AmpersandDeclaration;
      const toDoc = JSON.parse(toRaw) as AmpersandDeclaration;
      return json(diffSpecs(fromDoc, toDoc));
    },
  );

  // registry_list
  server.registerTool(
    "registry_list",
    {
      title: "List registry capabilities",
      description: "List all primitive capabilities declared in the bundled registry.",
      inputSchema: {},
    },
    async () => {
      const registry = loadRegistry(ctx.validator.artifacts.registryFile);
      return json({ capabilities: listCapabilities(registry) });
    },
  );

  // registry_providers
  server.registerTool(
    "registry_providers",
    {
      title: "List providers for a capability",
      description: "Return the registry providers for a given capability id (e.g. &memory.graph).",
      inputSchema: {
        capability: z.string(),
      },
    },
    async (input) => {
      const registry = loadRegistry(ctx.validator.artifacts.registryFile);
      return json({
        capability: input.capability,
        providers: providersForCapability(registry, input.capability),
      });
    },
  );
}
