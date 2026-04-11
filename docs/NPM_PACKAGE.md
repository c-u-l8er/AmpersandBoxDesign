# box-and-box — NPM Package Specification

**Package**: `box-and-box`
**Version**: `0.1.0` (initial)
**Language**: TypeScript (pure JS)
**License**: Apache-2.0
**Registry**: https://www.npmjs.com/package/box-and-box
**Repository**: `AmpersandBoxDesign` (monorepo root)

## Purpose

`box-and-box` is the MCP server for the [&] Protocol. It validates
`*.ampersand.json` documents against the canonical JSON Schema, composes
capability manifests, generates MCP and A2A runtime configuration, inspects
the capability registry, and exposes the spec graph to agents as structured
MCP tools.

`box-and-box` is **pure TypeScript**. The Elixir reference implementation in
`reference/elixir/ampersand_core` remains the authoritative source of the
`ampersand` validation and composition logic during protocol development, but
for v0.1 of the npm package the validate/compose/check logic is reimplemented
in TypeScript against the same JSON Schema 2020-12 artifacts under
`protocol/schema/v0.1.0/`. The npm package and the Elixir escript share test
fixtures in `examples/*.ampersand.json` to guarantee behavioural parity.

## Install

```bash
npx -y box-and-box --db ~/.box-and-box/specs.db
```

Or in `.mcp.json`:

```jsonc
{
  "mcpServers": {
    "ampersand": {
      "command": "npx",
      "args": ["-y", "box-and-box", "--db", "~/.box-and-box/specs.db"]
    }
  }
}
```

## CLI Flags

| Flag                    | Default                    | Description                                        |
|-------------------------|----------------------------|----------------------------------------------------|
| `--db <path>`           | `~/.box-and-box/specs.db`  | SQLite database path (auto-created).               |
| `--transport`           | `stdio`                    | `stdio` or `http`.                                 |
| `--port <n>`            | `4711`                     | HTTP port (ignored for stdio).                     |
| `--schema-version`      | `v0.1.0`                   | Which bundled schema version to validate against.  |
| `--registry-path <p>`   | bundled `contracts/v0.1.0/`| Override capability contract registry location.    |
| `--log-level`           | `info`                     | `debug`, `info`, `warn`, `error`.                  |
| `--version` / `--help`  | —                          | Print and exit.                                    |

The same binary also runs as a **one-shot CLI** for scripts and CI:

```bash
npx box-and-box validate ./examples/infra-operator.ampersand.json
npx box-and-box compose ./examples/infra-operator.ampersand.json ./examples/mailroom.ampersand.json
npx box-and-box generate mcp ./examples/infra-operator.ampersand.json -o mcp.json
```

One-shot mode bypasses the MCP server and prints JSON to stdout (parity with
the Elixir escript).

## Dependencies

| Dependency                 | Version   | Why                                                       |
|----------------------------|-----------|-----------------------------------------------------------|
| `@modelcontextprotocol/sdk`| `^1.29.0` | Stable v1.x MCP surface.                                  |
| `better-sqlite3`           | `^12.8.0` | SQLite bindings for spec persistence.                      |
| `sqlite-vec`               | `^0.1.10` | Vector index over capability descriptions (future).       |
| `ajv`                      | `^8.17.0` | JSON Schema 2020-12 validator.                            |
| `ajv-formats`              | `^3.0.1`  | Standard formats.                                         |
| `zod`                      | `^3.23.0` | Tool input schemas.                                       |
| `yargs`                    | `^17.7.0` | CLI parsing.                                              |
| `json-source-map`          | `^0.6.1`  | Line/column hints in validation errors.                   |

## SQLite Schema

