# Capability Contracts

This directory contains standalone **capability contract artifacts** for the [&] Protocol.

These files complement the canonical agent declaration schema by describing how individual capabilities behave once they are declared in `ampersand.json`.

At a high level:

- `ampersand.json` answers: **what capabilities does this agent have?**
- capability contracts answer: **what can each capability do, what inputs does it accept, what outputs does it produce, and what can it compose with?**

---

## Why capability contracts exist

A declaration like this:

```json
{
  "capabilities": {
    "&time.forecast": {
      "provider": "ticktickclock"
    },
    "&reason.argument": {
      "provider": "deliberatic"
    }
  }
}
```

tells you that an agent has temporal forecasting and argumentative reasoning.

That is useful, but incomplete.

A runtime or validator still needs to know:

- which operations `&time.forecast` supports
- which type each operation expects as input
- which type it produces as output
- whether `&time.forecast` can legally feed into `&reason.argument`
- what A2A-facing skills may be derived from that capability

That is the role of a contract artifact.

---

## Contract responsibilities

A capability contract is the protocol-level description of a single capability interface.

A contract can declare:

- the capability identifier
- the provider that satisfies it
- the version of the contract artifact
- the operations the capability supports
- the typed input/output signature of each operation
- adjacency rules via `accepts_from`
- adjacency rules via `feeds_into`
- optional `a2a_skills`
- optional metadata for documentation or tooling

This makes capability composition **machine-checkable** instead of only descriptive.

---

## Relationship to the rest of the protocol

The repository has three closely related artifact layers:

### 1. Agent declarations

Located in:

- `protocol/schema/v0.1.0/ampersand.schema.json`
- `examples/*.ampersand.json`

These describe a whole agent.

### 2. Capability contracts

Located here in:

- `contracts/v0.1.0/*.contract.json`

These describe one capability at a time.

### 3. Registry artifacts

Located in:

- `protocol/registry/v0.1.0/*.json`

These publish primitives, subtypes, and providers and may link back to contracts in this directory.

A useful mental model is:

- declaration = agent-level source of truth
- contract = capability-level behavior and composition rules
- registry = discovery and publishing layer

---

## Current contract artifacts

This directory currently includes the complete `v0.1.0` contract artifact set for the published capability subtypes:

- `memory.graph.contract.json`
- `memory.vector.contract.json`
- `memory.episodic.contract.json`
- `reason.argument.contract.json`
- `reason.vote.contract.json`
- `reason.plan.contract.json`
- `time.anomaly.contract.json`
- `time.forecast.contract.json`
- `time.pattern.contract.json`
- `space.fleet.contract.json`
- `space.route.contract.json`
- `space.geofence.contract.json`

These artifacts are intended to serve as:

- canonical protocol fixtures for the full versioned artifact set
- validation fixtures
- input for registry and generation tooling
- references for additional provider implementations

---

## Contract file format

Each contract artifact is validated by:

- `protocol/schema/v0.1.0/capability-contract.schema.json`

A typical file includes fields like:

- `$schema`
- `capability`
- `provider`
- `version`
- `description`
- `operations`
- `accepts_from`
- `feeds_into`
- `a2a_skills`
- `metadata`

