#!/usr/bin/env node
/**
 * box-and-box CLI entrypoint.
 *
 * Two modes:
 *  - Default (no positional command): boot the MCP server on stdio.
 *  - One-shot: `validate | compose | check | generate [mcp|a2a] | inspect`
 *    run the corresponding operation and print JSON to stdout.
 */
import yargs, { type Argv } from "yargs";
import { hideBin } from "yargs/helpers";
import path from "node:path";
import os from "node:os";
import { mkdirSync, readFileSync } from "node:fs";
import { openDatabase } from "./db.js";
import { startServer } from "./server.js";
import { AmpersandValidator, type AmpersandDeclaration } from "./validate.js";
import { composeDocuments } from "./compose.js";
import { checkPipeline } from "./check.js";
import { generateMcp, generateA2a } from "./generate.js";
import { inspectSpec } from "./inspect.js";
import { loadRegistry } from "./registry.js";

function expandHome(p: string): string {
  if (p.startsWith("~")) return path.join(os.homedir(), p.slice(1));
  return p;
}

function readDoc(p: string): AmpersandDeclaration {
  return JSON.parse(readFileSync(p, "utf8")) as AmpersandDeclaration;
}

function printJson(value: unknown): void {
  process.stdout.write(JSON.stringify(value, null, 2) + "\n");
}

async function main(): Promise<void> {
  const parser: Argv = yargs(hideBin(process.argv))
    .scriptName("box-and-box")
    .option("db", {
      type: "string",
      default: "~/.box-and-box/specs.db",
      describe: "SQLite database path",
    })
    .option("transport", {
      type: "string",
      choices: ["stdio", "http"] as const,
      default: "stdio",
    })
    .option("port", { type: "number", default: 4711 })
    .option("schema-version", { type: "string", default: "v0.1.0" })
    .option("log-level", {
      type: "string",
      choices: ["debug", "info", "warn", "error"] as const,
      default: "info",
    })
    .command(
      "validate <path>",
      "Validate an ampersand.json spec and exit",
      (y) => y.positional("path", { type: "string", demandOption: true }),
      (argv) => {
        const validator = new AmpersandValidator(argv.schemaVersion);
        const doc = readDoc(argv.path as string);
        const result = validator.validateSpec(doc);
        printJson({ path: argv.path, ...result });
        process.exit(result.valid ? 0 : 1);
      },
    )
    .command(
      "compose <paths...>",
      "Compose N ampersand.json specs and print the merged capability map",
      (y) => y.positional("paths", { type: "string", array: true, demandOption: true }),
      (argv) => {
        const validator = new AmpersandValidator(argv.schemaVersion);
        const paths = argv.paths as string[];
        const docs = paths.map(readDoc);
        const invalid = docs
          .map((d, i) => ({ i, r: validator.validateSpec(d) }))
          .filter((x) => !x.r.valid);
        if (invalid.length > 0) {
          printJson({ ok: false, stage: "validate", invalid });
          process.exit(1);
        }
        const result = composeDocuments(docs);
        printJson(result);
        process.exit(result.ok ? 0 : 1);
      },
    )
    .command(
      "check <path>",
      "Check a pipeline against a spec",
      (y) =>
        y
          .positional("path", { type: "string", demandOption: true })
          .option("pipeline", { type: "string", describe: "Named pipeline from the spec" })
          .option("expression", { type: "string", describe: "|>-separated pipeline expression" }),
      (argv) => {
        const doc = readDoc(argv.path as string);
        const result = checkPipeline(doc, {
          pipelineName: argv.pipeline,
          pipelineExpression: argv.expression,
        });
        printJson(result);
        process.exit(result.ok ? 0 : 1);
      },
    )
    .command(
      "generate <target> <path>",
      "Generate runtime config from a spec (mcp|a2a)",
      (y) =>
        y
          .positional("target", { type: "string", choices: ["mcp", "a2a"], demandOption: true })
          .positional("path", { type: "string", demandOption: true })
          .option("format", { type: "string", choices: ["zed", "generic"], default: "zed" }),
      (argv) => {
        const doc = readDoc(argv.path as string);
        if (argv.target === "mcp") {
          const validator = new AmpersandValidator(argv.schemaVersion);
          const registry = loadRegistry(validator.artifacts.registryFile);
          printJson(generateMcp(doc, registry, { format: argv.format as "zed" | "generic" }));
        } else {
          printJson(generateA2a(doc));
        }
        process.exit(0);
      },
    )
    .command(
      "inspect <path>",
      "Print a structured capability graph for a spec",
      (y) => y.positional("path", { type: "string", demandOption: true }),
      (argv) => {
        printJson(inspectSpec(readDoc(argv.path as string)));
        process.exit(0);
      },
    )
    .version()
    .help()
    .strict();

  const argv = await parser.parseAsync();

  // If yargs handled a subcommand it already called process.exit above. If
  // we get here with no positional command, fall through to server mode.
  if (argv._.length > 0) return;

  const dbPath = expandHome(argv.db as string);
  mkdirSync(path.dirname(dbPath), { recursive: true });

  const logLevel = argv.logLevel as string;
  const log = (level: string, msg: string) => {
    const order = ["debug", "info", "warn", "error"];
    if (order.indexOf(level) < order.indexOf(logLevel)) return;
    process.stderr.write(`[box-and-box ${level}] ${msg}\n`);
  };
  log("info", `opening database ${dbPath}`);

  const db = openDatabase(dbPath);
  const transport = argv.transport as "stdio" | "http";
  log("info", `starting MCP server on ${transport} transport`);
  await startServer({
    db,
    transport,
    port: argv.port as number,
    schemaVersion: argv.schemaVersion as string,
    log,
  });
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.stack ?? err.message : String(err);
  process.stderr.write(`[box-and-box error] ${message}\n`);
  process.exit(1);
});