```sql
-- Registered agent specs.
CREATE TABLE IF NOT EXISTS specs (
  id             TEXT PRIMARY KEY,                -- sha256 of canonical JSON
  agent          TEXT NOT NULL,
  version        TEXT NOT NULL,
  schema_version TEXT NOT NULL,                   -- e.g. "v0.1.0"
  source_path    TEXT,                            -- absolute path if loaded from disk
  source_hash    TEXT NOT NULL,
  spec_json      TEXT NOT NULL,                   -- canonical JSON text
  registered_at  INTEGER NOT NULL
);

-- Validation history per spec.
CREATE TABLE IF NOT EXISTS validations (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  spec_id        TEXT NOT NULL,
  validator      TEXT NOT NULL,                   -- schema | contract | registry | composition
  status         TEXT NOT NULL,                   -- pass | fail
  errors_json    TEXT,                            -- ajv errors array if failed
  validated_at   INTEGER NOT NULL,
  FOREIGN KEY (spec_id) REFERENCES specs (id)
);

-- Composition results (N specs → 1 composed spec).
CREATE TABLE IF NOT EXISTS compositions (
  id             TEXT PRIMARY KEY,                -- sha256 of inputs + operator
  input_ids      TEXT NOT NULL,                   -- JSON array of spec ids
  output_json    TEXT NOT NULL,
  status         TEXT NOT NULL,                   -- pass | fail | conflict
  conflicts_json TEXT,
  composed_at    INTEGER NOT NULL
);

-- Snapshot of capability contracts bundled with this server version.
CREATE TABLE IF NOT EXISTS capabilities (
  name           TEXT PRIMARY KEY,                -- e.g. "&memory.graph"
  category       TEXT NOT NULL,                   -- memory | reason | time | space | govern
  contract_json  TEXT NOT NULL
);
```

## MCP Tools Exposed

| Tool              | Purpose                                                          |
|-------------------|------------------------------------------------------------------|
| `validate`        | Validate a spec against `ampersand.schema.json` (draft 2020-12). |
| `validate_contract`| Validate a capability contract against `capability-contract.schema.json`. |
| `validate_registry`| Validate the registry against `registry.schema.json`.           |
| `compose`         | Compose N specs into one, checking ACI properties.               |
| `check`           | Check a pipeline expression against a spec's type contracts.     |
| `plan`            | Produce an execution plan for a pipeline.                        |
| `generate_mcp`    | Emit MCP configuration from a spec.                              |
| `generate_a2a`    | Emit A2A agent card from a spec.                                 |
| `diff`            | Diff two specs and return added/removed/changed capabilities.    |
| `inspect_spec`    | Return the capability graph + provenance metadata.               |
| `registry_list`   | List capabilities in the bundled registry.                       |
| `registry_providers`| List providers for a given capability.                         |

## MCP Resources Exposed

| URI                                   | Returns                                    |
|---------------------------------------|--------------------------------------------|
| `ampersand://runtime/health`          | Server health, spec counts.                |
| `ampersand://specs/recent`            | Recently registered/validated specs.       |
| `ampersand://registry/capabilities`   | Full registry snapshot.                    |
| `ampersand://spec/{id}`               | Canonical JSON of a spec by hash id.       |

## Project Layout

```
AmpersandBoxDesign/
├── package.json                         # at repo root, "name": "box-and-box"
├── tsconfig.json
├── bin/
│   └── box-and-box.js
├── src/
│   ├── server.ts                        # MCP wiring
│   ├── db.ts
│   ├── validate/
│   │   ├── schema.ts
│   │   ├── contract.ts
│   │   └── registry.ts
│   ├── compose.ts
│   ├── check.ts
│   ├── plan.ts
│   ├── generate/
│   │   ├── mcp.ts
│   │   └── a2a.ts
│   ├── diff.ts
│   ├── inspect.ts
│   ├── tools/ …
│   ├── resources/ …
│   └── cli.ts
└── protocol/                             # existing schema artifacts (bundled)
    └── schema/v0.1.0/
        ├── ampersand.schema.json
        ├── capability-contract.schema.json
        └── registry.schema.json
```

The existing `sdk/npm/validate/` package (`@ampersand-protocol/validate`)
remains in place for backward compatibility and is deprecated in favour of
`box-and-box` for new users. Its JSON Schema validation code is reused by
`box-and-box` where possible.

## Parity with the Elixir Reference

The Elixir `ampersand` escript remains the reference implementation during
protocol development. `box-and-box` publishes against the same test fixtures
under `examples/*.ampersand.json`, and the test suite asserts byte-for-byte
equivalent JSON output for `validate`, `compose`, `generate mcp`, and
`generate a2a` for the canonical fixtures. Any divergence is a bug in
`box-and-box`, not a spec change.

## Why box-and-box ships second

1. Depends on `os-pulse` only for registering its own loop manifest (trivial).
2. Pure JS, no native binary — same install story as `os-pulse`.
3. Validates a well-known schema that already has extensive test fixtures.
4. Unblocks `os-prism`, which reads `*.ampersand.json` to understand the
   capability graph of the system under test.
