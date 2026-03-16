#!/usr/bin/env node

/* eslint-disable no-console */

const fs = require("node:fs");
const path = require("node:path");
const Ajv2020 = require("ajv/dist/2020");
const addFormats = require("ajv-formats");

const PACKAGE_VERSION = "0.1.0";
const ROOT_DIR = path.resolve(__dirname, "..");
const SCHEMA_PATH = path.join(ROOT_DIR, "schema", "ampersand.schema.json");

function main() {
  const argv = process.argv.slice(2);

  if (argv.length === 0 || argv[0] === "help" || argv[0] === "--help" || argv[0] === "-h") {
    return emitOk({
      command: "help",
      status: "ok",
      version: PACKAGE_VERSION,
      usage: usageLines(),
    });
  }

  if (argv[0] === "version" || argv[0] === "--version") {
    return emitOk({
      command: "version",
      status: "ok",
      version: PACKAGE_VERSION,
    });
  }

  const [command, ...rest] = argv;

  switch (command) {
    case "validate":
      return handleValidate(rest);

    case "compose":
      return handleCompose(rest);

    case "check":
      return handleCheck(rest);

    case "generate":
      return handleGenerate(rest);

    default:
      return emitError(
        "invalid_arguments",
        "unrecognized command line arguments",
        1,
        { usage: usageLines() }
      );
  }
}

function handleValidate(args) {
  if (args.length !== 1) {
    return emitError("invalid_arguments", "usage: ampersand validate <file>", 1, {
      usage: usageLines(),
    });
  }

  const filePath = args[0];
  const result = validateDeclarationFile(filePath);

  if (!result.ok) {
    return emitError("validation_failed", result.errors, 1, {
      command: "validate",
      file: filePath,
    });
  }

  const document = result.document;
  return emitOk({
    command: "validate",
    status: "ok",
    valid: true,
    file: filePath,
    agent: document.agent,
    version: document.version,
    schema: document.$schema,
    capability_count: Object.keys(document.capabilities || {}).length,
  });
}

function handleCompose(args) {
  if (args.length < 1) {
    return emitError("invalid_arguments", "usage: ampersand compose <file1> [file2...]", 1, {
      usage: usageLines(),
    });
  }

  const documents = [];
  for (const filePath of args) {
    const result = validateDeclarationFile(filePath);
    if (!result.ok) {
      return emitError("compose_failed", prefixErrors(filePath, result.errors), 1, {
        command: "compose",
        files: args,
      });
    }
    documents.push(result.document);
  }

  const merged = {};
  for (const document of documents) {
    const capabilities = document.capabilities || {};
    for (const [capability, binding] of Object.entries(capabilities)) {
      if (!Object.prototype.hasOwnProperty.call(merged, capability)) {
        merged[capability] = binding;
        continue;
      }

      if (!deepEqual(merged[capability], binding)) {
        return emitError(
          "compose_failed",
          [
            `conflicting_binding for ${capability}: ` +
              `${stableStringify(merged[capability])} != ${stableStringify(binding)}`,
          ],
          1,
          { command: "compose", files: args }
        );
      }
    }
  }

  const payload =
    args.length === 1
      ? {
          command: "compose",
          status: "ok",
          file: args[0],
          agent: documents[0].agent,
          version: documents[0].version,
          capabilities: Object.keys(merged).sort(),
          capability_count: Object.keys(merged).length,
          composed: merged,
        }
      : {
          command: "compose",
          status: "ok",
          files: args,
          file_count: args.length,
          agents: Array.from(new Set(documents.map((d) => d.agent))).sort(),
          versions: Array.from(new Set(documents.map((d) => d.version))).sort(),
          capabilities: Object.keys(merged).sort(),
          capability_count: Object.keys(merged).length,
          composed: merged,
        };

  return emitOk(payload);
}

