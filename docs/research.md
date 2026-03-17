# Research Overview

This document is the research-oriented companion for the [&] Protocol documentation hub.

Its purpose is to explain **why capability composition is emerging as a distinct problem in the agent ecosystem**, how that problem relates to current protocol work, and which research threads most directly support the protocol’s design.

This is not a full literature review. It is a structured overview of the ideas, pressures, and signals that make a composition layer plausible now.

---

## Executive Summary

The agent ecosystem is maturing in recognizable layers:

- **tool and resource connectivity** via protocols such as MCP
- **agent-to-agent coordination** via protocols such as A2A
- **communication and transport** via ACP, HTTP, gRPC, and related infrastructure
- **UI and rendering** via interface-oriented protocols and frameworks

These layers matter, but they do not fully address a different question:

> How should an agent declare, validate, and govern the cognitive capabilities that make it up before runtime wiring begins?

That is the research and protocol gap the [&] Protocol addresses.

The relevant convergence is happening across four fronts:

1. **industry standardization** around MCP and A2A
2. **cognitive architecture research** that decomposes intelligence into functional systems
3. **memory/reasoning systems work** that makes capability boundaries more explicit
4. **governance and provenance demands** driven by safety, auditability, and operational trust

The result is a clear opening for a composition layer built around:

- capability declaration
- typed contracts
- composition algebra
- provenance
- governance as data
- compilation into downstream runtime protocols

---

## 1. Why This Research Matters

The strongest reason to study this space is that agent systems are no longer just prompt wrappers around a single model invocation.

Production systems now combine:

- retrieval layers
- graph or vector memory
- planning or deliberation systems
- temporal pattern detection
- routing and location awareness
- policy constraints
- external tool invocation
- multi-agent delegation

Once agents become multi-capability systems, the architectural question changes.

It is no longer enough to say:

- “this agent has memory”
- “this agent can reason”
- “this agent can call tools”

Those statements are too vague for interoperability and too vague for validation.

A more useful question is:

- what kind of memory?
- what kind of reasoning?
- what temporal or spatial intelligence is involved?
- what contracts do those components satisfy?
- how do they compose?
- how is provenance preserved?
- where do constraints live?

That is why a research overview is useful: it shows that the protocol problem is not arbitrary. It emerges from real architectural pressure.

---

## 2. The Current Protocol Stack

The current ecosystem already has strong momentum in adjacent areas.

### MCP

MCP is important because it standardizes **agent-to-tool connectivity**.

It gives agents a consistent way to discover and invoke tools, resources, and prompts. This is a major step toward interoperability at the context layer.

But MCP does not attempt to define:

- cognitive primitives
- capability composition
- governance semantics
- provenance chain structure
- compatibility between internal agent capabilities

It standardizes invocation surfaces, not internal capability architecture.

### A2A

A2A is important because it standardizes **agent-to-agent coordination**.

It gives agents a way to advertise skills, publish agent cards, and coordinate with other agents.

But A2A begins with the assumption that an agent already exists and is ready to expose itself externally. It does not define how that agent was internally composed.

### ACP and adjacent work

ACP and similar work help standardize communication patterns.

Operational projects around agent infrastructure improve:

- observability
- scaling
- testing
- evaluation
- deployment discipline

All of that is useful, but it still leaves a conceptual and practical gap between:

- “agent can call tools”
- and
- “agent is composed from validated capabilities with explicit governance and provenance”

That gap is the composition layer.

---

## 3. Research Thread: Cognitive Architectures

A major source of support for the [&] model comes from cognitive architecture research.

### Why cognitive architecture matters

Cognitive architectures treat intelligence as a system of interacting functions rather than a single monolithic process.

That perspective maps naturally onto the protocol’s primitive domains:

- **memory**
- **reason**
- **time**
- **space**

This is not a claim that the protocol is a neuroscience model. It is a claim that practical agent systems benefit from a functional decomposition that resembles the way cognitive architecture research breaks down intelligence.

### Why this supports a protocol

Once intelligence is decomposed into distinct functional concerns, it becomes possible to standardize:

- interfaces between concerns
- contracts for each concern
- composition rules
- implementation-agnostic declarations

This is exactly the shift from “framework code” to “protocol artifact.”

### Why now

Earlier generations of AI software often hid architecture behind application code. Modern agent systems increasingly expose architecture in configuration, orchestration, or retrieval layers. That makes the step toward a formal capability declaration much more plausible.

---

## 4. Research Thread: Memory Systems

Memory is one of the clearest areas where capability distinctions matter.

In practice, “memory” now often means multiple different things:

