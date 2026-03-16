# `@ampersand-protocol/validate`

Minimal TypeScript/Node validator and CLI for [`ampersand.json`](../../../schema/v0.1.0/ampersand.schema.json) declarations.

This package is designed for fast CI checks and local validation without needing the Elixir reference runtime.

---

## Install

### One-off via `npx`

```bash
npx @ampersand-protocol/validate validate ./examples/infra-operator.ampersand.json
```

### As a dependency

```bash
npm install @ampersand-protocol/validate
```

---

## CLI usage

### Validate a declaration

```bash
npx @ampersand-protocol/validate validate ./agent.ampersand.json
```

### Compose one or more declarations

```bash
npx @ampersand-protocol/validate compose ./a.ampersand.json ./b.ampersand.json
```

### Check a pipeline against a declaration (capability presence + step shape)

```bash
npx @ampersand-protocol/validate check ./agent.ampersand.json "stream_data |> &time.anomaly.detect() |> &memory.graph.enrich()"
```

### Check a named pipeline in declaration

```bash
npx @ampersand-protocol/validate check ./agent.ampersand.json --pipeline incident_triage
```

---

## Programmatic API

```js
import {
  validateFile,
  validateDocument,
  composeCapabilities,
  normalizeCapabilities,
  checkPipeline,
  generateMcpConfig
} from "@ampersand-protocol/validate";

const result = validateFile("./agent.ampersand.json");

if (!result.ok) {
  console.error(result.errors);
  process.exit(1);
}
```

### Validate decoded JSON

```js
const doc = JSON.parse(fs.readFileSync("./agent.ampersand.json", "utf8"));
const validation = validateDocument(doc);

if (validation.ok) {
  console.log("valid");
} else {
  console.log(validation.errors);
}
```

### Compose capability sets

```js
const composed = composeCapabilities([docA, docB, docC]);
// { ok: true, capabilities: {...} } or conflict error
```

### Generate MCP-style config map

```js
const mcp = generateMcpConfig(doc, { format: "zed" });
// { context_servers: {...} }
```

---

## Output format

CLI commands return JSON:

- success: `{ "status": "ok", ... }`
- error: `{ "status": "error", "error": "...", "errors": ["..."] }`

This makes the package easy to consume in CI pipelines and scripts.

---

## Schema source

The bundled schema is synchronized from:

- `schema/v0.1.0/ampersand.schema.json`

If you update protocol schema fields, re-sync this package before publishing.

---

## Notes

- This package focuses on validation and lightweight composition checks.
- For full contract-backed runtime planning/execution, use the Elixir reference implementation in:
  - `reference/elixir/ampersand_core/`
