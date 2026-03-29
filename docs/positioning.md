# The Missing Layer: Capability Composition in the Agent Protocol Stack

## Introduction

The current agent ecosystem is converging on a recognizable protocol stack.

At the context layer, **MCP** defines how agents discover and invoke tools, resources, and prompts. At the coordination layer, **A2A** defines how agents discover each other and exchange work. Other protocols are emerging around UI rendering, transport, evaluation, and deployment. This is healthy. It means the ecosystem is beginning to separate concerns and stabilize interfaces.

But there is still a missing layer.

None of the existing protocols gives developers a standard way to declare **how an agent’s cognitive capabilities compose into a coherent system before runtime wiring begins**. They do not describe what kinds of memory an agent has, what form of reasoning it applies, what temporal intelligence it relies on, what spatial model it uses, what governance policies constrain it, whether those components are compatible, how data moves between them, or how provenance travels with that composition.

That is the problem the [&] Protocol addresses.

The goal is not to replace MCP or A2A. The goal is to provide a higher-level declaration layer that can **compile into MCP + A2A configurations**. In that sense, the protocol is less like another transport standard and more like a source-of-truth artifact for agent architecture.

## 1. The Current Stack

A useful way to understand the problem is to look at what the current layers already do well.

### MCP: context and tools

MCP solves a real and important problem: it gives agents a common way to connect to external tools and resources. A model or runtime does not need custom glue code for every tool provider. Instead, a server can expose tools, resources, and prompts through a shared interface.

This is a major step forward for interoperability. It reduces bespoke integrations and makes tool access portable across runtimes.

But MCP is deliberately focused on **agent-to-tool connectivity**. It tells you *how* a tool is called. It does not tell you *which cognitive capabilities should exist in the first place*, or whether a graph memory provider and a temporal anomaly detector compose safely with a specific reasoning strategy.

### A2A: coordination and delegation

A2A solves a different problem. It standardizes how agents discover one another, advertise capabilities, and delegate tasks. That matters for multi-agent systems, marketplaces, and enterprise orchestration. Agent cards and skill metadata are useful coordination primitives.

But A2A is about **agent-to-agent coordination**. It tells you how one agent exposes itself to another. It does not tell you how that agent is internally composed. If two agents both publish skills, A2A does not specify whether those skills are backed by durable memory, auditable reasoning, temporal prediction, or any other cognitive architecture.

### ACP and adjacent work

Other protocols such as ACP address communication surfaces. Evaluation and operations projects such as ScaleMCP and MCPEval improve runtime quality, observability, and deployment discipline. These are valuable contributions.

But they still do not define the composition layer.

They do not answer questions like:

- What are the canonical cognitive primitives an agent should declare?
- How are capability interfaces separated from providers?
- How are capability sets normalized and validated?
- How does pipeline type safety work across capability operations?
- How is provenance preserved across composed decisions?
- How are governance constraints expressed as portable data rather than framework-specific code?

Those questions sit between architecture and runtime. That is the missing layer.

## 2. The Gap

Saying "an agent has memory and reasoning" is not enough.

That statement is too vague to validate, too vague to generate from, and too vague to interoperate around. In practice, agent systems differ not only in *whether* they have memory, but in *what kind* of memory they have, how it is wired to other capabilities, what contracts it satisfies, and what guarantees the surrounding system provides.

This gap is becoming more important as agent systems move from demos to infrastructure.

A research assistant, incident responder, fleet optimizer, and customer support agent may all involve memory and reasoning, but they do not compose those capabilities in the same way. Some need graph recall. Some need vector retrieval. Some need temporal anomaly detection. Some need spatial fleet state. Some need argumentative or constitutional reasoning with escalation rules. Some need explicit governance — telemetry, identity management, or policy enforcement — as a first-class capability rather than a bolted-on afterthought. Without a shared way to represent those choices, each project reinvents its own private architecture language.

Academic work points in the same direction. The **CoALA** taxonomy is useful because it breaks agent cognition into meaningful functional categories rather than treating "the agent" as a single black box. Likewise, work such as **DALIA** is relevant because it reinforces the need for explicit structure in agent architectures rather than informal prompt-only assembly.