- graph memory
- vector retrieval memory
- episodic recall
- durable long-term storage
- short-term working context
- consolidation pipelines

These are not interchangeable.

A graph memory system supports different queries and reasoning patterns than a vector store. An episodic memory system supports different use cases than a simple semantic retrieval layer.

That means memory is already a namespace of capabilities, not a single feature flag.

This is one reason the protocol models memory as:

- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`

The research landscape supports this move because modern agent memory work already treats memory as plural.

### Why memory research matters to the protocol

It reinforces three protocol ideas:

1. **capabilities should be typed**
2. **providers should be separated from interfaces**
3. **downstream pipelines should know what form of memory they are receiving**

Without that distinction, “agent memory” becomes a vague marketing term rather than a composable system component.

---

## 5. Research Thread: Reasoning and Deliberation

Reasoning is another place where capability boundaries matter.

Agent systems increasingly use multiple reasoning modes:

- argumentation
- voting
- planning
- critique
- self-reflection
- evidence comparison
- tool-assisted verification

Again, these are not identical.

A system built around deliberative argument is not equivalent to one built around weighted voting or one-step planning. If an agent declaration says only “has reasoning,” it hides the operationally important part.

The protocol therefore models reasoning as a namespace, for example:

- `&reason.argument`
- `&reason.vote`
- `&reason.plan`

### Why this matters

Reasoning strategy affects:

- explainability
- governance compatibility
- escalation paths
- auditability
- acceptable inputs and outputs
- how much provenance needs to be preserved

This makes reasoning a natural fit for typed contracts and governance-aware declaration.

---

## 6. Research Thread: Time and Temporal Intelligence

Time is often under-modeled in agent systems even though many real-world tasks depend on it.

Examples include:

- anomaly detection
- forecasting
- trend recognition
- sequence modeling
- seasonality
- decay and recency weighting
- event windows

A support agent, fleet optimizer, or infrastructure operator often depends on temporal behavior, not just current-state lookup.

That is why the protocol treats temporal capability as first-class:

- `&time.anomaly`
- `&time.forecast`
- `&time.pattern`

### Why this matters for composition

Temporal outputs are not always interchangeable with memory or reasoning outputs.

A forecast may produce one type of signal.
An anomaly detector may produce another.
A downstream reasoner may require enriched context rather than raw temporal output.

This is exactly where typed contracts and pipeline validation become useful.

---

## 7. Research Thread: Space and Spatial Intelligence

Spatial intelligence is also easy to ignore until the system must reason about:

- fleets
- routes
- regions
- geofences
- locations
- topology
- asset distribution

In logistics, operations, robotics, and physical systems, this is not optional.

The protocol treats these as spatial capabilities such as:

- `&space.fleet`
- `&space.route`
- `&space.geofence`

### Why this matters

Spatial context is often the missing dimension in otherwise “intelligent” agents.

An agent can remember, retrieve, and reason—but still fail if it cannot represent where assets are, which regions are affected, or how routes constrain action.

From a research perspective, this supports the idea that cognition for real-world agents is multi-domain rather than purely symbolic or purely linguistic.

---

## 8. Research Thread: Taxonomy and Functional Decomposition

One of the strongest external supports for the protocol model is work that treats agent cognition as a taxonomy rather than an undifferentiated blob.

The general pattern is:

- break cognition into functions
- make those functions explicit
- reason about interfaces between them
- keep architecture inspectable

This kind of decomposition appears across:

- memory taxonomies
- planning systems
- deliberation systems
- agent architecture work
- embodied cognition and situated reasoning research

The protocol’s primitive structure is intentionally simple, but it follows the same broad direction:
a small number of high-level domains with extensible subtype namespaces.

That balance matters.

Too few categories and the protocol becomes vague.
Too many categories and the protocol becomes unusable.

---

## 9. Research Thread: Provenance, Auditability, and Trust

A major reason composition is becoming more important is that systems are increasingly expected to be explainable and auditable.

That expectation comes from multiple pressures:

- enterprise governance
- safety engineering
- internal debugging
- regulated workflows
- customer trust
- postmortem and incident analysis

If an agent decision combines:

- memory retrieval
- anomaly detection
- spatial context
- deliberative reasoning

then a useful system should be able to answer:

- what data entered the decision path?
- which capability produced which intermediate artifact?
- what provider produced the result?
- what was the sequence of transformations?
- what rules constrained the output?

This is where provenance shifts from a “nice tracing feature” to a protocol concern.

### Why hash-linked provenance matters

Hash-linked provenance is useful because it preserves sequence and dependency, not just logs.

It creates a chain of evidence that can be inspected after the fact.
That makes provenance a natural part of capability composition rather than an afterthought.

---

## 10. Research Thread: Governance as Data

Another major convergence is the shift from “prompt policy” toward more explicit forms of control.

Teams increasingly need systems to represent:

- hard operational boundaries
- soft preferences
- escalation triggers
- approval conditions
- cost thresholds
- confidence thresholds

If those rules live only in scattered framework code or prompts, they are hard to port and hard to audit.

The protocol’s answer is to treat governance as part of the declaration itself.

That is a research-informed move because many safety and governance problems are really interface problems:
the constraint exists, but it is not represented in a portable, inspectable form.

Putting governance in data makes it:

- visible
- testable
- portable
- generatable
- reviewable

---

## 11. Why a Composition Layer Is Plausible Now

A composition layer becomes plausible only when several conditions are true at once.

### Condition 1: adjacent protocols exist

MCP and A2A already provide surrounding layers.
That means composition does not need to solve everything.
It can focus on its own concern boundary.

### Condition 2: agent systems are increasingly modular

Real systems already distinguish between memory, retrieval, planning, reasoning, and tool use.
The architecture is already there, even when the declaration format is not.

### Condition 3: schemas and generators are acceptable developer tools

Modern developer workflows are comfortable with:

- JSON Schema
- contract files
- registry documents
- code generation
- CLI validation
- machine-readable configuration

That makes a schema-first protocol socially and technically plausible.

### Condition 4: auditability pressure is increasing

The more consequential agents become, the less acceptable opaque composition becomes.

---

## 12. What the [&] Protocol Adds

Against this background, the protocol contributes a concrete set of ideas:

### A canonical declaration

A single source artifact: `ampersand.json`

### Capability primitives with namespaces

A compact vocabulary:

- `&memory`
- `&reason`
- `&time`
- `&space`

with extensible subtypes.

### Composition algebra

Deterministic behavior for capability sets:

- commutative
- associative
- idempotent
- identity-safe

### Capability contracts

Explicit input/output typing and adjacency rules via:

- `operations`
- `accepts_from`
- `feeds_into`
- `a2a_skills`

### Provenance model

Hash-linkable records that preserve decision lineage.

### Governance model

Constraints and escalation rules represented as data.

### Downstream compilation

The declaration is not isolated. It can generate:

- MCP config
- A2A-style agent cards
- future runtime artifacts

This is the core point:
the protocol turns composition into a machine-readable layer instead of leaving it as prose, framework convention, or private architecture.

---

## 13. Important Open Questions

A research overview should also be honest about what remains open.

### How many primitives are enough?

The current four-domain model is intentionally compact, but future implementations may raise pressure for more domains or more formal subtype hierarchies.

### How strict should contracts be?

There is a tradeoff between:

- portability and flexibility
- strong typing and adoption friction

### How much provenance is mandatory?

Implementations may differ in storage and tracing depth, even if the protocol defines a common record shape.

### How should registries evolve?

Provider registries can become complex quickly once they include:

- capabilities
- versions
- transport details
- compatibility metadata
- governance traits
- cost information

### How much should the protocol standardize vs delegate?

A good protocol should define enough to be useful without overreaching into every runtime concern.

These are healthy questions. They indicate that the problem is real.

---

## 14. Reading Map

If you are exploring the repository through the lens of this research overview, a useful order is:

1. `docs/positioning.md`
2. `SPEC.md`
3. `protocol/schema/v0.1.0/ampersand.schema.json`
4. `protocol/schema/v0.1.0/capability-contract.schema.json`
5. `protocol/schema/v0.1.0/registry.schema.json`
6. `examples/`
7. `reference/elixir/ampersand_core/`

This path moves from:
concept → contract → example → implementation

---

## 15. Conclusion

The research case for the [&] Protocol is not that no one has worked on agents before.

It is that the ecosystem now has enough maturity in adjacent layers, enough modularity in real systems, and enough demand for governance and provenance that **capability composition is ready to become a protocol concern of its own**.

The strongest supporting signals are:

- agent systems are increasingly multi-capability
- current protocols solve neighboring but different problems
- cognitive architecture research supports functional decomposition
- memory and reasoning systems already operate as capability families
- provenance and governance demands make opaque composition harder to justify

The result is a credible opening for a composition layer that is:

- schema-first
- provider-agnostic
- contract-aware
- provenance-aware
- governance-aware
- complementary to MCP and A2A

That is the research context in which the [&] Protocol should be understood.

---

## Suggested Next Reading

- `docs/positioning.md`
- `docs/comparison-table.md`
- `SPEC.md`
- `examples/README.md`