function handleCheck(args) {
  if (args.length < 2) {
    return emitError(
      "invalid_arguments",
      "usage: ampersand check <file> <pipeline> | ampersand check <file> --pipeline <name>",
      1,
      { usage: usageLines() }
    );
  }

  const declarationPath = args[0];
  const declarationResult = validateDeclarationFile(declarationPath);
  if (!declarationResult.ok) {
    return emitError("pipeline_check_failed", declarationResult.errors, 1, {
      command: "check",
      file: declarationPath,
    });
  }

  const document = declarationResult.document;
  let pipelineInput;
  let pipelineMeta = {};

  if (args[1] === "--pipeline") {
    if (!args[2]) {
      return emitError("pipeline_check_failed", ["missing pipeline name after --pipeline"], 1, {
        command: "check",
        file: declarationPath,
      });
    }
    const pipelineName = args[2];
    const pipelines = document.pipelines || {};
    if (!pipelines[pipelineName] || typeof pipelines[pipelineName] !== "object") {
      return emitError(
        "pipeline_check_failed",
        [`pipeline "${pipelineName}" is not defined in declaration pipelines`],
        1,
        { command: "check", file: declarationPath, pipeline_name: pipelineName }
      );
    }
    pipelineInput = pipelines[pipelineName];
    pipelineMeta.pipeline_name = pipelineName;
  } else {
    pipelineInput = loadPipelineReference(args[1]).value;
    pipelineMeta = loadPipelineReference(args[1]).meta;
  }

  const normalized = normalizePipeline(pipelineInput);
  if (!normalized.ok) {
    return emitError("pipeline_check_failed", normalized.errors, 1, {
      command: "check",
      file: declarationPath,
    });
  }

  const capabilityErrors = validatePipelineAgainstDeclaration(document, normalized.pipeline.steps);
  if (capabilityErrors.length > 0) {
    return emitError("pipeline_check_failed", capabilityErrors, 1, {
      command: "check",
      file: declarationPath,
      ...pipelineMeta,
    });
  }

  return emitOk({
    command: "check",
    status: "ok",
    valid: true,
    file: declarationPath,
    agent: document.agent,
    version: document.version,
    source: {
      type: normalized.pipeline.source_type || "stream_data",
      ref: normalized.pipeline.source_ref || normalized.pipeline.source_type || "raw_data",
    },
    step_count: normalized.pipeline.steps.length,
    pipeline: normalized.pipeline.steps,
    ...pipelineMeta,
  });
}

