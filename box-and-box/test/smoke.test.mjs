/**
 * Smoke tests for the core box-and-box library surface.
 *
 * Tests run against compiled dist/ (so `npm test` also runs `npm run build`
 * via the pretest hook). Sources use `.js` extension imports for
 * NodeNext compatibility, which would otherwise fight with
 * --experimental-strip-types.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { AmpersandValidator } from "../dist/validate.js";
import { composeDocuments } from "../dist/compose.js";
import { checkPipeline } from "../dist/check.js";
import { generateMcp, generateA2a } from "../dist/generate.js";
import { inspectSpec } from "../dist/inspect.js";
import { loadRegistry } from "../dist/registry.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const examplesDir = path.resolve(here, "..", "..", "examples");
const infraOperator = path.join(examplesDir, "infra-operator.ampersand.json");
const fleetManager = path.join(examplesDir, "fleet-manager.ampersand.json");

function readDoc(p) {
  return JSON.parse(readFileSync(p, "utf8"));
}

test("infra-operator example validates against v0.1.0 schema", () => {
  const v = new AmpersandValidator();
  const doc = readDoc(infraOperator);
  const result = v.validateSpec(doc);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
});

test("missing required field fails validation", () => {
  const v = new AmpersandValidator();
  const doc = readDoc(infraOperator);
  const broken = { ...doc };
  delete broken.capabilities;
  const result = v.validateSpec(broken);
  assert.equal(result.valid, false);
  assert.ok(result.errors.length > 0);
});

test("compose two valid specs succeeds when bindings match", () => {
  const doc = readDoc(infraOperator);
  const result = composeDocuments([doc, doc]);
  assert.equal(result.ok, true);
  assert.equal(result.capability_count, Object.keys(doc.capabilities).length);
});

test("compose detects conflicting bindings", () => {
  const a = readDoc(infraOperator);
  const b = JSON.parse(JSON.stringify(a));
  const firstCap = Object.keys(b.capabilities)[0];
  b.capabilities[firstCap] = { provider: "something-else" };
  const result = composeDocuments([a, b]);
  assert.equal(result.ok, false);
  assert.ok(result.conflicts.length > 0);
});

test("checkPipeline resolves a named pipeline", () => {
  const doc = readDoc(infraOperator);
  const firstPipeline = Object.keys(doc.pipelines)[0];
  const result = checkPipeline(doc, { pipelineName: firstPipeline });
  assert.equal(result.ok, true);
});

test("inspectSpec returns a graph summary", () => {
  const doc = readDoc(infraOperator);
  const graph = inspectSpec(doc);
  assert.equal(graph.agent, doc.agent);
  assert.ok(graph.capability_count > 0);
});

test("generate_a2a produces an agent card", () => {
  const doc = readDoc(infraOperator);
  const card = generateA2a(doc);
  assert.equal(card.agent, doc.agent);
  assert.ok(card.capabilities.length > 0);
});

test("generate_mcp produces a config referencing declared providers", () => {
  const v = new AmpersandValidator();
  const doc = readDoc(infraOperator);
  const registry = loadRegistry(v.artifacts.registryFile);
  const result = generateMcp(doc, registry, { format: "generic" });
  assert.equal(result.agent, doc.agent);
  assert.ok(
    Object.keys(result.config.mcpServers).length > 0 ||
      result.unresolved_providers.length > 0,
  );
});

test("fleet-manager example also validates", () => {
  const v = new AmpersandValidator();
  const doc = readDoc(fleetManager);
  const result = v.validateSpec(doc);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
});
