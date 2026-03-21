# [&] Protocol — AmpersandBoxDesign

Open, language-agnostic specification for capability composition in AI agents. Defines how agents declare memory, reasoning, time, and space capabilities that compile into MCP and A2A configurations.

## Implementation prompts (source-of-truth for code generation)

- `prompts/PROTOCOL_PROMPT.md` — the full implementation prompt used to generate [&] Protocol reference code. Read this before modifying the Elixir reference implementation — it contains the project identity, architecture summary, formal grammar, coding standards, and generation rules.
- `prompts/GRAPHONOMOUS_PROMPT.md` — autonomous codebase traversal prompt for Graphonomous MCP integration.

These prompts serve the same role as `project_spec/` in other portfolio projects. When the protocol or reference impl needs changes, align with the prompt first.

## Build and verify (Elixir reference implementation)

```
cd reference/elixir/ampersand_core
mix deps.get
mix escript.build
mix test
```

## CLI usage

```
cd reference/elixir/ampersand_core
./ampersand validate ../../../examples/infra-operator.ampersand.json
./ampersand compose ../../../examples/infra-operator.ampersand.json
./ampersand generate mcp ../../../examples/infra-operator.ampersand.json
./ampersand generate a2a ../../../examples/infra-operator.ampersand.json
```

## Repository structure

- `SPEC.md` — protocol specification (draft v0.1.0)
- `protocol/schema/v0.1.0/` — JSON Schema artifacts (ampersand.schema.json, capability-contract.schema.json, registry.schema.json)
- `examples/` — reference agent declarations (*.ampersand.json)
- `contracts/v0.1.0/` — capability contract definitions
- `reference/elixir/ampersand_core/` — Elixir reference implementation + CLI
- `sdk/npm/validate/` — @ampersand-protocol/validate npm package
- `sdk/python/ampersand_protocol/` — ampersand-protocol Python SDK
- `capabilities/` — individual capability documentation
- `docs/` — quickstart, runtime walkthrough, FAQ, comparison table
- `site/` — website source files
- `playground/` — browser-based validation playground

## Protocol change rules

When changing the protocol, update ALL affected layers together:
1. `SPEC.md`
2. `protocol/schema/v0.1.0/*.schema.json`
3. `examples/*.ampersand.json`
4. Reference implementation logic
5. CLI output
6. `docs/`

A protocol change is not complete if only the prose changes. See CONTRIBUTING.md.

## Core model

Four capability primitives: `&memory`, `&reason`, `&time`, `&space`
Two composition operators: `&` (combine) and `|>` (pipeline)
Capabilities are interfaces, providers are implementations.
[&] does not replace MCP or A2A — it compiles into them.

## Schema targets

JSON Schema draft 2020-12. Prefer explicit validation rules over descriptions.
