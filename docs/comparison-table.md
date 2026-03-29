# [&] vs MCP vs A2A vs DALIA vs ACP

This document positions the [&] Protocol relative to adjacent standards, research efforts, and ecosystem protocols.

The short version:

- **MCP** standardizes agent-to-tool connectivity.
- **A2A** standardizes agent-to-agent coordination.
- **ACP** standardizes lightweight agent communication over network APIs.
- **DALIA** highlights the need for compositional intelligence architectures at the research level.
- **[&]** defines the **capability composition layer**: how an agent declares, validates, binds, and governs its cognitive capabilities before compiling into runtime protocols.

The right framing is not replacement, but composition:

> [&] compiles into MCP + A2A configurations.

---

## Comparison Table

| System | Primary Scope | Layer in the Stack | Main Unit of Abstraction | What It Standardizes Well | What It Does **Not** Standardize | Relationship to [&] |
|---|---|---|---|---|---|---|
| **[&] Protocol** | Capability composition for agents | Composition | Capability declarations, contracts, provenance, governance | How memory, reasoning, time, space, and governance capabilities are declared, validated, composed, and compiled into downstream configs | Low-level transport protocols, direct tool RPC semantics, agent network communication | Source-of-truth layer |
| **MCP** | Agent-to-tool connectivity | Context / Tooling | Tools, resources, prompts, client-server interaction | Tool discovery, tool invocation, structured context access, resource exposure | How an agent's cognitive capabilities are selected, composed, governed, or provenance-linked | [&] can generate MCP configuration |
| **A2A** | Agent-to-agent coordination | Coordination | Agent cards, skills, tasks, delegation flows | Agent discovery, advertised skills, delegation and inter-agent interaction | How internal cognitive capabilities are composed or validated before publication | [&] can generate A2A agent cards |
| **ACP** | Lightweight agent communication | Communication | HTTP/REST-style agent endpoints and message exchange | Inter-agent messaging and integration patterns over standard web infrastructure | Capability algebra, provenance semantics, governance-as-data, typed capability composition | Adjacent network protocol; [&] sits at a different concern boundary |
| **DALIA** | Research framework for compositional intelligence | Research / Theory | Cognitive architecture model | Why modular, compositional agent intelligence matters; academic framing for layered capability systems | A production-ready protocol artifact, schema, CLI, registry, or runtime config format | Independent conceptual validation of the gap [&] addresses |

---

## Quick Definitions

### [&] Protocol
An open, language-agnostic protocol for composing agent cognitive capabilities. It defines:

- canonical `ampersand.json`
- capability primitives like `&memory`, `&reason`, `&time`, `&space`, and `&govern`
- namespaced subtypes like `&memory.graph` and `&time.anomaly`
- capability contracts with typed operations
- composition algebra properties
- provenance records
- governance constraints
- compilation targets such as MCP and A2A artifacts

### MCP
The Model Context Protocol focuses on connecting agents to tools, resources, and prompts. It standardizes the agent-to-tool interface, not the internal capability model of the agent.

### A2A
The Agent-to-Agent Protocol focuses on how agents discover each other, advertise skills, and coordinate tasks. It assumes an agent already exists and exposes an interaction surface.

### ACP
The Agent Communication Protocol focuses on interoperable communication between agents or agent-like services, often through lightweight network-native interfaces.

### DALIA
A research effort that treats intelligence as compositional and layered. DALIA helps articulate why capability composition matters, but it is not itself a deployable protocol specification in the same sense.

---

## The Stack View

A useful mental model is:

| Layer | Question | Example Protocols |
|---|---|---|
| UI | How does the agent render and interact with users? | AG-UI, A2UI |
| **Composition** | What capabilities make up this agent, and how do they fit together? | **[&]** |
| Coordination | How do agents discover and delegate to each other? | A2A |
| Context | How does an agent access tools and resources? | MCP |
| Communication | How do services and agents exchange messages over networks? | ACP, HTTP, gRPC |

This is why [&] should not be framed as "above" MCP or A2A in a political or replacement sense. A better and more accurate statement is:

> [&] defines the composition layer and compiles into MCP + A2A configurations.

---

## Where MCP Is Strong

MCP is strong when you need:

- a standard way to expose tools
- structured resources and prompts
- agent access to external systems
- clear client/server boundaries
- tool interoperability across runtimes

MCP is not trying to answer questions like:

