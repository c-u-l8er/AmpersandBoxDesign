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
- **Ecosystem Overview** explains how all twelve products compose through the five primitives.
- **Industry Verticals** maps seven commercial industries where all five primitives deliver value.
- **Capability pages** explain the five core primitives in more detail.
- **Skills** are hands-on, step-by-step guides covering the full declare → validate → compose → generate workflow, plus provider implementation, governance, and integration patterns.

## What you'll find here

- A practical overview of the protocol's role in the agent stack
- A runtime walkthrough covering declaration → validation → composition → resolution → generation
- Explanations of capability declaration, contracts, provenance, and governance
- Comparisons with MCP, A2A, ACP, and related work
- Deep dives into `&memory`, `&reason`, `&time`, `&space`, and `&govern`
- **Skills guides** for hands-on implementation — from writing your first `ampersand.json` to building providers and governance policies

## Documentation map


```{toctree}
:maxdepth: 1
:caption: Homepages

[&] Ampersand Box <https://ampersandboxdesign.com>
Graphonomous <https://graphonomous.com>
BendScript <https://bendscript.com>
WebHost.Systems <https://webhost.systems>
Agentelic <https://agentelic.com>
AgenTroMatic <https://agentromatic.com>
Delegatic <https://delegatic.com>
Deliberatic <https://deliberatic.com>
FleetPrompt <https://fleetprompt.com>
GeoFleetic <https://geofleetic.com>
OpenSentience <https://opensentience.org>
SpecPrompt <https://specprompt.com>
TickTickClock <https://ticktickclock.com>
```

```{toctree}
:maxdepth: 1
:caption: Root Docs

[&] Protocol Docs <https://docs.ampersandboxdesign.com>
Graphonomous Docs <https://docs.graphonomous.com>
BendScript Docs <https://docs.bendscript.com>
WebHost.Systems Docs <https://docs.webhost.systems>
Agentelic Docs <https://docs.agentelic.com>
AgenTroMatic Docs <https://docs.agentromatic.com>
Delegatic Docs <https://docs.delegatic.com>
Deliberatic Docs <https://docs.deliberatic.com>
FleetPrompt Docs <https://docs.fleetprompt.com>
GeoFleetic Docs <https://docs.geofleetic.com>
OpenSentience Docs <https://docs.opensentience.org>
SpecPrompt Docs <https://docs.specprompt.com>
TickTickClock Docs <https://docs.ticktickclock.com>
```

```{toctree}
:maxdepth: 2
:caption: [&] Protocol Docs

quickstart
architecture
runtime-walkthrough
ecosystem-overview
positioning
competitive-landscape
topology-is-the-authority
use-cases-autonomous-systems
use-cases-industry-verticals
comparison-table
research
faq
```

```{toctree}
:maxdepth: 1
:caption: Capabilities & Registry

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
capabilities/govern
registry/govern.telemetry
registry/govern.escalation
registry/govern.identity
```

```{toctree}
:maxdepth: 1
:caption: Skills

skills/SKILLS
skills/01_DECLARATION
skills/02_VALIDATION
skills/03_COMPOSITION
skills/04_CONTRACTS
skills/05_GENERATION
skills/06_CLI_REFERENCE
skills/07_INTEGRATION_PATTERNS
skills/08_PROVIDER_IMPLEMENTATION
skills/09_GOVERNANCE_PROVENANCE
skills/10_ANTI_PATTERNS
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
9. Capability deep dives — explore the five core capability families in detail once the runtime model is clear
10. `skills/SKILLS` — hands-on implementation skills registry; start here when you're ready to build
    - `01_DECLARATION` → `02_VALIDATION` → `03_COMPOSITION` → `04_CONTRACTS` → `05_GENERATION` (core workflow)
    - `06_CLI_REFERENCE` (command reference)
    - `07_INTEGRATION_PATTERNS` → `08_PROVIDER_IMPLEMENTATION` (advanced)
    - `09_GOVERNANCE_PROVENANCE` → `10_ANTI_PATTERNS` (governance and guardrails)

## Core idea

A concise framing for the protocol is:

> MCP defines how agents call tools.  
> A2A defines how agents call agents.  
> [&] defines how capabilities compose into a coherent agent.

The goal is not to replace existing protocols, but to provide a **source-of-truth composition layer** that sits above runtime wiring and makes agent architecture explicit, portable, and auditable.
