# [&] Protocol Documentation

Welcome to the documentation hub for the **[&] Protocol**.

The [&] Protocol is a language-agnostic specification for **capability composition in AI agents**. It defines how an agent declares what it can remember, how it reasons, how it understands time and space, how those capabilities compose, and how that declaration can compile into downstream runtime artifacts such as MCP and A2A configurations.

Use this documentation to understand the protocol from multiple angles:

- **Architecture** explains the system model, runtime lifecycle, and end-to-end declaration flow.
- **Positioning** compares [&] with adjacent standards and research.
- **Competitive Landscape** maps the machine cognition market and explains the structural constraints facing each competitor category.
- **Topology Is the Authority** explains why governance must emerge from feedback topology, not be bolted onto architecture.
- **Autonomous Systems** explains why autonomous vehicles and drone swarms are the canonical [&] use case, including the Palantir integration surface and κ-driven swarm governance.
- **Research** provides the motivation for a composition layer in the agent stack.
- **FAQ** answers common questions quickly.
- **Capability pages** explain the four core primitives in more detail.

## What you'll find here

- A practical overview of the protocol's role in the agent stack
- A runtime walkthrough covering declaration → validation → composition → resolution → generation
- Explanations of capability declaration, contracts, provenance, and governance
- Comparisons with MCP, A2A, ACP, and related work
- Deep dives into `&memory`, `&reason`, `&time`, and `&space`

## Documentation map

```{toctree}
:maxdepth: 2
:caption: Documentation

quickstart
architecture
runtime-walkthrough
positioning
competitive-landscape
topology-is-the-authority
use-cases-autonomous-systems
comparison-table
research
registry/README
capabilities/memory
registry/memory.episodic
registry/memory.graph
capabilities/reason
registry/reason.argument
registry/reason.deliberate
registry/reason.attend
capabilities/time
registry/time.forecast
capabilities/space
registry/space.fleet
faq
```

## Suggested reading order

If you're new to the project, a good path is:

1. `quickstart` — get from clone to a working `ampersand` CLI in minutes, with reproducible command output
2. `architecture` — understand the protocol's responsibilities, runtime lifecycle, and end-to-end declaration flow
3. `runtime-walkthrough` — follow a concrete declaration through validation, composition, provider resolution, and generation
4. `positioning` — see where [&] fits relative to MCP, A2A, ACP, and DALIA
5. `competitive-landscape` — understand the structural constraints facing every competitor category in machine cognition
6. `topology-is-the-authority` — why governance must emerge from feedback topology, not be configured on top
7. `research` — understand the ecosystem and research pressures behind the design
8. `faq` — get quick answers to common adoption and framing questions
9. Capability deep dives — explore the four core capability families in detail once the runtime model is clear

## Core idea

A concise framing for the protocol is:

> MCP defines how agents call tools.  
> A2A defines how agents call agents.  
> [&] defines how capabilities compose into a coherent agent.

The goal is not to replace existing protocols, but to provide a **source-of-truth composition layer** that sits above runtime wiring and makes agent architecture explicit, portable, and auditable.
