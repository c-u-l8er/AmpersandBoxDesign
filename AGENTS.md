# [&] Protocol — AmpersandBoxDesign

Open specification for capability composition in AI agents. Defines memory, reasoning, time, and space primitives that compile into MCP and A2A configurations.

## Implementation prompts

- `prompts/PROTOCOL_PROMPT.md` — implementation prompt for generating [&] Protocol code (project identity, architecture, formal grammar, coding standards)
- `prompts/GRAPHONOMOUS_PROMPT.md` — autonomous traversal prompt for Graphonomous MCP

These serve the same role as `project_spec/` in other portfolio projects. Read before modifying the reference implementation.

## Build and test

```
cd reference/elixir/ampersand_core && mix deps.get && mix escript.build && mix test
```

## CLI

```
cd reference/elixir/ampersand_core
./ampersand validate ../../../examples/infra-operator.ampersand.json
./ampersand compose ../../../examples/infra-operator.ampersand.json
./ampersand generate mcp ../../../examples/infra-operator.ampersand.json
./ampersand generate a2a ../../../examples/infra-operator.ampersand.json
```

## Structure

- `SPEC.md` — protocol specification
- `protocol/schema/v0.1.0/` — JSON Schema artifacts
- `examples/` — reference *.ampersand.json declarations
- `contracts/v0.1.0/` — capability contracts
- `reference/elixir/ampersand_core/` — Elixir reference impl + CLI
- `sdk/npm/validate/` — npm validator
- `sdk/python/ampersand_protocol/` — Python SDK
- `docs/` — guides and documentation

## Constraints

- Protocol changes must update schema, examples, reference impl, and docs together
- JSON Schema targets draft 2020-12
- Capabilities are interfaces, not products (`&memory.graph` is a contract, `graphonomous` is a provider)
- [&] complements MCP and A2A — it compiles into them, does not replace them
- Examples must be realistic and validate successfully
- See CONTRIBUTING.md for full guidelines
