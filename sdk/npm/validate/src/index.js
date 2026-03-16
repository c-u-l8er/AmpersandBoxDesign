// Ampersand Protocol npm validator/library
// Provides: validate, compose, check, MCP generation.

const fs = require("node:fs");
const path = require("node:path");
const Ajv2020 = require("ajv/dist/2020");
const addFormats = require("ajv-formats");

const DEFAULT_SCHEMA_PATH = path.resolve(
  __dirname,
  "../schema/ampersand.schema.json",
);
const DEFAULT_REGISTRY_PATH = path.resolve(
  __dirname,
  "../../../../registry/v0.1.0/capabilities.registry.json",
);

function readJsonFile(filePath, label = "JSON file") {
  let raw;
  try {
    raw = fs.readFileSync(filePath, "utf8");
  } catch (error) {
    return {
      ok: false,
      errors: [`Unable to read ${label} at ${filePath}: ${error.message}`],
    };
  }

  try {
    return { ok: true, value: JSON.parse(raw) };
  } catch (error) {
    return {
      ok: false,
      errors: [`Unable to parse ${label} at ${filePath}: ${error.message}`],
    };
  }
}

function stringifyAjvError(error) {
  const instancePath =
    error.instancePath && error.instancePath !== "" ? error.instancePath : "/";
  return `${instancePath} ${error.message}`.trim();
}

function getSchema(schemaPath = DEFAULT_SCHEMA_PATH) {
  const loaded = readJsonFile(schemaPath, "schema");
  if (!loaded.ok) return loaded;
  return { ok: true, value: loaded.value };
}

function createValidator(schemaPath = DEFAULT_SCHEMA_PATH) {
  const loaded = getSchema(schemaPath);
  if (!loaded.ok) return loaded;

  const ajv = new Ajv2020({
    allErrors: true,
    strict: false,
    allowUnionTypes: true,
  });

  addFormats(ajv);

  let validate;
  try {
    validate = ajv.compile(loaded.value);
  } catch (error) {
    return {
      ok: false,
      errors: [`Unable to compile schema at ${schemaPath}: ${error.message}`],
    };
  }

  return { ok: true, value: validate };
}

function validateDocument(document, options = {}) {
  if (!document || typeof document !== "object" || Array.isArray(document)) {
    return {
      ok: false,
      errors: ["Document must be a JSON object"],
    };
  }

  const schemaPath = options.schemaPath || DEFAULT_SCHEMA_PATH;
  const validatorResult = createValidator(schemaPath);
  if (!validatorResult.ok) return validatorResult;

  const validate = validatorResult.value;
  const valid = validate(document);

  if (!valid) {
    return {
      ok: false,
      errors: (validate.errors || []).map(stringifyAjvError),
    };
  }

  return { ok: true, value: document };
}

function validateFile(filePath, options = {}) {
  const loaded = readJsonFile(filePath, "ampersand declaration");
  if (!loaded.ok) return loaded;

  const result = validateDocument(loaded.value, options);
  if (!result.ok) {
    return {
      ok: false,
      errors: result.errors.map((e) => `${filePath}: ${e}`),
    };
  }

  return { ok: true, value: loaded.value };
}

function asCapabilityMap(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  if (
    input.capabilities &&
    typeof input.capabilities === "object" &&
    !Array.isArray(input.capabilities)
  ) {
    return input.capabilities;
  }
  const entries = Object.entries(input);
  if (
    entries.every(
      ([k, v]) =>
        typeof k === "string" &&
        k.startsWith("&") &&
        v &&
        typeof v === "object" &&
        !Array.isArray(v),
    )
  ) {
    return input;
  }
  return null;
}

function normalizeCapabilities(input) {
  const caps = asCapabilityMap(input) || {};
  return Object.keys(caps)
    .filter((id) => typeof id === "string")
    .sort();
}

function deepEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function composeCapabilityMaps(inputs) {
  const merged = {};
  for (const input of inputs) {
    const caps = asCapabilityMap(input);
    if (!caps) {
      return {
        ok: false,
        errors: [
          "compose input must be a declaration object or capability map",
        ],
      };
    }
    for (const [capability, binding] of Object.entries(caps)) {
      if (!(capability in merged)) {
        merged[capability] = binding;
        continue;
      }
      if (!deepEqual(merged[capability], binding)) {
        return {
          ok: false,
          errors: [
            `conflicting_binding for capability ${capability}: ${JSON.stringify(
              merged[capability],
            )} vs ${JSON.stringify(binding)}`,
          ],
        };
      }
    }
  }
  return { ok: true, value: merged };
}

function composeDocuments(documents) {
  const result = composeCapabilityMaps(documents);
  if (!result.ok) return result;
  return {
    ok: true,
    value: {
      capabilities: result.value,
      normalized: Object.keys(result.value).sort(),
      capability_count: Object.keys(result.value).length,
    },
  };
}

function composeFiles(filePaths, options = {}) {
  const docs = [];
  for (const filePath of filePaths) {
    const validated = validateFile(filePath, options);
    if (!validated.ok) return validated;
    docs.push(validated.value);
  }
  return composeDocuments(docs);
}

function parseStepToken(token) {
  const clean = String(token)
    .trim()
    .replace(/\(\)\s*$/, "");
  const parts = clean.split(".").filter(Boolean);
  if (parts.length < 3 || !parts[0].startsWith("&")) {
    return { ok: false, errors: [`Invalid pipeline token: ${token}`] };
  }
  const operation = parts[parts.length - 1];
  const capability = parts.slice(0, -1).join(".");
  return { ok: true, value: { capability, operation } };
}

function parsePipelineExpression(expression) {
  if (typeof expression !== "string" || expression.trim() === "") {
    return {
      ok: false,
      errors: ["pipeline expression must be a non-empty string"],
    };
  }

  const tokens = expression
    .split(/\s*\|>\s*/)
    .map((s) => s.trim())
    .filter(Boolean);

  if (tokens.length < 2) {
    return {
      ok: false,
      errors: ["pipeline must include a source token and at least one step"],
    };
  }

  const sourceType = tokens[0].startsWith("&") ? null : tokens[0];
  const stepTokens = sourceType ? tokens.slice(1) : tokens;

  if (stepTokens.length === 0) {
    return {
      ok: false,
      errors: ["pipeline must include at least one capability operation step"],
    };
  }

  const steps = [];
  for (const token of stepTokens) {
    const parsed = parseStepToken(token);
    if (!parsed.ok) return parsed;
    steps.push(parsed.value);
  }

  return {
    ok: true,
    value: {
      source_type: sourceType || null,
      source_ref: sourceType || "raw_data",
      steps,
    },
  };
}

function normalizePipelineInput(document, pipelineInput, options = {}) {
  if (options.pipelineName) {
    const pipelineName = options.pipelineName;
    const pipelines = (document && document.pipelines) || {};
    const named = pipelines[pipelineName];
    if (!named || typeof named !== "object") {
      return {
        ok: false,
        errors: [
          `pipeline "${pipelineName}" is not defined in document.pipelines`,
        ],
      };
    }
    return {
      ok: true,
      value: {
        source_type: named.source_type || null,
        source_ref: named.source_ref || named.source_type || "raw_data",
        steps: Array.isArray(named.steps) ? named.steps : [],
      },
    };
  }

  if (typeof pipelineInput === "string")
    return parsePipelineExpression(pipelineInput);

  if (Array.isArray(pipelineInput)) {
    return {
      ok: true,
      value: {
        source_type: null,
        source_ref: "raw_data",
        steps: pipelineInput,
      },
    };
  }

  if (pipelineInput && typeof pipelineInput === "object") {
    if (Array.isArray(pipelineInput.steps)) {
      return {
        ok: true,
        value: {
          source_type: pipelineInput.source_type || null,
          source_ref:
            pipelineInput.source_ref || pipelineInput.source_type || "raw_data",
          steps: pipelineInput.steps,
        },
      };
    }
    if (typeof pipelineInput.pipeline === "string") {
      const parsed = parsePipelineExpression(pipelineInput.pipeline);
      if (!parsed.ok) return parsed;
      return {
        ok: true,
        value: {
          source_type: pipelineInput.source_type || parsed.value.source_type,
          source_ref:
            pipelineInput.source_ref ||
            parsed.value.source_ref ||
            pipelineInput.source_type ||
            "raw_data",
          steps: parsed.value.steps,
        },
      };
    }
  }

  return {
    ok: false,
    errors: [
      "pipeline input must be a string, steps array, or pipeline object",
    ],
  };
}

