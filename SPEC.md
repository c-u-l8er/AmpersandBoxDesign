# [&] Protocol Specification

**Status:** draft `v0.1.0`  
**Scope:** capability composition for AI agents  
**Position in stack:** compiles into MCP and A2A configurations

---

## 1. Purpose

The [&] Protocol defines a language-agnostic way to describe how an AI agent’s cognitive capabilities compose into a coherent system.

It does **not** replace MCP or A2A.

Instead:

- **MCP** defines agent-to-tool connectivity
- **A2A** defines agent-to-agent coordination
- **[&]** defines capability declaration, compatibility, governance, and provenance before runtime wiring occurs

The canonical source artifact is `ampersand.json`.

A conforming implementation should be able to:

1. validate an `ampersand.json` declaration
2. normalize a capability set
3. check capability contracts and pipeline compatibility
4. preserve context provenance
5. generate downstream MCP and A2A artifacts

---

## 2. Design Goals

The protocol is designed to make agent composition:

- **machine-readable**
- **provider-agnostic**
- **deterministic**
- **portable across runtimes**
- **compatible with existing agent protocols**
- **auditable**

The protocol treats capabilities as interfaces rather than products. For example, `&memory.graph` is a capability contract, while `graphonomous` is one possible provider that can satisfy it.

---

## 3. Stack Position

The current agent stack can be understood as four layers:

1. **UI layer** — protocols for agent-to-user rendering and interaction
2. **Composition layer** — capability declaration, validation, provenance, governance
3. **Coordination layer** — agent-to-agent task exchange and discovery
4. **Context layer** — agent-to-tool access and resource wiring

[&] occupies the **composition layer**.

A useful shorthand is:

- UI: `A2UI`, `AG-UI`, related rendering protocols
- Composition: `[&]`
- Coordination: `A2A`, `ACP`
- Context: `MCP`

The core claim of the protocol is simple: an agent should declare **what kinds of cognition it has** before a runtime decides **how those capabilities are wired**.

---

## 4. Cognitive Primitives

The protocol starts from four primitive capability domains.

### 4.1 `&memory`

Describes what the agent can store, recall, enrich, replay, or consolidate.

Common subtypes include:

- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`

### 4.2 `&reason`

Describes how the agent decides, evaluates, plans, argues, or votes.

Common subtypes include:

- `&reason.argument`
- `&reason.vote`
- `&reason.plan`

### 4.3 `&time`

Describes temporal perception, forecasting, anomaly detection, and pattern recognition.

Common subtypes include:

- `&time.anomaly`
- `&time.forecast`
- `&time.pattern`

### 4.4 `&space`

Describes spatial context, fleet state, routing, geofencing, and regional awareness.

Common subtypes include:

- `&space.fleet`
- `&space.route`
- `&space.geofence`

These primitives are intended to map to a practical cognitive taxonomy:

- **what** → memory
- **how** → reason
- **when** → time
- **where** → space

---

## 5. Namespaces and Capability Identifiers

A capability identifier has the form:

- `&primitive`
- `&primitive.subtype`

Valid primitive roots are:

- `memory`
- `reason`
- `time`
- `space`

Examples:

- `&memory.graph`
- `&reason.argument`
- `&time.anomaly`
- `&space.fleet`

Wildcard matching is used in contracts and compatibility rules. For example:

- `&memory.*` matches any `&memory` subtype
- `&reason.*` matches any `&reason` subtype

---

## 6. Operators

The protocol defines two operators.

### 6.1 Composition operator: `&`

`&` combines capabilities into a set-like declaration.

Example expression:

`&memory.graph & &time.anomaly & &reason.argument`

This means the agent declares all three capabilities.

### 6.2 Pipeline operator: `|>`

`|>` flows data through capability operations.

Example expression:

`stream_data |> &time.anomaly.detect() |> &memory.graph.enrich() |> &reason.argument.evaluate()`

This means output from one operation becomes input to the next, subject to contract checks.

---

## 7. Formal Grammar Summary

A conforming implementation should be able to parse a minimal capability grammar with these concepts:

- an **agent declaration**
- a **capability block**
- an optional **governance block**
- a **capability** composed of:
  - a primitive
  - an optional subtype
  - a provider binding
  - an optional config payload
- an optional **pipeline** composed of capability operations

At minimum, the grammar needs to express:

- `agent`
- `capabilities`
- `governance`
- `provider`
- `config`
- `&`
- `|>`

The grammar is intentionally small. Most protocol power comes from the schema and the contract system rather than from a large syntax surface.

---

## 8. Canonical Agent Declaration

The canonical artifact is `ampersand.json`.

A valid declaration contains:

- `$schema`
- `agent`
- `version`
- `capabilities`

Optional top-level fields include:

- `governance`
- `provenance`

### 8.1 Required fields

#### `$schema`

Must reference the canonical agent declaration schema.

Current value:

`https://protocol.ampersandboxdesign.com/v0.1/schema.json`

#### `agent`

A human-readable identifier for the agent.

Examples:

- `InfraOperator`
- `FleetManager`
- `ResearchAgent`

#### `version`

A semantic version string for the declaration.

