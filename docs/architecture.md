# Architecture Guide

This document describes the reference architecture of the [&] Protocol and how its core artifacts fit together.

It is written for engineers who want to understand the protocol as a system, not just as a schema or a CLI.

---

## 1. What the protocol is responsible for

The [&] Protocol defines the **composition layer** of the agent stack.

It is responsible for:

- capability declaration
- capability compatibility
- capability contracts
- governance as data
- provenance requirements
- downstream artifact generation

It is **not** responsible for replacing:

- MCP tool invocation
- A2A delegation semantics
- UI rendering protocols
- model inference runtimes
- storage engines
- deployment platforms

A concise framing is:

> MCP defines how agents call tools.  
> A2A defines how agents call agents.  
> [&] defines how capabilities compose into a coherent agent.

---

## 2. Stack position

A useful architecture view of the ecosystem is:

| Layer | Concern | Typical Protocols |
|---|---|---|
| UI | agent-to-user rendering | AG-UI, A2UI |
| Composition | capability declaration, validation, provenance, governance | [&] |
| Coordination | agent-to-agent delegation and discovery | A2A, ACP |
| Context | agent-to-tool connectivity | MCP |
| Runtime | execution, storage, orchestration, observability | framework-specific |

The protocol exists because there is currently no standard, machine-readable layer for declaring how an agent's cognitive capabilities fit together before runtime wiring begins.

---

## 3. Core architectural model

The protocol has five primary architectural concepts:

1. **capability primitives**
2. **canonical declarations**
3. **contracts**
4. **registry artifacts**
5. **generated downstream configuration**

These concepts are designed to remain valid across programming languages and runtimes.

### 3.1 Capability primitives

The protocol starts with four primitive capability domains:

- `&memory`
- `&reason`
- `&time`
- `&space`

These are the top-level cognitive building blocks.

Examples of subtypes:

- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`
- `&reason.argument`
- `&reason.vote`
- `&time.anomaly`
- `&time.forecast`
- `&space.fleet`
- `&space.route`

This gives the protocol a compact vocabulary for describing an agent's architecture.

### 3.2 Canonical declaration

The canonical artifact is `ampersand.json`.

This file declares:

- agent identity
- version
- capabilities
- provider bindings
- provider config
- governance constraints
- provenance preference

This declaration is the source of truth for the rest of the architecture.

### 3.3 Contracts

Capability contracts describe the typed operational behavior of a capability.

A contract can define:

- supported operations
- input types
- output types
- adjacency rules with `accepts_from`
- adjacency rules with `feeds_into`
- optional A2A skill mappings

Contracts make composition checkable instead of merely descriptive.

### 3.4 Registry artifacts

A registry publishes:

- known primitives
- known subtypes
- known providers
- provider support metadata
- optional links to contracts

This is especially useful when a declaration uses `provider: "auto"`.

### 3.5 Generated artifacts

A valid declaration can compile into downstream artifacts such as:

- MCP configuration
- A2A-style agent cards

This means the architecture is not just descriptive. It is executable.

---

## 4. Repository architecture

The repository is structured around the protocol lifecycle.

## 4.1 Overview

- `README.md` — protocol overview and quick start
- `SPEC.md` — markdown protocol specification
- `schema/` — machine-readable schema artifacts
- `examples/` — validating example declarations
- `reference/` — reference implementation(s)
- `docs/` — conceptual and practical documentation
- `site/` — website/source publishing assets
- `tools/` — helper scripts

## 4.2 Why this structure matters

This layout is intentional.

A protocol repo should not be only:

- prose docs
- a website
- or a reference implementation

It should contain all three layers:

1. **specification**
2. **machine contracts**
3. **working implementation**

That reduces ambiguity and helps keep the docs, schema, and code aligned.

---

## 5. Schema architecture

The protocol currently uses a schema suite rather than one oversized schema.

## 5.1 `ampersand.schema.json`

This schema validates canonical agent declarations.

It defines the shape of:

- `$schema`
- `agent`
- `version`
- `capabilities`
- `governance`
- `provenance`

It is the primary entry point for validation.

## 5.2 `capability-contract.schema.json`

This schema validates capability contract artifacts.

It defines the structure of:

- `capability`
- `operations`
- `accepts_from`
- `feeds_into`
- `a2a_skills`

This is the schema that makes typed composition portable.

## 5.3 `registry.schema.json`

This schema validates registry documents that publish:

- primitive namespaces
- subtypes
- providers
- protocol metadata

It supports capability discovery and provider resolution.

## 5.4 Why multiple schemas are better

Using multiple schemas keeps the architecture modular.

Each artifact has a different role:

- declarations describe an agent
- contracts describe capability behavior
- registries describe discovery and availability

Separating them avoids conflating concerns and makes implementations easier to reason about.

---

## 6. Declaration architecture

A declaration is a normalized description of an agent's capability architecture.

## 6.1 Top-level shape

An `ampersand.json` declaration usually includes:

- `$schema`
- `agent`
- `version`
- `capabilities`

It may also include:

- `governance`
- `provenance`

## 6.2 Capability binding modes

There are two main binding modes.

### Explicit binding

A declaration directly names the provider.

Example idea:

- `&memory.graph` → `graphonomous`

This mode is best when:

- the runtime is already known
- the provider is fixed
- reproducibility matters more than discovery

### Auto binding

A declaration uses `provider: "auto"` with a `need`.

This mode is best when:

- provider resolution should happen later
- discovery is dynamic
- the declaration should preserve intent without locking a provider

## 6.3 Why declarations are object-shaped

Capabilities are stored as object keys rather than positional list items.

This design supports set-like semantics:

- declaration order does not define meaning
- duplicates collapse naturally
- capability identity is explicit

This makes composition behavior easier to normalize and validate.

---

## 7. Composition architecture

The protocol treats capability sets as algebraic structures.

## 7.1 Set-like semantics

A valid capability set should preserve:

- **commutativity**
- **associativity**
- **idempotence**
- **identity**

These properties are important because multiple tools or users may assemble the same declaration in different ways, and they should converge on the same result.

## 7.2 Conflict behavior

Set-like composition does not mean every merge is valid.

A conflict occurs when the same capability appears with incompatible bindings.

Example:

- `&memory.graph` bound to `graphonomous`
- `&memory.graph` bound to `neo4j-memory`

That is not an idempotent duplicate. It is a real conflict that should be surfaced explicitly.

## 7.3 Why composition is separate from execution

Composition answers:

> What capabilities does the agent contain?

Execution answers:

> How does work flow through those capabilities?

Keeping those separate makes the protocol easier to validate and implement.

---

## 8. Pipeline architecture

Pipelines represent data flowing through capability operations.

## 8.1 The role of `|>`

The pipeline operator conceptually models an ordered flow:

- one operation produces an output
- the next operation accepts that output as input

Example shape:

- `stream_data`
- `&time.anomaly.detect`
- `&memory.graph.enrich`
- `&reason.argument.evaluate`

## 8.2 Contract-driven validation

A pipeline is valid only if:

1. each capability exists
2. each operation exists
3. output and input types align
4. `feeds_into` allows the transition
5. `accepts_from` allows the transition

This architecture prevents pipelines from being treated as informal glue.

## 8.3 Architectural implication

The protocol moves pipeline safety earlier in the lifecycle.

Instead of waiting for runtime failures, implementations can reject invalid compositions before deployment or generation.

---

## 9. Governance architecture

Governance is expressed as portable data.

## 9.1 Components

The governance object can contain:

- `hard`
- `soft`
- `escalate_when`
- `infer_from_goal`

## 9.2 Why governance is modeled this way

If governance only exists in runtime code, then:

- it is hard to audit
- it is not portable
- it becomes implementation-specific
- it cannot travel with the declaration

By expressing governance in the declaration, the protocol lets implementations preserve the same safety intent across languages and runtimes.

## 9.3 Architectural boundaries

The protocol defines the structure of governance.

A runtime still decides:

- how hard constraints are enforced
- how soft constraints are used in reasoning
- how escalation is implemented operationally

So the architecture separates:

- **governance declaration**
- from
- **governance execution**

That is an intentional boundary.

---

## 10. Provenance architecture

Provenance is a required architectural concept for trustworthy composition.

## 10.1 What provenance captures

A provenance record may include:

- source capability
- provider
- operation
- timestamp
- input hash
- output hash
- parent hash
- optional runtime trace IDs

## 10.2 Why hash-linked chains matter

A hash-linked provenance chain allows the system to answer questions like:

- why was this decision made
- which capability produced this context
- what output depended on what input
- what runtime call corresponds to this step

This is especially important for:

- audits
- debugging
- regulated workflows
- governance review
- trust and explainability

## 10.3 Architectural role

Provenance is not just logging.

It is a protocol-level requirement that says:

> composed cognition should preserve lineage

That makes provenance part of the architecture contract rather than an optional afterthought.

---

## 11. Provider architecture

The protocol makes a strict distinction between capabilities and providers.

## 11.1 Capabilities are interfaces

Examples:

- `&memory.graph`
- `&time.anomaly`
- `&reason.argument`

These are protocol concepts.

## 11.2 Providers are implementations

Examples:

- `graphonomous`
- `ticktickclock`
- `deliberatic`
- `geofleetic`

These are concrete implementations.

## 11.3 Why this separation matters

If capabilities and providers are collapsed into one concept, then:

- interoperability disappears
- schemas become vendor-specific
- portability suffers
- composition becomes branding instead of protocol design

The architecture is stronger when capabilities remain vendor-neutral.

---

## 12. Registry architecture

The registry is the discovery and resolution layer.

## 12.1 What the registry publishes

A registry can publish:

- primitive roots
- subtype definitions
- operation metadata
- provider availability
- transport/protocol identifiers
- contract references

## 12.2 Why a registry exists

The registry supports:

- `provider: "auto"`
- compatibility discovery
- provider lookup
- downstream generation
- capability publishing

## 12.3 Architectural boundary

The protocol does not require one global registry service implementation.

It only requires a machine-readable registry model.

That means different ecosystems can host their own registries while preserving the same artifact shape.

---

## 13. Generation architecture

One of the most important architectural goals of the protocol is that a declaration should compile into downstream artifacts.

## 13.1 MCP generation

MCP generation turns a validated declaration into a tool-facing configuration.

That may involve:

- grouping capabilities by provider
- resolving provider launch details
- creating stdio or URL-based config entries
- preserving unresolved providers explicitly

The generator should not invent details that are not grounded in known provider information.

## 13.2 A2A generation

A2A generation turns a validated declaration into an agent-facing coordination artifact.

That may include:

- agent identity
- skill list
- provider bindings
- governance metadata
- provenance metadata

This shows that the same declaration can support both runtime integration and coordination publication.

## 13.3 Architectural significance

This is what makes the protocol more than documentation.

A declaration is not just read by humans. It is transformed into real operational artifacts.

---

## 14. Reference implementation architecture

The Elixir reference implementation is intentionally small and layered.

Its main modules correspond to the protocol architecture:

- schema validation
- composition
- contract checking
- MCP generation
- A2A generation
- CLI entrypoint

## 14.1 Why the reference implementation is minimal

The purpose of the reference implementation is to prove:

- the schema is usable
- composition is checkable
- generation is possible
- the protocol can be grounded in real code

It is not intended to be the only runtime or the final production architecture.

## 14.2 Why a CLI matters

A protocol spreads through interfaces that developers can actually use.

The CLI acts as the operator surface for the lifecycle:

1. validate
2. compose
3. generate

This makes the architecture easier to adopt and test.

---

## 15. Documentation architecture

The documentation should mirror the system architecture.

A healthy documentation hub should include:

- overview
- formal spec
- positioning
- FAQ
- architecture guide
- capability deep dives
- reference examples

This structure matters because different audiences need different entry points:

- engineers want artifacts and implementation detail
- researchers want conceptual framing
- adopters want examples and workflows
- contributors want repository conventions

---

## 16. End-to-end architecture flow

The full architecture flow looks like this:

1. author an `ampersand.json`
2. validate it against the canonical schema
3. normalize the capability set
4. optionally check capability contracts and pipeline compatibility
5. preserve governance and provenance semantics
6. resolve providers directly or through a registry
7. generate downstream artifacts such as MCP config and A2A agent cards

This can be summarized as:

**declaration → validation → composition → resolution → generation**

That is the central execution model of the protocol.

---

## 17. Example mental model

Consider an incident response or infrastructure operations agent.

Its declaration may include:

- `&memory.graph`
- `&time.anomaly`
- `&space.fleet`
- `&reason.argument`

Architecturally, that means:

- memory stores and recalls similar incidents
- time detects anomalous behavior
- space localizes impact across regions or fleets
- reason evaluates possible actions under governance constraints

The protocol gives that architecture a portable machine-readable representation.

Without the protocol, those pieces often exist only as implicit framework wiring or prompt conventions.

---

## 18. Non-goals of this architecture

This architecture is intentionally narrow in a few places.

It does not try to standardize:

- all runtime execution semantics
- all transport protocols
- all memory implementations
- all reasoning models
- all deployment and orchestration
- all UI behavior

Its focus is the composition layer.

That narrowness is a strength. It keeps the protocol understandable and implementable.

---

## 19. Design principles for future architecture work

When extending the protocol, preserve these architectural principles:

### 19.1 Spec first
If a new concept matters, it should be represented in schema and examples, not only prose.

### 19.2 Provider-agnostic core
Keep capability identity separate from provider identity.

### 19.3 No invented runtime details
If provider launch or integration details are unknown, leave them unresolved explicitly.

### 19.4 Declarative governance
Keep constraints portable and machine-readable.

### 19.5 Provenance by design
Do not bolt lineage on later.

### 19.6 Minimal primitive set
Prefer a compact, extensible primitive vocabulary over an explosion of top-level categories.

---

## 20. Practical reading order

If you are trying to understand the architecture for the first time, read the repository in this order:

1. `README.md`
2. `SPEC.md`
3. `schema/v0.1.0/ampersand.schema.json`
4. `schema/v0.1.0/capability-contract.schema.json`
5. `schema/v0.1.0/registry.schema.json`
6. `examples/`
7. `reference/elixir/ampersand_core/`
8. `docs/positioning.md`
9. `docs/comparison-table.md`

That moves from concept to contract to implementation.

---

## 21. Summary

The [&] Protocol architecture is built around one central idea:

> an agent should have a portable, machine-readable declaration of how its cognitive capabilities compose before runtime integration is generated

To make that possible, the architecture includes:

- a canonical declaration format
- a schema suite
- capability contracts
- a registry model
- governance as data
- provenance requirements
- generators for MCP and A2A
- a reference implementation and CLI

That is the composition layer this protocol is designed to provide.