The practical consequence is straightforward:

- runtimes can call tools,
- agents can call other agents,
- but developers still lack a portable contract for how cognitive capabilities compose.

The [&] Protocol treats that as a protocol problem rather than just an implementation detail.

## 3. What Composition Means

In this context, composition is not a branding metaphor. It is a formal property of how an agent is assembled.

### Capability declaration

An agent should be able to declare its capabilities in a machine-readable artifact such as `ampersand.json`. Those capabilities are expressed as protocol interfaces:

- `&memory`
- `&reason`
- `&time`
- `&space`
- `&govern`

Each primitive can be refined into namespaced subtypes such as:

- `&memory.graph`
- `&memory.episodic`
- `&reason.argument`
- `&time.anomaly`
- `&time.forecast`
- `&space.fleet`
- `&govern.telemetry`
- `&govern.escalation`
- `&govern.identity`

This gives the protocol a vocabulary for cognition that is both small and extensible. The first four primitives map to cognitive domains; `&govern` is the cross-cutting primitive for telemetry, escalation, and identity that all capability providers may consume or emit.

### Formal grammar

Composition should be parseable, not implied.

The protocol defines two operators:

- `&` for composing capabilities into a set
- `|>` for flowing data through capability operations

That distinction matters. A capability set answers "what this agent contains." A pipeline answers "how data moves across those capabilities at execution time."

This is the difference between static declaration and operational flow.

### Algebraic properties

Capability composition should behave predictably. The protocol therefore treats capability sets with algebraic discipline:

- **commutative**: declaration order should not change meaning
- **associative**: grouping should not change meaning
- **idempotent**: duplicates should collapse
- **identity-safe**: empty composition should behave cleanly

This sounds abstract, but it matters operationally. If different tools, humans, or agents assemble the same set in different orders, they should converge on the same result.

### Type-safe pipelines

Composition is not just set membership. It is also contract compatibility.

A capability contract declares:

- supported operations
- input and output types
- what the capability can accept input from
- what it can feed into
- optional A2A skill mappings

For example, a temporal anomaly detector might output `anomaly_set`, while a graph memory enricher expects `anomaly_set` as input. A protocol-aware implementation can validate that pipeline before runtime. It can also reject invalid adjacency such as feeding a capability into another one that does not declare compatibility.

This is the difference between "plausible-looking architecture" and validated architecture.

### Hash-linked provenance

Composition should preserve where data came from.

The protocol therefore treats provenance as a first-class concept. Each capability operation can append a provenance record describing:

- source capability
- provider
- operation
- timestamp
- input hash
- output hash
- parent hash
- optional runtime trace identifiers

This creates a hash-linked chain across the decision path. That matters for debugging, auditability, trust, and governance.

### Declarative governance

Constraints should not live only in framework code.

The protocol expresses governance in data:

- `hard` constraints that must not be violated
- `soft` preferences that can guide reasoning
- `escalate_when` conditions that require deferral to a human or another authority

This makes governance portable. It can travel with the declaration rather than disappearing when the implementation language changes.

### Governance from topology

The protocol makes a stronger claim about governance than "constraints as data."

In any composed system, some regions have feedback loops and some do not. The κ invariant — computed from Tarjan's strongly connected component (SCC) analysis on the capability graph — distinguishes these regions mechanically. When κ = 0, the subgraph is acyclic: data flows in one direction, and single-pass retrieval is sufficient. When κ > 0, irreducible feedback loops exist: nodes influence each other mutually, and deliberation is both warranted and bounded by the loop's complexity.

This is a governance principle, not a routing heuristic. Deliberation rights derive from the topology of mutual influence. A node that cannot be influenced by a decision has no structural basis for participating in that decision. Conversely, nodes within a feedback loop have both the right and the obligation to deliberate, because their states are interdependent.

The practical consequence: governance is not layered on top of architecture. It emerges from the architecture's own feedback structure. The κ invariant is computable, verifiable, and deterministic — it does not depend on role hierarchies, trust scores, or human judgment about who should participate.