function handleGenerate(args) {
  if (args.length < 2) {
    return emitError("invalid_arguments", "usage: ampersand generate <target> ...", 1, {
      usage: usageLines(),
    });
  }

  const [target, ...rest] = args;
  if (target !== "mcp") {
    return emitError("unknown_generate_target", `unsupported generate target "${target}"`, 1, {
      usage: usageLines(),
    });
  }

  const parse = parseGenerateMcpArgs(rest);
  if (!parse.ok) {
    return emitError("mcp_generation_failed", parse.errors, 1, {
      command: "generate",
      target: "mcp",
    });
  }

  const { filePath, format, outputPath } = parse;
  const declarationResult = validateDeclarationFile(filePath);
  if (!declarationResult.ok) {
    return emitError("mcp_generation_failed", declarationResult.errors, 1, {
      command: "generate",
      target: "mcp",
      file: filePath,
    });
  }

  const document = declarationResult.document;
  const manifest = buildMcpConfig(document, format);

  if (outputPath) {
    try {
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      fs.writeFileSync(outputPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
      return emitOk({
        command: "generate",
        target: "mcp",
        status: "ok",
        file: filePath,
        format,
        output: outputPath,
        config: manifest,
      });
    } catch (error) {
      return emitError(
        "mcp_generation_failed",
        [`unable to write output file ${outputPath}: ${String(error?.message || error)}`],
        1,
        { command: "generate", target: "mcp", file: filePath }
      );
    }
  }

  return emitOk(manifest);
}

function parseGenerateMcpArgs(args) {
  if (!args[0]) {
    return { ok: false, errors: ["missing declaration file"] };
  }

  const filePath = args[0];
  let format = "zed";
  let outputPath = null;

  for (let i = 1; i < args.length; i += 1) {
    const token = args[i];
    if (token === "--format") {
      const next = args[i + 1];
      if (!next) return { ok: false, errors: ["missing value for --format"] };
      if (next !== "zed" && next !== "generic") {
        return { ok: false, errors: [`unsupported --format "${next}"; expected zed or generic`] };
      }
      format = next;
      i += 1;
      continue;
    }

    if (token === "-o" || token === "--output") {
      const next = args[i + 1];
      if (!next) return { ok: false, errors: [`missing value for ${token}`] };
      outputPath = next;
      i += 1;
      continue;
    }

    return { ok: false, errors: [`unknown option "${token}"`] };
  }

  return { ok: true, filePath, format, outputPath };
}

function validateDeclarationFile(filePath) {
  const loaded = loadJsonFile(filePath);
  if (!loaded.ok) return loaded;

  const schemaLoaded = loadJsonFile(SCHEMA_PATH);
  if (!schemaLoaded.ok) {
    return {
      ok: false,
      errors: [`unable to load bundled schema: ${schemaLoaded.errors.join("; ")}`],
    };
  }

  try {
    const ajv = new Ajv2020({ allErrors: true, strict: false });
    addFormats(ajv);
    const validate = ajv.compile(schemaLoaded.document);
    const valid = validate(loaded.document);
    if (!valid) {
      return {
        ok: false,
        errors: (validate.errors || []).map((e) => `${e.instancePath || "/"} ${e.message}`),
      };
    }
    return { ok: true, document: loaded.document };
  } catch (error) {
    return { ok: false, errors: [String(error?.message || error)] };
  }
}

function buildMcpConfig(document, format) {
  const bindings = Object.entries(document.capabilities || {}).map(([capability, binding]) => ({
    capability,
    provider: binding.provider,
  }));

  const grouped = new Map();
  for (const binding of bindings) {
    if (!grouped.has(binding.provider)) grouped.set(binding.provider, []);
    grouped.get(binding.provider).push(binding.capability);
  }

  const servers = {};
  for (const [provider, capabilities] of [...grouped.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    const server = resolveProvider(provider, capabilities.sort());
    if (server) servers[provider] = server;
  }

  const key = format === "generic" ? "mcpServers" : "context_servers";
  return { [key]: servers };
}

function resolveProvider(provider, capabilities) {
  if (provider === "graphonomous") {
    return {
      command: "npx",
      args: ["-y", "graphonomous", "--db", "~/.graphonomous/knowledge.db", "--embedder-backend", "fallback"],
      env: { GRAPHONOMOUS_EMBEDDING_MODEL: "sentence-transformers/all-MiniLM-L6-v2" },
      transport: "stdio",
      capabilities,
    };
  }

  if (provider === "ticktickclock") {
    return {
      command: "npx",
      args: ["-y", "@ampersand-protocol/ticktickclock-mcp"],
      env: {},
      transport: "stdio",
      capabilities,
    };
  }

  return null;
}

function loadPipelineReference(reference) {
  if (fs.existsSync(reference) && fs.statSync(reference).isFile()) {
    const raw = fs.readFileSync(reference, "utf8");
    return { value: decodeJsonish(raw), meta: { pipeline_file: reference } };
  }
  return { value: decodeJsonish(reference), meta: {} };
}

function normalizePipeline(input) {
  if (typeof input === "string") {
    return parsePipelineString(input);
  }

  if (Array.isArray(input)) {
    const steps = input.map(normalizeStep).filter(Boolean);
    if (steps.length === 0) return { ok: false, errors: ["pipeline must contain at least one step"] };
    return { ok: true, pipeline: { source_type: null, source_ref: null, steps } };
  }

  if (input && typeof input === "object") {
    const stepsInput = input.steps || input.pipeline;
    if (typeof stepsInput === "string") {
      return parsePipelineString(stepsInput, {
        source_type: input.source_type || null,
        source_ref: input.source_ref || null,
      });
    }
    if (Array.isArray(stepsInput)) {
      const steps = stepsInput.map(normalizeStep).filter(Boolean);
      if (steps.length === 0) return { ok: false, errors: ["pipeline must contain at least one step"] };
      return {
        ok: true,
        pipeline: {
          source_type: input.source_type || null,
          source_ref: input.source_ref || null,
          steps,
        },
      };
    }
  }

  return { ok: false, errors: ["pipeline must be a string, steps array, or pipeline object"] };
}

function parsePipelineString(value, overrides = {}) {
  const cleaned = String(value).trim();
  if (!cleaned) return { ok: false, errors: ["pipeline string cannot be empty"] };

  const tokens = cleaned.split(/\s*\|>\s*/).map((t) => t.trim()).filter(Boolean);
  if (tokens.length < 2) return { ok: false, errors: ["pipeline must include source and at least one step"] };

  let sourceType = tokens[0];
  let stepTokens = tokens.slice(1);

  if (tokens[0].startsWith("&")) {
    sourceType = null;
    stepTokens = tokens;
  }

  const steps = [];
  for (const token of stepTokens) {
    const normalized = normalizeStep(token);
    if (!normalized) return { ok: false, errors: [`invalid pipeline step ${JSON.stringify(token)}`] };
    steps.push(normalized);
  }

  return {
    ok: true,
    pipeline: {
      source_type: overrides.source_type ?? sourceType,
      source_ref: overrides.source_ref ?? (sourceType || "raw_data"),
      steps,
    },
  };
}

function normalizeStep(step) {
  if (!step) return null;

  if (typeof step === "string") {
    const token = step.trim().replace(/\(\)$/, "");
    const parts = token.split(".");
    if (parts.length < 3 || !parts[0].startsWith("&")) return null;
    return {
      capability: parts.slice(0, -1).join("."),
      operation: parts[parts.length - 1],
    };
  }

  if (Array.isArray(step) && step.length === 2) {
    return { capability: step[0], operation: step[1] };
  }

  if (typeof step === "object") {
    const capability = step.capability;
    const operation = step.operation;
    if (typeof capability === "string" && typeof operation === "string") {
      return { capability, operation };
    }
  }

  return null;
}

function validatePipelineAgainstDeclaration(document, steps) {
  const errors = [];
  const capabilities = document.capabilities || {};

  steps.forEach((step, index) => {
    if (!capabilities[step.capability]) {
      errors.push(`step ${index + 1} references undeclared capability ${step.capability}`);
    }
    if (!step.operation || typeof step.operation !== "string") {
      errors.push(`step ${index + 1} has invalid operation`);
    }
  });

  return errors;
}

function loadJsonFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(content);
    return { ok: true, document: parsed };
  } catch (error) {
    return {
      ok: false,
      errors: [`unable to read/parse JSON file ${filePath}: ${String(error?.message || error)}`],
    };
  }
}

function decodeJsonish(value) {
  if (typeof value !== "string") return value;
  const trimmed = value.trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    return value;
  }
}

function prefixErrors(filePath, errors) {
  return (errors || []).map((e) => `${filePath}: ${e}`);
}

function stableStringify(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  const keys = Object.keys(value).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`).join(",")}}`;
}

function deepEqual(left, right) {
  return stableStringify(left) === stableStringify(right);
}

function usageLines() {
  return [
    "ampersand validate <file>",
    "ampersand compose <file1> [file2...]",
    "ampersand check <file> <pipeline>",
    "ampersand check <file> --pipeline <name>",
    "ampersand generate mcp <file> [--format zed|generic] [-o|--output <path>]",
    "ampersand version",
    "ampersand help",
  ];
}

function emitOk(payload) {
  process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
  process.exit(0);
}

function emitError(kind, messageOrMessages, code, extra = {}) {
  const errors = Array.isArray(messageOrMessages)
    ? messageOrMessages.map(String)
    : [String(messageOrMessages)];

  const payload = {
    status: "error",
    error: kind,
    errors,
    ...extra,
  };

  process.stderr.write(`${JSON.stringify(payload, null, 2)}\n`);
  process.exit(code);
}

main();