function checkPipeline(document, pipelineInput, options = {}) {
  const validated = validateDocument(document, options);
  if (!validated.ok) return validated;

  const normalized = normalizePipelineInput(document, pipelineInput, options);
  if (!normalized.ok) return normalized;

  const capabilities = asCapabilityMap(document) || {};
  const steps = normalized.value.steps;

  if (!Array.isArray(steps) || steps.length === 0) {
    return { ok: false, errors: ["pipeline must contain at least one step"] };
  }

  const errors = [];
  for (let i = 0; i < steps.length; i += 1) {
    const step = steps[i];
    const capability = step && step.capability;
    const operation = step && step.operation;

    if (!capability || typeof capability !== "string") {
      errors.push(`step ${i + 1}: missing capability`);
      continue;
    }
    if (!operation || typeof operation !== "string") {
      errors.push(`step ${i + 1}: missing operation`);
      continue;
    }
    if (!capabilities[capability]) {
      errors.push(
        `step ${i + 1}: capability ${capability} is not declared in document.capabilities`,
      );
    }
  }

  if (errors.length > 0) return { ok: false, errors };

  return {
    ok: true,
    value: {
      valid: true,
      source: {
        type: normalized.value.source_type,
        ref: normalized.value.source_ref,
      },
      steps,
      step_count: steps.length,
    },
  };
}

function loadRegistry(registryPath = DEFAULT_REGISTRY_PATH) {
  const loaded = readJsonFile(registryPath, "capability registry");
  if (!loaded.ok) return loaded;
  return { ok: true, value: loaded.value };
}

function parseCapability(capabilityId) {
  const parts = String(capabilityId).split(".");
  if (!parts[0] || !parts[0].startsWith("&")) return null;
  const primitive = parts[0];
  const subtype = parts[1] || null;
  return { primitive, subtype };
}

function providersForCapability(registry, capabilityId) {
  const parsed = parseCapability(capabilityId);
  if (!parsed) return [];

  const primitiveEntry = registry[parsed.primitive];
  if (!primitiveEntry || !Array.isArray(primitiveEntry.providers)) return [];

  if (!parsed.subtype) {
    return [...primitiveEntry.providers];
  }

  return primitiveEntry.providers.filter((provider) =>
    Array.isArray(provider.subtypes)
      ? provider.subtypes.includes(parsed.subtype)
      : false,
  );
}

function resolveProvider(registry, capabilityId, binding) {
  const provider = binding.provider;

  if (provider !== "auto") {
    return {
      provider,
      resolution: {
        status: "explicit",
        provider,
      },
    };
  }

  const candidates = providersForCapability(registry, capabilityId)
    .filter((p) => p && typeof p.id === "string")
    .sort((a, b) => a.id.localeCompare(b.id));

  if (candidates.length === 0) {
    return {
      provider: "auto",
      unresolved: {
        provider: "auto",
        capabilities: [capabilityId],
        reason: `no registry provider found for capability ${capabilityId}`,
      },
    };
  }

  const selected = candidates[0];
  return {
    provider: selected.id,
    resolution: {
      status: "resolved-from-registry",
      provider: "auto",
      selected_provider: selected.id,
      protocol: selected.protocol || null,
      transport: selected.transport || null,
      url: selected.url || null,
    },
  };
}

