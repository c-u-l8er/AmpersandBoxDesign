# box-and-box

**Reference MCP server for the [&] Protocol.**

One of four MCP servers in the [&] three-protocol stack:

| Package        | Role                                     | Install                                                          |
|----------------|------------------------------------------|------------------------------------------------------------------|
| `box-and-box`  | [&] Protocol validator / composer (**this**) | `npx -y box-and-box --db ~/.box-and-box/specs.db`            |
| `graphonomous` | Memory loop (5 machines)                 | `npx -y graphonomous --db ~/.graphonomous/knowledge.db`          |
| `os-prism`     | Diagnostic loop (6 machines)             | `npx -y os-prism --db ~/.os-prism/benchmarks.db`                 |
| `os-pulse`     | PULSE manifest registry                  | `npx -y os-pulse --db ~/.os-pulse/manifests.db`                  |

## What box-and-box does

- Validates `*.ampersand.json` agent declarations against
  `ampersand.schema.json` (JSON Schema draft 2020-12).
- Validates capability contracts against `capability-contract.schema.json`
  and the bundled registry against `registry.schema.json`.
- Composes N specs into one (ACI / idempotent capability merging with
  conflict detection).
- Checks pipelines declared with `|>` against a spec's capability set.
- Generates MCP server configuration (`zed` or `generic` format) and A2A
  agent cards from a spec.
- Persists registered specs and validation history in an embedded SQLite
  database.
- Exposes 12 MCP tools and 3 resources over stdio.

## MCP tools

| Tool                 | Description                                                   |
|----------------------|---------------------------------------------------------------|
| `validate`           | Validate a spec; optionally persist it.                       |
| `validate_contract`  | Validate a capability contract.                               |
| `validate_registry`  | Validate a capability registry.                               |
| `compose`            | Compose N specs into one; detect conflicts.                   |
| `check`              | Check a pipeline against a spec's capabilities.               |
| `generate_mcp`       | Emit MCP server configuration from a spec.                    |
| `generate_a2a`       | Emit an A2A agent card from a spec.                           |
| `inspect_spec`       | Return a structured capability graph.                         |
| `diff`               | Diff two specs (added / removed / changed capabilities).     |
| `registry_list`      | List primitive capabilities in the bundled registry.          |
| `registry_providers` | List providers for a given capability id.                     |

## MCP resources

| URI                                 | Returns                                |
|-------------------------------------|----------------------------------------|
| `ampersand://runtime/health`        | Server health + counts.                |
| `ampersand://specs/recent`          | Recently registered specs.             |
| `ampersand://registry/capabilities` | Full bundled registry snapshot.        |

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

## One-shot CLI mode

The same binary runs as a plain CLI for scripts and CI — it bypasses the
MCP server and prints JSON to stdout:

```bash
npx box-and-box validate ./examples/infra-operator.ampersand.json
npx box-and-box compose ./examples/infra-operator.ampersand.json \
                        ./examples/fleet-manager.ampersand.json
npx box-and-box check ./examples/infra-operator.ampersand.json \
                      --pipeline incident_triage
npx box-and-box generate mcp ./examples/infra-operator.ampersand.json
npx box-and-box generate a2a ./examples/infra-operator.ampersand.json
npx box-and-box inspect ./examples/infra-operator.ampersand.json
```

## Flags

| Flag                 | Default                       |
|----------------------|-------------------------------|
| `--db <path>`        | `~/.box-and-box/specs.db`     |
| `--transport`        | `stdio` (only; HTTP planned)  |
| `--port`             | `4711` (ignored for stdio)    |
| `--schema-version`   | `v0.1.0`                      |
| `--log-level`        | `info`                        |

## Build from source

```bash
git clone https://github.com/c-u-l8er/AmpersandBoxDesign
cd AmpersandBoxDesign/box-and-box
npm install
npm run build
node bin/box-and-box.js --help
```

## Parity with the Elixir reference

The Elixir `ampersand` escript in
`AmpersandBoxDesign/reference/elixir/ampersand_core/` remains the
authoritative reference during protocol development. `box-and-box` shares
the exact same JSON Schema artifacts and test fixtures under
`examples/*.ampersand.json`. Any divergence is a bug in `box-and-box`,
not a protocol change.

## Spec

- [`docs/NPM_PACKAGE.md`](../docs/NPM_PACKAGE.md) — full package specification
- [`SPEC.md`](../SPEC.md) — [&] Protocol draft v0.1.0
- [`protocol/schema/v0.1.0/`](../protocol/schema/v0.1.0/) — JSON Schemas
- [`contracts/v0.1.0/`](../contracts/v0.1.0/) — capability contracts

## License

Apache-2.0