Example shape:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/capability-contract.schema.json",
  "capability": "&reason.argument",
  "provider": "deliberatic",
  "version": "0.1.0",
  "description": "Argumentative reasoning contract for evidence-weighted evaluation.",
  "operations": {
    "evaluate": {
      "in": "enriched_context",
      "out": "decision"
    },
    "justify": {
      "in": "decision",
      "out": "justification"
    }
  },
  "accepts_from": ["&memory.*", "&time.*", "&space.*", "context"],
  "feeds_into": ["&memory.*", "output"],
  "a2a_skills": ["decision-evaluation", "decision-justification"]
}
```

---

## Meaning of the key fields

### `capability`

The protocol capability identifier, such as:

- `&memory.graph`
- `&memory.episodic`
- `&reason.argument`
- `&time.forecast`
- `&space.fleet`

This identifies the interface being described.

### `provider`

The concrete implementation satisfying the interface.

Examples:

- `graphonomous`
- `deliberatic`
- `ticktickclock`
- `geofleetic`

The protocol keeps **capability** and **provider** separate on purpose.

### `operations`

The callable surface of the capability.

Each operation declares at minimum:

- `in`
- `out`

These are protocol-level type tokens such as:

- `query_context`
- `memory_hits`
- `enriched_context`
- `decision`
- `forecast_set`
- `capacity_snapshot`

### `accepts_from`

Declares what kinds of upstream capabilities or source types may legally precede this capability.

Examples:

- `&memory.*`
- `&time.*`
- `raw_data`
- `context`

### `feeds_into`

Declares what kinds of downstream capabilities or output sinks this capability may legally feed into.

Examples:

- `&reason.*`
- `&memory.*`
- `output`

### `a2a_skills`

Optional external skill mappings that may be used when generating A2A-style agent cards.

Examples:

- `decision-evaluation`
- `temporal-forecasting`
- `graph-memory-recall`

---

## Why these contracts matter

These files make several important protocol behaviors possible.

### Pipeline validation

A validator can reject pipelines where:

- the operation does not exist
- the output type of one step does not match the input type of the next
- the upstream capability is not allowed by `accepts_from`
- the downstream capability is not allowed by `feeds_into`

### Provider-agnostic composition

A declaration can say:

- `&memory.graph`

without collapsing the protocol into a single vendor.

A provider only needs to satisfy the contract.

### Artifact generation

Contracts provide enough semantic structure to support:

- MCP-oriented config generation
- A2A-style skill mapping
- future registry compilation and compatibility tooling

### Documentation and discoverability

Contracts are also useful as public-facing technical artifacts because they show exactly what a capability is expected to do.

---

## Conventions used in this directory

These contract files follow a few practical conventions.

### File naming

Files are named with the capability path and a `.contract.json` suffix.

Examples:

- `memory.graph.contract.json`
- `reason.argument.contract.json`
- `space.fleet.contract.json`

This keeps filenames readable while still mapping cleanly back to the protocol capability identifier.

### One capability per file

Each file should describe one primary capability contract.

This keeps artifacts small, composable, and easy to validate.

### Provider grounding

Where possible, provider examples in these files should be grounded in the repository's current protocol ecosystem and docs.

If a provider is not yet implemented or documented enough to justify a full artifact, it is better to omit it than invent unsupported details.

### Portable type tokens

Input and output tokens should remain protocol-level and implementation-agnostic.

Good examples:

- `query_context`
- `enriched_context`
- `decision`
- `forecast_set`

Less useful examples would be deeply framework-specific internal structs or opaque runtime identifiers.

---

## Current examples by intent

### `memory.graph.contract.json`

Shows how graph memory can support:

- recall
- learn
- consolidate
- enrich

and how it commonly composes with temporal and reasoning capabilities.

### `memory.episodic.contract.json`

Shows how replayable experience memory can support:

- recall
- store
- replay
- enrich

for support, workflow, and case-history scenarios.

### `reason.argument.contract.json`

Shows how argumentative reasoning can support:

- evaluate
- deliberate
- justify
- learn

under evidence and governance-sensitive conditions.

### `time.forecast.contract.json`

Shows how temporal forecasting can support:

- predict
- explain
- enrich
- learn

for planning, demand prediction, and future-state estimation.

### `space.fleet.contract.json`

Shows how fleet-aware spatial capability can support:

- locate
- enrich
- capacity
- route

for distributed regional and operational decisions.

---

## Adding a new contract

When adding a new contract artifact, try to keep it useful both as documentation and as a real validation target.

Recommended checklist:

- use the canonical contract schema
- choose a real capability identifier
- keep provider and capability clearly separated
- define meaningful operations
- use portable input/output type tokens
- define realistic `accepts_from`
- define realistic `feeds_into`
- add `a2a_skills` only when they are meaningful
- keep metadata helpful but optional
- make sure the file validates against the contract schema

---

## Good reasons to add a contract

Add a new contract when:

- a capability subtype has become important enough to document explicitly
- a provider meaningfully satisfies a capability in a reusable way
- a new generator or validator needs a machine-readable contract
- you want to document composition rules for a capability clearly

---

## Things to avoid

Avoid these anti-patterns when writing contracts:

- treating provider names as capability names
- using vague operation names that do not imply a real interface
- inventing unsupported provider behavior
- making type tokens too implementation-specific
- omitting adjacency rules entirely when composition boundaries matter
- creating “marketing contracts” that read like product copy instead of protocol artifacts

---

## Intended audience

This directory is useful for:

- protocol implementers
- CLI and SDK authors
- registry tooling authors
- agent framework developers
- engineers building compatibility checks
- anyone trying to understand how a declared capability behaves beyond its name

---

## Suggested next steps

Useful future additions for this directory include:

- `memory.vector.contract.json`
- `time.anomaly.contract.json`
- `time.pattern.contract.json`
- `reason.vote.contract.json`
- `reason.plan.contract.json`
- `space.route.contract.json`
- `space.geofence.contract.json`

Those would round out the current primitive namespaces and make registry artifacts even more useful.

---

## Summary

Capability contracts are the protocol artifacts that make composition concrete.

They answer questions like:

- What operations does this capability support?
- What types does it consume and produce?
- What can it compose with?
- What skills can it advertise externally?

If `ampersand.json` is the declaration of an agent's architecture, the files in this directory are the behavioral contracts that make that architecture checkable.