function serverConfigFromProvider(providerId, providerMetadata, capabilities) {
  if (providerId === "graphonomous") {
    return {
      command: "npx",
      args: [
        "-y",
        "graphonomous",
        "--db",
        "~/.graphonomous/knowledge.db",
        "--embedder-backend",
        "fallback",
      ],
      env: {
        GRAPHONOMOUS_EMBEDDING_MODEL: "sentence-transformers/all-MiniLM-L6-v2",
      },
      transport: "stdio",
      capabilities,
    };
  }

  if (providerId === "ticktickclock") {
    return {
      command: "npx",
      args: ["-y", "@ampersand-protocol/ticktickclock-mcp"],
      env: {},
      transport: "stdio",
      capabilities,
    };
  }

  if (providerMetadata && providerMetadata.command) {
    return {
      command: providerMetadata.command,
      args: Array.isArray(providerMetadata.args) ? providerMetadata.args : [],
      env: providerMetadata.env || {},
      transport: providerMetadata.transport || "custom",
      url: providerMetadata.url || undefined,
      capabilities,
    };
  }

  return null;
}

function buildProviderIndex(registry) {
  const index = new Map();
  for (const [key, primitiveEntry] of Object.entries(registry)) {
    if (!key.startsWith("&")) continue;
    const providers = Array.isArray(primitiveEntry.providers)
      ? primitiveEntry.providers
      : [];
    for (const provider of providers) {
      if (
        provider &&
        typeof provider.id === "string" &&
        !index.has(provider.id)
      ) {
        index.set(provider.id, provider);
      }
    }
  }
  return index;
}

function generateMcpConfig(document, options = {}) {
  const validated = validateDocument(document, options);
  if (!validated.ok) return validated;

  const registryResult = loadRegistry(
    options.registryPath || DEFAULT_REGISTRY_PATH,
  );
  if (!registryResult.ok) return registryResult;

  const registry = registryResult.value;
  const providerIndex = buildProviderIndex(registry);
  const capabilities = asCapabilityMap(document) || {};

  const grouped = new Map();
  const unresolved = [];

  for (const [capabilityId, binding] of Object.entries(capabilities)) {
    const resolved = resolveProvider(registry, capabilityId, binding);

    if (resolved.unresolved) {
      unresolved.push(resolved.unresolved);
      continue;
    }

    if (!grouped.has(resolved.provider)) grouped.set(resolved.provider, []);
    grouped.get(resolved.provider).push(capabilityId);
  }

  const servers = {};
  for (const [providerId, caps] of grouped.entries()) {
    const metadata = providerIndex.get(providerId);
    const config = serverConfigFromProvider(
      providerId,
      metadata,
      [...caps].sort(),
    );

    if (!config) {
      unresolved.push({
        provider: providerId,
        capabilities: [...caps].sort(),
        reason: "no MCP resolver registered for provider",
      });
      continue;
    }

    servers[providerId] = config;
  }

  const format = options.format === "generic" ? "generic" : "zed";
  const rootKey = format === "generic" ? "mcpServers" : "context_servers";

  return {
    ok: true,
    value: {
      agent: document.agent,
      version: document.version,
      format,
      config: { [rootKey]: servers },
      unresolved_providers: unresolved,
    },
  };
}

module.exports = {
  DEFAULT_SCHEMA_PATH,
  DEFAULT_REGISTRY_PATH,
  validateDocument,
  validateFile,
  normalizeCapabilities,
  composeCapabilityMaps,
  composeDocuments,
  composeFiles,
  parsePipelineExpression,
  checkPipeline,
  generateMcpConfig,
  loadRegistry,
};