Examples:

- `1.0.0`
- `0.1.0`

#### `capabilities`

An object keyed by capability identifier.

Each capability entry declares at least:

- `provider`

It may also include:

- `config`
- `need`

### 8.2 Provider binding modes

The protocol supports two broad binding styles.

#### Explicit provider binding

The declaration names the exact provider.

Example idea:

`"&memory.graph": { "provider": "graphonomous", "config": { ... } }`

#### Auto provider binding

The declaration delegates provider resolution to a registry or runtime.

Example idea:

`"&time.forecast": { "provider": "auto", "need": "demand spike prediction" }`

When `provider` is `auto`, `need` should be present to preserve intent.

---

## 9. Schema Suite

The protocol currently defines three core schema artifacts.

### 9.1 Agent declaration schema

File:

`protocol/schema/v0.1.0/ampersand.schema.json`

Purpose:

- validate canonical `ampersand.json` documents

### 9.2 Capability contract schema

File:

`protocol/schema/v0.1.0/capability-contract.schema.json`

Purpose:

- validate capability contract artifacts describing operations, type signatures, adjacency, and skill mappings

### 9.3 Registry schema

File:

`protocol/schema/v0.1.0/registry.schema.json`

Purpose:

- validate provider registry artifacts describing primitive namespaces, subtypes, and provider entries

All schemas target JSON Schema draft `2020-12`.

---

## 10. Capability Composition Algebra

Capability composition is set-like and should satisfy deterministic normalization rules.

A conforming implementation should preserve these properties where capability bindings do not conflict.

### 10.1 Commutative

Order of declaration does not change the normalized capability set.

`A & B` is equivalent to `B & A`

### 10.2 Associative

Grouping of compatible declarations does not change the normalized capability set.

`(A & B) & C` is equivalent to `A & (B & C)`

### 10.3 Idempotent

Declaring the same capability with the same binding more than once does not change the result.

`A & A` is equivalent to `A`

### 10.4 Identity

An empty capability set composes cleanly with a non-empty one.

`∅ & A` is equivalent to `A`

### 10.5 Conflict rule

If the same capability appears with incompatible bindings, composition should fail.

Example conflict:

- `&memory.graph -> graphonomous`
- `&memory.graph -> neo4j-memory`

This is not a valid idempotent collapse; it is a binding conflict.

---

## 11. Governance

Governance is declared as data rather than embedded in runtime-specific syntax.

The top-level `governance` object may include:

- `hard`
- `soft`
- `escalate_when`
- `infer_from_goal`

### 11.1 Hard constraints

Hard constraints are inviolable boundaries.

Examples:

- never delete customer data without approval
- never scale beyond a fixed threshold in one action
- always preserve an audit trail

A conforming implementation should prevent actions that violate hard constraints.

### 11.2 Soft constraints

Soft constraints are preferences rather than absolute rules.

Examples:

- prefer gradual scaling over spikes
- prefer recent peer-reviewed evidence
- prefer concise policy-grounded responses

A conforming implementation may override soft constraints when evidence or policy justifies it.

### 11.3 Escalation rules

`escalate_when` defines when the system should defer to a human or a higher-trust workflow.

Common keys include:

- `confidence_below`
- `cost_exceeds_usd`
- `hard_boundary_approached`

### 11.4 Goal inference

`infer_from_goal: true` signals that governance may be partially derived from a natural-language goal and runtime context.

---

## 12. Provenance

The protocol treats provenance as a first-class concern.

When `provenance` is enabled, capability operations should append provenance records to pipeline context.

A provenance record should preserve at least:

- `source`
- `provider`
- `operation`
- `timestamp`
- `input_hash`
- `output_hash`
- `parent_hash`
- `mcp_trace_id` when available

### 12.1 Chain semantics

Provenance records are intended to form a hash-linked chain.

This enables a runtime or auditor to answer questions such as:

- why was a decision made
- which capability produced a key datum
- which prior artifact a result depended on
- which external tool invocation corresponds to a pipeline step

### 12.2 Protocol intent

The protocol does not mandate one hashing library, storage backend, or log format. It mandates the **shape and role** of provenance, not one implementation.

---

## 13. Capability Contracts

Capability contracts are how the protocol expresses type safety and adjacency rules.

A contract should declare:

- `capability`
- `operations`
- `accepts_from`
- `feeds_into`
- optional `a2a_skills`

### 13.1 Operations

Each operation describes typed input and output.

Example operation ideas:

- `detect: in -> out`
- `enrich: in -> out`
- `learn: in -> out`

The types are protocol-level tokens such as:

- `stream_data`
- `anomaly_set`
- `context`
- `enriched_context`
- `decision`
- `ack`
- `output`

### 13.2 `accepts_from`

Defines which capability patterns or input sources may precede this capability.

Examples:

- `&memory.*`
- `&space.*`
- `raw_data`

### 13.3 `feeds_into`

Defines which capability patterns or outputs this capability may lead into.

Examples:

- `&reason.*`
- `&memory.*`
- `output`

### 13.4 `a2a_skills`

Maps a capability to portable A2A-facing skill identifiers.