Coherence across the system is maintained through timescale separation. Fast memory operations (seconds) preserve local autonomy; slow consolidation cycles (days to months) enforce system-wide coherence. This gradient — from autonomous local action to coherent global structure — is the core tension that governance manages, and the protocol makes it explicit through the `governance.autonomy` block and consolidation tier declarations.

## 4. The [&] Protocol

The [&] Protocol is a language-agnostic composition layer for agent cognition.

It sits between architecture design and downstream runtime configuration. Its purpose is to make an agent declaration:

- machine-validatable,
- provider-agnostic,
- composition-aware,
- provenance-aware,
- governance-aware,
- and translatable into other protocol surfaces.

### Five primitives

The protocol starts from five primitives that map cleanly onto common cognitive and operational categories:

- **memory** — what the agent stores and recalls
- **reason** — how the agent evaluates and decides
- **time** — how the agent models trends, forecasts, and anomalies
- **space** — how the agent models regions, fleets, routes, or topology
- **govern** — who is acting, under what rules, at what cost

The first four are cognitive domains. The fifth — `&govern` — is the cross-cutting primitive that makes governance a declared, composable capability rather than an afterthought. `&govern.telemetry` tracks operational metrics, `&govern.escalation` defines deferral policies, and `&govern.identity` manages agent authentication and authorization.

This is intentionally compact. A smaller primitive set is easier to standardize, while namespaces allow specialization.

### Capability interfaces, not product names

A key design choice is that capabilities are interfaces, not vendors.

`&memory.graph` is a protocol capability. `graphonomous` is one provider that may satisfy it. The same capability might also be implemented by another provider if it satisfies the same contract.

This keeps the protocol open and avoids collapsing architecture into brand names.

### Canonical declaration: `ampersand.json`

A declaration such as `ampersand.json` becomes the canonical source of truth for an agent’s capability architecture. It can express:

- agent identity
- version
- capability bindings
- provider-specific config
- auto-resolved needs
- governance
- provenance preferences

That declaration can then be validated against a JSON Schema and processed by tooling.

### Compiles into MCP + A2A

This is the adoption story.

The protocol does not ask developers to abandon MCP or A2A. Instead, it treats those protocols as downstream targets.

From one declaration, a conforming toolchain should be able to generate:

- MCP client/server configuration for declared providers
- A2A-style agent cards that advertise composed capabilities as skills

This makes the protocol complementary to the ecosystem rather than competitive with it.

### Reference implementation

A useful protocol needs more than prose. It needs runnable artifacts.

A minimal reference stack should therefore include:

- a schema for `ampersand.json`
- example declarations
- contract validation logic
- composition checks
- MCP config generation
- A2A card generation
- a CLI for validate / compose / generate flows

Once those exist, documentation and AI-assisted development become much more reliable because they are grounded in real structures.

## 5. Try It

The easiest way to understand the protocol is to interact with the actual artifacts.

Start with the schema:

- `protocol/schema/v0.1.0/ampersand.schema.json`

Then inspect example declarations:

- `examples/infra-operator.ampersand.json`
- `examples/research-agent.ampersand.json`
- `examples/fleet-manager.ampersand.json`
- `examples/customer-support.ampersand.json`

Then use the CLI from the Elixir reference implementation:

- `ampersand validate <file>`
- `ampersand compose <file>`
- `ampersand generate mcp <file>`
- `ampersand generate a2a <file>`

That workflow shows the intended developer experience:

1. declare the agent once
2. validate the declaration
3. check composition semantics
4. generate downstream protocol configuration

## Conclusion

The agent ecosystem already has strong momentum around tool connectivity and agent coordination. That is necessary, but it is not sufficient.

There is still no widely shared, machine-readable way to describe how an agent’s internal cognitive capabilities compose into a valid, governable, auditable system. That gap becomes more painful as systems become more complex, more regulated, and more distributed.

The [&] Protocol treats composition as a first-class protocol concern.

It gives developers a compact vocabulary for memory, reasoning, time, space, and governance. It gives implementations a schema to validate against. It gives tooling a way to check contracts and preserve provenance. And it gives the broader ecosystem a source-of-truth declaration that can compile into MCP and A2A surfaces.

That is the missing layer.

Not another runtime.  
Not another transport.  
A composition layer.
