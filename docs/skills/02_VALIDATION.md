# Skill 02 — Validation

> Running schema validation on agent declarations — via CLI, npm SDK, or
> Python SDK. How to read errors and fix them.

---

## Why This Matters

Validation catches declaration errors before they reach composition or
generation. A malformed `ampersand.json` cannot produce correct MCP or A2A
output. Validate early and often.

---

## CLI Validation

### Basic usage

```bash
cd reference/elixir/ampersand_core
./ampersand validate ../../examples/infra-operator.ampersand.json
```

**Success output:**
```
OK  infra-operator.ampersand.json
  Agent: InfraOperator v1.0.0
  Capabilities: 6
  Governance: hard=1 soft=1 escalation=yes
  Provenance: enabled
```

**Failure output:**
```
FAIL  broken-agent.ampersand.json
  errors:
    - /agent: Required property missing
    - /capabilities/&memory: Invalid capability identifier (missing subtype)
    - /governance/escalate_when/confidence_below: Expected number, got string
```

### Flags

| Flag | Effect |
|------|--------|
| `--format json` | Output validation results as JSON |
| `--format text` | Human-readable output (default) |
| `--schema <path>` | Use a local schema file instead of the default |
| `--quiet` | Suppress success output, only show errors |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Valid declaration |
| `1` | Schema validation errors |
| `2` | File not found or unreadable |

---

## Schema Validation Rules

The canonical schema lives at
`protocol/schema/v0.1.0/ampersand.schema.json` and uses JSON Schema
draft 2020-12.

### Required fields

| Field | Type | Constraint |
|-------|------|-----------|
| `agent` | string | Non-empty, matches `^[A-Za-z][A-Za-z0-9_-]*$` |
| `version` | string | Valid semver (`X.Y.Z`) |
| `capabilities` | object | At least one capability entry |

### Capability entry rules

Each key must match `^&(memory|reason|time|space)\.[a-z][a-z0-9_]*$`.

Each value must have:
- `provider` — string (provider name or `"auto"`)
- `config` — object (provider-specific, no schema constraints)

### Governance rules (when present)

- `hard` — array of strings (inviolable constraints)
- `soft` — array of strings (preferences)
- `escalate_when` — object with numeric or boolean trigger fields
- `autonomy.level` — one of `"observe"`, `"advise"`, `"act"`
- `autonomy.model_tier` — one of `"local_small"`, `"local_large"`, `"cloud_frontier"`

---

## Common Validation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Required property 'agent' missing` | No `agent` field | Add `"agent": "YourAgentName"` |
| `Invalid capability identifier` | Key does not match `&primitive.subtype` | Use format `&memory.graph`, not `memory.graph` or `&memory` |
| `Empty capabilities object` | No capabilities declared | Add at least one capability |
| `Invalid version format` | Non-semver string | Use `"1.0.0"`, not `"v1"` or `"1.0"` |
| `Unknown autonomy level` | Typo in level value | Must be `"observe"`, `"advise"`, or `"act"` |
| `Expected number, got string` | Wrong type in escalation rule | Check types in `escalate_when` |

---

## Batch Validation

Validate multiple files by passing them as arguments:

```bash
./ampersand validate examples/*.ampersand.json
```

Output shows pass/fail for each file:

```
OK    infra-operator.ampersand.json
OK    research-agent.ampersand.json
OK    customer-support.ampersand.json
FAIL  broken.ampersand.json
  errors:
    - /capabilities: Must have at least 1 property
```

Exit code is `1` if any file fails.

---

## Programmatic Validation — npm SDK

The `@ampersand-protocol/validate` package provides schema validation
for JavaScript/TypeScript projects:

```bash
npm install @ampersand-protocol/validate
```

```javascript
import { validate } from '@ampersand-protocol/validate';

const result = validate('./agent.ampersand.json');

if (result.valid) {
  console.log(`Agent: ${result.agent} v${result.version}`);
  console.log(`Capabilities: ${result.capabilityCount}`);
} else {
  for (const error of result.errors) {
    console.error(`${error.path}: ${error.message}`);
  }
}
```

The SDK uses `ajv` (JSON Schema draft 2020-12) under the hood.

---

## Programmatic Validation — Python SDK

The `ampersand-protocol` Python package provides equivalent functionality:

```bash
pip install ampersand-protocol
```

```python
from ampersand_protocol import validate

result = validate("agent.ampersand.json")

if result.valid:
    print(f"Agent: {result.agent} v{result.version}")
else:
    for error in result.errors:
        print(f"{error.path}: {error.message}")
```

---

## Validation in CI/CD

Add schema validation to your pipeline to catch declaration errors before
deployment:

```yaml
# GitHub Actions example
- name: Validate agent declarations
  run: |
    npx @ampersand-protocol/validate agents/*.ampersand.json
```

This ensures all declarations in the repository conform to the schema
before any downstream tooling runs.
