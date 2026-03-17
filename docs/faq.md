# FAQ

## What is the [&] Protocol?

The [&] Protocol is a language-agnostic specification for **capability composition in AI agents**.

It defines how an agent declares:

- what it can remember
- how it can reason
- how it understands time
- how it understands space
- how those capabilities compose
- how provenance is preserved
- how governance constraints are expressed
- how declarations compile into MCP and A2A configurations

The core source-of-truth artifact is `ampersand.json`.

---

## What problem does it solve?

The current agent stack has useful protocol layers for:

- **tools and context** via MCP
- **agent-to-agent coordination** via A2A
- **rendering and interaction** via UI protocols

What is still missing is a standard way to express **how an agent’s cognitive capabilities fit together before runtime wiring begins**.

The [&] Protocol fills that gap by making capability composition explicit, machine-readable, and portable.

---

## Does [&] replace MCP?

No.

MCP defines how an agent connects to tools and external resources.

[&] defines how an agent declares and validates the capabilities it needs **before** those tool bindings are generated.

A good shorthand is:

- **MCP** = agent-to-tool connectivity
- **A2A** = agent-to-agent coordination
- **[&]** = capability composition

[&] compiles into MCP configuration. It does not compete with MCP.

---

## Does [&] replace A2A?

No.

A2A is for agent discovery, delegation, and communication.

[&] is for describing what an agent is composed of and how those capabilities interoperate.

In practice, an `ampersand.json` declaration can generate an A2A-style agent card that advertises the composed capabilities as skills.

---

## Why is the protocol called “[&]”?

Because the ampersand is the protocol’s composition operator.

It is not just a brand mark. It represents the operation of combining capability declarations into a coherent set.

Examples:

- `&memory.graph`
- `&time.anomaly`
- `&reason.argument`

And at the expression level:

- `&memory.graph & &time.anomaly & &reason.argument`

---

## What are the four core capability domains?

The protocol starts from four cognitive primitives:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

Each primitive can be refined into subtypes, such as:

- `&memory.graph`
- `&memory.episodic`
- `&reason.argument`
- `&reason.vote`
- `&time.anomaly`
- `&time.forecast`
- `&space.fleet`
- `&space.route`

---

## What is `ampersand.json`?

`ampersand.json` is the canonical protocol declaration for an agent.

It describes:

- the agent name
- the version
- the declared capabilities
- provider bindings
- provider-specific config
- governance rules
- provenance requirements

It is intended to be:

- human-readable
- machine-validated
- implementation-independent
- suitable for downstream generation into other protocol formats

---

## Why use JSON instead of a language-specific DSL first?

Because the protocol is intended to be portable across runtimes and languages.

JSON gives the project:

- a stable interchange format
- schema validation
- compatibility with tooling ecosystems
- a neutral source of truth

Language-specific DSLs can still exist, but they should compile down to the same canonical declaration.

---

## What does a capability declaration look like?

A capability declaration is a key in the `capabilities` object of `ampersand.json`.

For example:

- `&memory.graph`
- `&time.anomaly`
- `&space.fleet`
- `&reason.argument`

Each capability is bound to a provider and may include configuration.

Example shape:

- `provider`
- `config`
- optional `need` when using `provider: "auto"`

---

## What is a provider?

A provider is a concrete implementation that satisfies a protocol capability.

For example:

- `graphonomous` may satisfy `&memory.graph`
- `ticktickclock` may satisfy `&time.anomaly`
- `deliberatic` may satisfy `&reason.argument`

Capabilities are interfaces. Providers are implementations.

That distinction is important: the protocol should remain provider-agnostic.

---

## Can multiple providers satisfy the same capability?

Yes.

That is one of the protocol’s design goals.

A capability such as `&memory.graph` should not be tied to one company or one runtime. Any implementation that satisfies the contract can act as a provider.

This makes the protocol portable and keeps the composition layer separate from vendor choice.

---

## What is `provider: "auto"`?

`provider: "auto"` means the declaration is intentionally leaving provider resolution to a registry or runtime.

In that case, the declaration should also include a natural-language `need` field describing the requirement.

Example intent:

- the human or model says what capability is needed
- the registry/runtime chooses which provider satisfies it

This supports autonomous or goal-driven composition workflows.

---

## Why is `need` required when `provider` is `auto`?

Because `auto` without a requirement is underspecified.

If the protocol is going to delegate provider resolution, it still needs enough semantic information to guide that decision. The `need` field provides that missing context.

---

## What is capability composition?

Capability composition is the process of combining declared capabilities into a set that behaves coherently.

The protocol treats capability declarations as set-like, not list-like. That means composition is intended to preserve algebraic properties such as:

- commutativity
- associativity
- idempotence
- identity

The practical benefit is that declaration order and duplication should not change the meaning of a valid capability set.

---

## Why do algebraic properties matter here?

