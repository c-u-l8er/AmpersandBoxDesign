# [&] Protocol Documentation

Welcome to the documentation hub for the **[&] Protocol**.

The [&] Protocol is a language-agnostic specification for **capability composition in AI agents**. It defines how an agent declares what it can remember, how it reasons, how it understands time and space, how those capabilities compose, and how that declaration can compile into downstream runtime artifacts such as MCP and A2A configurations.

Use this documentation to understand the protocol from multiple angles:

- **Architecture** explains the system model and how core artifacts fit together.
- **Positioning** compares [&] with adjacent standards and research.
- **Research** provides the motivation for a composition layer in the agent stack.
- **FAQ** answers common questions quickly.
- **Capability pages** explain the four core primitives in more detail.

## What you'll find here

- A practical overview of the protocol's role in the agent stack
- Explanations of capability declaration, contracts, provenance, and governance
- Comparisons with MCP, A2A, ACP, and related work
- Deep dives into `&memory`, `&reason`, `&time`, and `&space`

## Documentation map

```{toctree}
:maxdepth: 2
:caption: Documentation

architecture
positioning
comparison-table
research
faq
capabilities/memory
capabilities/reason
capabilities/time
capabilities/space
```

## Suggested reading order

If you're new to the project, a good path is:

1. `architecture` — understand the protocol's responsibilities and system model
2. `positioning` — see where [&] fits relative to MCP, A2A, ACP, and DALIA
3. `research` — understand the ecosystem and research pressures behind the design
4. `faq` — get quick answers to common adoption and framing questions
5. Capability deep dives — explore the four core capability families in detail

## Core idea

A concise framing for the protocol is:

> MCP defines how agents call tools.  
> A2A defines how agents call agents.  
> [&] defines how capabilities compose into a coherent agent.

The goal is not to replace existing protocols, but to provide a **source-of-truth composition layer** that sits above runtime wiring and makes agent architecture explicit, portable, and auditable.