- Should this agent have episodic memory or graph memory?
- Is `&time.anomaly` compatible with `&reason.argument` in this pipeline?
- What governance rules constrain this agent's actions?
- How do I preserve a provenance chain across composed cognition?

Those are composition-layer concerns, which is exactly why [&] exists.

---

## Where A2A Is Strong

A2A is strong when you need:

- agent discovery
- advertised skills
- task delegation
- multi-agent workflow handoff
- machine-readable agent cards

A2A starts from the perspective that an agent has already been built and is now publishing its capabilities outward.

[&] starts earlier. It defines how the agent is composed in the first place.

That makes the relationship complementary:

- **[&]** describes internal composition
- **A2A** describes external coordination

---

## Where ACP Is Strong

ACP is strong when you need:

- lightweight inter-agent communication
- simple network-native interfaces
- integration over common web patterns
- deployable communication surfaces without requiring tool-specific semantics

ACP is closest to a communications substrate. It is useful for transport and interoperability, but it does not define:

- capability primitives
- capability subtypes
- composition algebra
- provenance chain structure
- governance constraints as portable data

So ACP and [&] solve different problems.

---

## Why DALIA Matters Here

DALIA is important because it strengthens the claim that there is a real conceptual gap in the ecosystem.

It supports ideas like:

- intelligence as composition rather than monolith
- modular cognitive systems
- layered capabilities
- architectural clarity between memory, reasoning, planning, governance, and execution

That is useful because [&] is not just inventing a product category. It is operationalizing a real architectural need into:

- schema artifacts
- machine-readable contracts
- validation logic
- generation tools
- protocol-ready outputs

DALIA is a research signal; [&] is a protocol implementation strategy.

---

## Decision Guide

If your question is:

### "How does my agent call tools?"
Use **MCP**.

### "How do my agents find and delegate to each other?"
Use **A2A**.

### "How do my agent services communicate over network APIs?"
Use **ACP**.

### "How should I think about intelligence as a compositional architecture?"
Read **DALIA**.

### "How do I declare, validate, govern, and compile an agent's cognitive capabilities?"
Use **[&]**.

---

## Side-by-Side by Concern

| Concern | [&] | MCP | A2A | ACP | DALIA |
|---|---|---|---|---|---|
| Capability declaration | Yes | No | No | No | Conceptually |
| Capability composition algebra | Yes | No | No | No | Conceptually |
| Typed capability contracts | Yes | Partial at tool boundary | Skill-level only | No | Conceptually |
| Governance as portable data | Yes | No | Limited / indirect | No | Conceptually |
| Provenance chain semantics | Yes | Not core | Not core | No | Conceptually |
| Tool invocation protocol | No | Yes | No | No | No |
| Agent discovery / delegation | No | No | Yes | Partial | No |
| Network communication substrate | No | Partial | Partial | Yes | No |
| Schema-first source of truth | Yes | Yes, but for tool interfaces | Yes, for agent cards | Varies | No |
| Runtime configuration generation | Yes | N/A | N/A | N/A | No |

---

## The Important Non-Competitive Framing

This repository should consistently avoid the claim that [&] competes with MCP or A2A.

The accurate position is:

- MCP and A2A are valuable standards
- they solve different layers of the stack
- neither standardizes internal capability composition
- [&] fills that missing concern
- [&] produces artifacts that are useful to MCP and A2A ecosystems

The safest one-line framing is:

> [&] is the source-of-truth composition layer that compiles into MCP + A2A configurations.

---

## Practical Example

A developer may start with this declaration:

- `&memory.graph`
- `&time.anomaly`
- `&space.fleet`
- `&reason.argument`
- `&govern.escalation`

From that, [&] can produce:

1. a validated `ampersand.json`
2. composition checks and compatibility validation
3. governance metadata
4. provenance requirements
5. an MCP config for tool-facing runtime integration
6. an A2A agent card for coordination-facing publication

MCP alone does not give you the declaration model.
A2A alone does not give you the declaration model.
ACP alone does not give you the declaration model.

That declaration model is the missing layer.

---

## Summary

The five systems are best understood as different answers to different questions:

- **MCP**: how an agent uses tools
- **A2A**: how agents work with other agents
- **ACP**: how agents communicate over APIs
- **DALIA**: why compositional intelligence matters
- **[&]**: how an agent's capabilities are declared, composed, validated, governed, and compiled

That distinction is the core positioning of the [&] Protocol.