Example:

- `temporal-anomaly-detection`

---

## 14. Pipeline Validation

A conforming implementation should reject invalid pipelines.

At minimum, pipeline checking should verify:

1. the capability exists in a contract registry
2. the referenced operation exists
3. the previous operation’s output type matches the next operation’s input type
4. the left capability’s `feeds_into` allows the right capability
5. the right capability’s `accepts_from` allows the left capability

This allows pipelines to be checked before deployment instead of relying only on runtime failure.

---

## 15. Capability Registry

The registry is the discovery layer for capability providers.

A registry artifact groups entries by primitive root such as:

- `&memory`
- `&reason`
- `&time`
- `&space`

Each primitive entry may define:

- available subtypes
- supported operations for each subtype
- providers supporting those subtypes
- transport or protocol identifiers
- links to contracts or metadata

### 15.1 Subtype entries

A subtype entry typically contains:

- `ops`
- optional `description`
- optional `contract_ref`
- optional `a2a_skills`

### 15.2 Provider entries

A provider entry typically contains:

- `id`
- `subtypes`
- `protocol`
- optional `command`
- optional `args`
- optional `env`
- optional `url`
- optional `status`

### 15.3 Registry role

The registry enables:

- provider discovery
- validation of `provider: "auto"` flows
- MCP/A2A compilation support
- capability publishing and compatibility analysis

---

## 16. Autonomous Composition

The protocol is intended to work for both human-authored and machine-authored declarations.

An autonomous agent may:

- propose capabilities from a goal
- choose `provider: "auto"` for unresolved needs
- infer governance requirements from context
- request contract and schema validation before execution
- compile into downstream runtime artifacts

The protocol does **not** require an LLM to know concrete provider wiring ahead of time. It only requires enough structure for a runtime to resolve, validate, and materialize a declaration safely.

---

## 17. Downstream Compilation

A valid `ampersand.json` can be compiled into other protocol artifacts.

### 17.1 MCP generation

An implementation may transform capability bindings into MCP client or server configuration.

Example outcomes:

- `graphonomous` resolved to a stdio MCP server entry
- unresolved providers preserved as explicit metadata rather than guessed commands

### 17.2 A2A generation

An implementation may transform a declaration into an A2A-style agent card.

Typical outputs include:

- agent identity
- skill list derived from capability declarations
- provider bindings
- governance and provenance metadata

The protocol therefore acts as the higher-level source of truth from which runtime integration artifacts are derived.

---

## 18. Reference Implementation

The repository includes a minimal Elixir reference implementation under:

`reference/elixir/ampersand_core/`

Current responsibilities include:

- schema validation
- capability normalization and composition
- contract-driven pipeline checks
- MCP generation
- A2A generation
- CLI commands for `validate`, `compose`, and `generate`

This implementation is intentionally small. It exists to prove the protocol can be grounded in runnable artifacts, not just described in prose.

---

## 19. CLI Surface

The current reference CLI exposes a minimal operator interface:

- `ampersand validate <file>`
- `ampersand compose <file>`
- `ampersand generate mcp <file>`
- `ampersand generate a2a <file>`

These commands correspond directly to the protocol lifecycle:

1. declare
2. validate
3. compose
4. compile

---

## 20. Example Artifacts

Reference examples live in `examples/` and currently include:

- `infra-operator.ampersand.json`
- `fleet-manager.ampersand.json`
- `research-agent.ampersand.json`
- `customer-support.ampersand.json`

They are intended to serve as both documentation and validation fixtures.

---

## 21. Conformance Expectations

An implementation may differ in language, runtime model, storage backend, or transport details, but it should still preserve the protocol’s core invariants.

A conforming implementation should:

- accept valid canonical declarations
- reject invalid declarations
- normalize compatible capability sets deterministically
- reject contract-invalid pipelines
- preserve governance semantics
- preserve provenance semantics
- generate downstream artifacts without inventing unsupported provider details

---

## 22. Non-Goals

The protocol does not attempt to standardize:

- one agent framework
- one programming language
- one storage engine
- one memory backend
- one reasoning implementation
- one deployment platform
- one MCP runtime library
- one A2A transport implementation

It standardizes the **composition contract**, not the entire agent runtime.

---

## 23. Repository Map

Important repository paths:

- `README.md` — overview
- `SPEC.md` — this document
- `protocol.html` — HTML spec
- `protocol/schema/v0.1.0/ampersand.schema.json`
- `protocol/schema/v0.1.0/capability-contract.schema.json`
- `protocol/schema/v0.1.0/registry.schema.json`
- `examples/`
- `reference/elixir/ampersand_core/`
- `docs/positioning.md`

---

## 24. Summary

The [&] Protocol defines a portable, machine-readable composition layer for AI agents.

It contributes:

- a canonical declaration format
- a capability taxonomy
- deterministic composition rules
- typed capability contracts
- governance as data
- provenance as protocol structure
- compilation targets for MCP and A2A

The protocol’s central idea is that agent systems should be declared and checked as composed cognitive systems before they are wired into tools, other agents, or UI surfaces.

That is the missing layer this specification is intended to provide.
