# Example Agent Declarations

This directory contains reference `ampersand.json` documents for the [&] Protocol.

These examples are intended to do three jobs:

1. act as schema validation fixtures
2. show different declaration styles
3. provide concrete inputs for the reference CLI and generators

All examples target the canonical schema at:

- `https://protocol.ampersandboxdesign.com/v0.1/schema.json`

## Files

### `infra-operator.ampersand.json`

The canonical infrastructure operations example from the protocol spec.

**What it demonstrates**

- explicit provider bindings
- all four capability domains
- provider-specific `config`
- declarative governance
- provenance enabled

**Capabilities**

- `&memory.graph` → `graphonomous`
- `&time.anomaly` → `ticktickclock`
- `&space.fleet` → `geofleetic`
- `&reason.argument` → `deliberatic`

**Why it matters**

This is the best end-to-end demo input for:

- schema validation
- composition checks
- MCP config generation
- A2A agent card generation

---

### `fleet-manager.ampersand.json`

A goal-driven example that leaves provider resolution to the registry/runtime.

**What it demonstrates**

- `provider: "auto"`
- required natural-language `need`
- governance inference via `infer_from_goal`
- provenance enabled

**Capabilities**

- `&memory.episodic`
- `&time.forecast`
- `&space.fleet`
- `&reason.argument`

**Why it matters**

This is the example that exercises the protocol's autonomous composition story:

- the declaration says what the agent needs
- the runtime decides which providers satisfy those needs

---

### `research-agent.ampersand.json`

A research and analysis agent focused on evidence quality and traceability.

**What it demonstrates**

- explicit providers
- richer nested config
- governance constraints for evidence handling
- provenance enabled

**Capabilities**

- `&memory.vector` → `pgvector`
- `&time.pattern` → `ticktickclock`
- `&reason.argument` → `deliberatic`

**Why it matters**

This example is useful for testing non-infrastructure scenarios and showing that the protocol is not limited to ops agents.

---

## Quick Usage

From the Elixir reference implementation:

```bash
cd reference/elixir/ampersand_core

mix test
mix escript.build

./ampersand validate ../../../examples/infra-operator.ampersand.json
./ampersand compose ../../../examples/infra-operator.ampersand.json
./ampersand generate mcp ../../../examples/infra-operator.ampersand.json
./ampersand generate a2a ../../../examples/infra-operator.ampersand.json
```

## What to look for

### Validation

A valid example should:

- match the JSON Schema
- use valid capability identifiers
- include a valid semantic version
- include at least one capability

### Composition

A composed declaration should preserve the protocol's set-like semantics:

- commutative
- associative
- idempotent
- identity-safe

### Generation

A declaration can compile into downstream protocol artifacts:

- MCP client/server configuration
- A2A-style agent card metadata

## Conventions used in these examples

### Explicit provider binding

Use this when you know the exact provider:

```json
{
  "&memory.graph": {
    "provider": "graphonomous",
    "config": {
      "instance": "infra-ops"
    }
  }
}
```

### Auto provider binding

Use this when you want runtime or registry resolution:

```json
{
  "&time.forecast": {
    "provider": "auto",
    "need": "demand spike prediction"
  }
}
```

### Governance

Use governance to express constraints and escalation conditions as data:

```json
{
  "governance": {
    "hard": [
      "Never delete data without human approval"
    ],
    "soft": [
      "Prefer gradual actions over sudden spikes"
    ],
    "escalate_when": {
      "confidence_below": 0.7
    }
  }
}
```

## Adding a new example

When you add a new example, keep it useful as both documentation and a test fixture.

Recommended checklist:

- reference the canonical schema
- use a realistic agent name
- include at least one meaningful capability
- enable `provenance`
- make governance explicit when relevant
- choose either explicit providers or `auto` intentionally
- make sure the file validates against `schema/v0.1.0/ampersand.schema.json`

## Suggested future examples

Useful additions that would round out this directory:

- `customer-support.ampersand.json`
- `fraud-analyst.ampersand.json`
- `route-planner.ampersand.json`
- `incident-commander.ampersand.json`

These would help demonstrate the protocol across customer operations, finance, logistics, and real-time response workflows.