Because deterministic composition makes tooling safer and more portable.

If capability sets behave predictably:

- multiple tools can normalize the same declaration the same way
- duplicates collapse safely
- grouping does not change the result
- composition becomes easier to validate and reason about

This is especially important if different agents, CLIs, SDKs, or runtimes all need to interpret the same declaration.

---

## What is the difference between `&` and `|>` in the protocol?

The protocol uses two conceptual operators:

- `&` for **composition**
- `|>` for **pipeline flow**

`&` combines capabilities into a set.

`|>` represents data or context flowing through capability operations.

So the first answers:

> What capabilities does this agent have?

The second answers:

> In what order do capability operations process a piece of work?

---

## What are capability contracts?

Capability contracts declare:

- what operations a capability supports
- the typed inputs each operation accepts
- the typed outputs each operation produces
- what the capability can accept input from
- what it can feed into
- optional A2A skill mappings

These contracts enable pipeline validation and compatibility checks.

---

## What do `accepts_from` and `feeds_into` mean?

They are adjacency constraints for composition and pipeline validation.

- `accepts_from` says what a capability is allowed to receive input from
- `feeds_into` says what a capability is allowed to send output into

These may refer to:

- specific capabilities
- wildcard primitive patterns like `&memory.*`
- abstract type tokens like `raw_data` or `output`

They help prevent invalid or nonsensical pipeline connections.

---

## What is type-safe pipeline validation in this context?

It means the protocol can reject pipelines where one capability operation produces an output type that does not match the next capability operation’s expected input type.

For example, if one operation outputs `anomaly_set` and the next expects `context`, the pipeline should fail validation unless there is an explicit compatible transformation.

This prevents “plausible-looking but incoherent” pipelines.

---

## What is provenance in the [&] Protocol?

Provenance is the record of where context came from and how it moved through a capability pipeline.

A provenance record may include:

- source capability
- provider
- operation
- timestamp
- input hash
- output hash
- parent hash
- transport trace identifier

The goal is to make agent decisions auditable and explainable.

---

## Why is provenance a protocol concern instead of just an implementation detail?

Because explainability and auditability break down if every runtime invents its own incompatible tracing format.

By making provenance a protocol-level concern, the project gives implementations a shared conceptual model for:

- context lineage
- decision traceability
- audit-friendly outputs
- downstream governance enforcement

---

## What is governance in the protocol?

Governance is the declarative constraint layer in `ampersand.json`.

It lets a declaration express:

- **hard constraints** — non-negotiable boundaries
- **soft constraints** — preferences or heuristics
- **escalation rules** — conditions that require human review or handoff

Governance belongs in data so it can travel with the declaration instead of being buried inside one implementation.

---

## What is the difference between hard and soft governance constraints?

**Hard constraints** are boundaries that should not be violated.

Examples:

- never delete data without approval
- never expose private customer data
- never exceed a specified operational threshold

**Soft constraints** are preferences that guide decisions but may be overridden with sufficient evidence.

Examples:

- prefer gradual scaling
- prefer concise responses
- prefer recent peer-reviewed evidence

---

## What does `escalate_when` do?

It defines conditions under which the system should defer to a human or another supervising process.

Examples include:

- confidence below a threshold
- cost above a threshold
- hard boundary approached

This helps connect protocol composition to operational safety and review workflows.

---

## Is the protocol only for autonomous agents?

No.

It is useful for:

- human-authored agent configurations
- partially automated builders
- fully autonomous composition systems
- CLIs and CI pipelines
- reference implementations and SDKs

The protocol is about making composition explicit and portable, not about mandating a specific authoring model.

---

## Is the protocol only for LLM agents?

No.

It is most obviously useful in LLM-heavy systems, but the composition model is broader than that.

Any system that needs to declare, validate, and bind memory, reasoning, temporal, or spatial capabilities can use the protocol.

---

## Does the protocol depend on Elixir?

No.

The protocol is language-agnostic.

The current repository includes an Elixir reference implementation because it is a convenient way to explore the model, validate artifacts, and build a CLI. But the protocol itself is not tied to Elixir.

Other implementations can exist in:

- TypeScript
- Rust
- Python
- Go
- or other runtimes

---

## Why keep a reference implementation at all if the protocol is language-agnostic?

Because specifications become much more useful once they are grounded in working artifacts.

A reference implementation helps prove that the protocol is:

- implementable
- testable
- composable
- not just a prose concept

It also gives future implementations a baseline for expected behavior.

---

## What is the current reference implementation capable of?

At the time of writing, the repository includes a minimal Elixir reference layer that supports:

- schema validation
- capability normalization and composition checks
- contract-based pipeline checks
- MCP configuration generation
- A2A-style agent card generation
- a working `ampersand` CLI

It is intentionally minimal, but it is already useful for real validation and generation tasks.

