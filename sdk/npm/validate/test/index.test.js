const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const {
  validateFile,
  composeFiles,
  checkPipeline,
  generateMcpConfig,
} = require("../src/index.js");

function repoRoot() {
  return path.resolve(__dirname, "../../../../");
}

function examplePath(name) {
  return path.join(repoRoot(), "examples", name);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

test("validateFile succeeds for infra-operator example", () => {
  const result = validateFile(examplePath("infra-operator.ampersand.json"));
  assert.equal(result.ok, true);
  assert.equal(result.value.agent, "InfraOperator");
  assert.equal(typeof result.value.capabilities, "object");
});

test("composeFiles merges compatible declarations", () => {
  const base = readJson(examplePath("infra-operator.ampersand.json"));

  const addon = {
    $schema: "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
    agent: "ComposeAddon",
    version: "0.1.0",
    capabilities: {
      "&memory.vector": {
        provider: "pgvector",
        config: { index: "incidents" },
      },
    },
    provenance: true,
  };

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "ampersand-validate-test-"));
  const basePath = path.join(tempDir, "base.ampersand.json");
  const addonPath = path.join(tempDir, "addon.ampersand.json");

  fs.writeFileSync(basePath, JSON.stringify(base, null, 2));
  fs.writeFileSync(addonPath, JSON.stringify(addon, null, 2));

  const composed = composeFiles([basePath, addonPath]);

  assert.equal(composed.ok, true);
  assert.equal(composed.value.capability_count, 5);
  assert.ok(composed.value.normalized.includes("&memory.graph"));
  assert.ok(composed.value.normalized.includes("&memory.vector"));
});

test("composeFiles detects conflicting bindings", () => {
  const left = {
    $schema: "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
    agent: "Left",
    version: "0.1.0",
    capabilities: {
      "&memory.graph": { provider: "graphonomous" },
    },
  };

  const right = {
    $schema: "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
    agent: "Right",
    version: "0.1.0",
    capabilities: {
      "&memory.graph": { provider: "neo4j-memory" },
    },
  };

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "ampersand-validate-test-"));
  const leftPath = path.join(tempDir, "left.ampersand.json");
  const rightPath = path.join(tempDir, "right.ampersand.json");

  fs.writeFileSync(leftPath, JSON.stringify(left, null, 2));
  fs.writeFileSync(rightPath, JSON.stringify(right, null, 2));

  const composed = composeFiles([leftPath, rightPath]);

  assert.equal(composed.ok, false);
  assert.ok(
    composed.errors.some((e) => e.includes("conflicting_binding") || e.includes("&memory.graph"))
  );
});

test("checkPipeline validates inline expression for declared capabilities", () => {
  const document = readJson(examplePath("infra-operator.ampersand.json"));

  const checked = checkPipeline(
    document,
    "stream_data |> &time.anomaly.detect() |> &memory.graph.enrich() |> &reason.argument.evaluate()"
  );

  assert.equal(checked.ok, true);
  assert.equal(checked.value.valid, true);
  assert.equal(checked.value.step_count, 3);
});

test("checkPipeline validates named pipeline from declaration", () => {
  const document = readJson(examplePath("infra-operator.ampersand.json"));

  const checked = checkPipeline(document, null, { pipelineName: "incident_triage" });

  assert.equal(checked.ok, true);
  assert.equal(checked.value.valid, true);
  assert.equal(checked.value.step_count, 3);
});

test("generateMcpConfig resolves auto providers from registry where possible", () => {
  const document = readJson(examplePath("fleet-manager.ampersand.json"));

  const generated = generateMcpConfig(document, { format: "zed" });

  assert.equal(generated.ok, true);
  assert.equal(generated.value.format, "zed");
  assert.ok(generated.value.config.context_servers.graphonomous);
  assert.ok(generated.value.config.context_servers.ticktickclock);

  const unresolvedProviders = generated.value.unresolved_providers.map((u) => u.provider);
  assert.ok(unresolvedProviders.includes("deliberatic"));
  assert.ok(unresolvedProviders.includes("geofleetic"));
});
