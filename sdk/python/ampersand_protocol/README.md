# ampersand-protocol (Python SDK)

Minimal Python SDK for working with `ampersand.json` declarations in the [&] Protocol.

This package provides:

- JSON Schema validation for declarations
- Capability normalization and composition
- Lightweight MCP config generation
- A small CLI for CI and local workflows

---

## Install

From source in this repository:

```bash
cd ProjectAmp2/AmpersandBoxDesign/sdk/python/ampersand_protocol
pip install -e .
```

Or with a standard install:

```bash
pip install .
```

---

## Python version

- Python `3.9+`

---

## Quick CLI usage

After install, the `ampersand` command is available.

### Validate a declaration

```bash
ampersand validate ../../../examples/infra-operator.ampersand.json
```

### Compose declarations

```bash
ampersand compose ../../../examples/infra-operator.ampersand.json ../../../examples/research-agent.ampersand.json
```

### Generate MCP config

```bash
ampersand generate mcp ../../../examples/infra-operator.ampersand.json
```

### Write MCP config to file

```bash
ampersand generate mcp ../../../examples/infra-operator.ampersand.json --output /tmp/mcp.json
```

---

## Programmatic API

```python
from ampersand_protocol import (
    validate_file,
    validate_document,
    normalize_capabilities,
    compose_capabilities,
    generate_mcp_config,
)

result = validate_file("examples/infra-operator.ampersand.json")
if not result.ok:
    print(result.errors)
    raise SystemExit(1)

doc = result.value
print(normalize_capabilities(doc))
```

---

## Validate decoded document

```python
import json
from ampersand_protocol import validate_document

with open("examples/infra-operator.ampersand.json", "r", encoding="utf-8") as f:
    document = json.load(f)

validation = validate_document(document)
if validation.ok:
    print("valid")
else:
    print(validation.errors)
```

---

## Compose capability sets

```python
from ampersand_protocol import compose_capabilities

composed = compose_capabilities([doc_a, doc_b, doc_c])

if not composed.ok:
    print(composed.errors)
else:
    print(composed.value["capabilities"])
```

Composition behavior:

- disjoint capability sets merge
- identical duplicate bindings are idempotent
- conflicting bindings for same capability return an error

---

## MCP generation

```python
from ampersand_protocol import generate_mcp_config

mcp = generate_mcp_config(doc, format="zed")
if mcp.ok:
    print(mcp.value)
else:
    print(mcp.errors)
```

Supported formats:

- `"zed"` -> `{"context_servers": ...}`
- `"generic"` -> `{"mcpServers": ...}`

---

## Output format conventions

Both CLI and API return structured data:

- success: `status = "ok"` (CLI) or `result.ok == True` (API)
- failure: `status = "error"` with `errors[]` (CLI), or `result.ok == False` with `errors` (API)

This keeps CI integration predictable.

---

## Schema source

Bundled schema file:

- `src/ampersand_protocol/schema/ampersand.schema.json`

Canonical protocol schema source:

- `../../../../protocol/schema/v0.1.0/ampersand.schema.json`

---

## Scope note

This Python SDK is intentionally minimal and practical for validation + composition workflows.

For full contract-backed planning/execution, use the Elixir reference runtime in:

- `reference/elixir/ampersand_core/`
