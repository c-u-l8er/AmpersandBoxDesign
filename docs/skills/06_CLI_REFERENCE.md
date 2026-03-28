# Skill 06 — CLI Reference

> Complete command reference for the `ampersand` CLI tool — flags, output
> formats, exit codes, and common workflows.

---

## Overview

The `ampersand` CLI is the primary interface for working with [&] Protocol
declarations. It validates, composes, and generates runtime artifacts.

### Installation

**Elixir escript (reference implementation):**
```bash
cd reference/elixir/ampersand_core
mix deps.get
mix escript.build
# Binary: ./ampersand
```

**npm (planned):**
```bash
npm install -g @ampersand/cli
```

---

## validate

Validate an agent declaration against the JSON Schema.

### Usage

```bash
ampersand validate <file> [flags]
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--format text` | `text` | Output format: `text` or `json` |
| `--schema <path>` | built-in | Path to a custom schema file |
| `--quiet` | off | Suppress success output, only show errors |

### Output (text)

```
OK  infra-operator.ampersand.json
  Agent: InfraOperator v1.0.0
  Capabilities: 6
  Governance: hard=1 soft=1 escalation=yes
  Provenance: enabled
```

### Output (json)

```json
{
  "file": "infra-operator.ampersand.json",
  "valid": true,
  "agent": "InfraOperator",
  "version": "1.0.0",
  "capabilities_count": 6,
  "errors": []
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All files valid |
| `1` | One or more validation errors |
| `2` | File not found or unreadable |

---

## compose

Check capability compatibility, ACI normalization, and pipeline type safety.

### Usage

```bash
ampersand compose <file> [flags]
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--format text` | `text` | Output format: `text` or `json` |
| `--verbose` | off | Show detailed type-checking trace |

### Output (text)

```
OK  infra-operator.ampersand.json
  Capability set: &memory.graph & &time.anomaly & &reason.argument
  ACI normal form: &memory.graph & &reason.argument & &time.anomaly
  Pipelines: incident_triage (3 steps, type-safe)
  Providers: graphonomous, ticktickclock, deliberatic
```

### Output (verbose)

```
  Pipeline: incident_triage
    Step 1: &time.anomaly.detect()
      Input:  stream_data (from source_ref)
      Output: anomaly_set
    Step 2: &memory.graph.enrich()
      Input:  anomaly_set (matches &time.* in accepts_from) OK
      Output: enriched_context
    Step 3: &reason.argument.evaluate()
      Input:  enriched_context (matches &memory.* in accepts_from) OK
      Output: evaluation_result
    Pipeline type-safe: YES
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Composition valid |
| `1` | Composition errors (type mismatch, missing provider) |
| `2` | File not found or unreadable |

---

## generate mcp

Generate an MCP server configuration from a declaration.

### Usage

```bash
ampersand generate mcp <file> [flags]
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--output <path>` | stdout | Write output to file |
| `--compact` | off | Minified JSON output |
| `--transport <type>` | `stdio` | MCP transport: `stdio` or `http` |
| `--provider <override>` | none | Override a provider: `"&cap=provider"` |

### Output

JSON object with `mcpServers` key containing one entry per provider. Each
entry includes `command`, `args`, `transport`, `tools`, and optionally
`resources`.

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Generation succeeded |
| `1` | Validation or composition errors |
| `2` | File not found or unreadable |

---

## generate a2a

Generate an A2A agent card from a declaration.

### Usage

```bash
ampersand generate a2a <file> [flags]
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--output <path>` | stdout | Write output to file |
| `--compact` | off | Minified JSON output |

### Output

JSON object conforming to the A2A agent card format with `name`, `version`,
`description`, `skills`, and `capabilities` fields.

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Generation succeeded |
| `1` | Validation or composition errors |
| `2` | File not found or unreadable |

---

## Common Workflows

### Validate, compose, and generate in sequence

```bash
ampersand validate agent.ampersand.json && \
ampersand compose agent.ampersand.json && \
ampersand generate mcp agent.ampersand.json --output mcp-config.json && \
ampersand generate a2a agent.ampersand.json --output agent-card.json
```

Note: `generate` includes validation and composition internally. The
explicit steps above are useful when you want to see intermediate output
or fail fast.

### Batch validate a directory

```bash
ampersand validate agents/*.ampersand.json
```

### Generate both artifacts at once

```bash
ampersand generate mcp agent.ampersand.json --output mcp-config.json
ampersand generate a2a agent.ampersand.json --output agent-card.json
```

### Pipe to jq for inspection

```bash
ampersand generate mcp agent.ampersand.json | jq '.mcpServers | keys'
ampersand generate a2a agent.ampersand.json | jq '.skills[].id'
```

---

## Error Handling

All commands write errors to stderr and return non-zero exit codes.

**Validation error example:**
```
FAIL  agent.ampersand.json
  errors:
    - /agent: Required property missing
    - /capabilities/&memory: Invalid capability identifier (missing subtype)
```

**Composition error example:**
```
FAIL  agent.ampersand.json
  errors:
    - Pipeline "triage" step 2: type mismatch — &memory.graph.enrich()
      does not accept "forecast_set"
```

**File error example:**
```
ERROR  File not found: nonexistent.ampersand.json
```

Errors include the JSON path where the problem occurred, making it
straightforward to locate and fix issues in the declaration.