---

## What does the CLI do today?

The current CLI supports commands like:

- `validate`
- `compose`
- `generate mcp`
- `generate a2a`

That means a declaration can already be used as an executable artifact for:

- schema validation
- composition inspection
- runtime-oriented config generation

---

## What is generated by `generate mcp`?

An MCP-oriented client configuration derived from the declared capability providers.

At the moment, grounded provider resolution exists only where the repository contains real runtime evidence. Known providers can be turned into concrete MCP launch configuration. Unknown or unresolved providers are kept explicit rather than being guessed.

This is deliberate: the generator should not invent runtime details it cannot justify.

---

## What is generated by `generate a2a`?

An A2A-style agent card derived from the declaration.

That card can expose:

- agent identity
- composed skills
- provider bindings
- governance and provenance metadata

The goal is to show how a single declaration can compile into downstream protocol artifacts.

---

## What does “compile into MCP + A2A” mean?

It means the protocol acts as the higher-level source of truth.

Instead of hand-authoring every downstream artifact independently, you author one canonical declaration and use generators to produce:

- MCP config
- A2A agent metadata
- potentially other runtime or documentation artifacts later

This keeps the composition layer authoritative.

---

## Is the schema the source of truth?

Yes, for the declaration format.

The protocol’s prose is still important, but the schema is what makes the declaration machine-checkable. Once a declaration is validated against the schema, tools can safely build on it.

That is why the schema is one of the first artifacts that should exist in the repository.

---

## Why have multiple schemas instead of only `ampersand.schema.json`?

Because the protocol contains more than one kind of artifact.

The repository may include schemas for:

- agent declarations
- capability contracts
- registry documents

Each artifact has a different role and should be validated explicitly rather than being folded into one oversized schema.

---

## What is the capability registry?

The capability registry is a catalog of:

- primitives
- subtypes
- providers
- supported operations
- provider metadata
- optional contract references

It supports discovery and resolution.

This matters especially when declarations use `provider: "auto"`.

---

## Do you need a registry to use the protocol?

Not always.

If a declaration uses explicit provider bindings, the protocol can still be useful without a full registry.

A registry becomes more important when you want:

- dynamic resolution
- discovery
- compatibility checks across providers
- richer automation

---

## Can the protocol be useful before a full ecosystem exists?

Yes.

Even a small repository with:

- a schema
- a few validating examples
- a minimal reference implementation
- a CLI
- a generator or two

is already significantly better than a purely conceptual protocol.

That is enough to ground future iteration and prevent hallucinated architecture.

---

## Is the protocol intended for public standards work or private internal use?

It can serve both.

As an open specification, it is useful for ecosystem-level interoperability.

As an internal artifact, it can also help one team standardize how agents are declared, validated, and generated across projects.

---

## How is this different from “agent frameworks with memory modules”?

Most frameworks provide implementation building blocks.

The [&] Protocol focuses on the **declaration and validation layer** above implementation details. It aims to answer questions like:

- Which capabilities are present?
- Are they compatible?
- What are the declared constraints?
- How should provenance be represented?
- What downstream configuration artifacts should be generated?

It is closer to a protocol and composition model than a framework runtime.

---

## Is the protocol trying to standardize all of agent architecture?

No.

It is intentionally scoped to the composition layer.

It does not try to replace all runtime concerns, model orchestration, UI protocols, transport standards, or every possible implementation detail.

Its job is to make capability composition explicit, portable, and machine-readable.

---

## How should contributors think about future work?

Good next steps usually fall into one of these categories:

- strengthen schemas
- expand examples
- deepen reference implementation behavior
- improve registry artifacts
- add more generators
- improve docs and publishing
- add provider integrations backed by real implementation evidence

A useful rule is:

> Prefer grounded artifacts over speculative architecture.

---

## What should not be added casually?

A few things should be treated carefully:

- invented provider commands
- unsupported protocol claims
- hand-wavy compatibility logic
- vague governance semantics
- runtime behavior that is not backed by schema or tests

The protocol gets stronger when each layer is precise and testable.

---

## Who is this repository for right now?

Right now, it is most useful for:

- protocol designers
- AI platform engineers
- agent infrastructure builders
- researchers interested in composition, provenance, and governance
- teams exploring interoperable agent declarations

It is early, but it is already concrete enough to build against.

---

## Where should a new reader start?

A good reading path is:

1. `README.md`
2. `SPEC.md`
3. `protocol/schema/v0.1.0/ampersand.schema.json`
4. `examples/`
5. `reference/elixir/ampersand_core/`
6. `docs/positioning.md`

That path moves from concept to contract to working implementation.

---

## What is the shortest possible summary?

The shortest accurate summary is:

> [&] is a protocol for declaring and validating how agent capabilities compose, then compiling that declaration into downstream protocol artifacts like MCP config and A2A agent cards.
