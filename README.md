# [&] Protocol

The **[&] Protocol** is an open, language-agnostic specification for **capability composition in AI agents**.

It defines how an agent declares:

- what it can **remember**
- how it can **reason**
- how it understands **time**
- how it understands **space**
- how those capabilities **compose**
- how decisions retain **provenance**
- how constraints are expressed as **governance**
- how declarations compile into **MCP** and **A2A** configurations

The ampersand (`&`) is not branding syntax. It is the protocol’s core operator for composition.

---

## Why this exists

The current agent stack has useful protocol layers already:

- **MCP** for agent-to-tool connectivity
- **A2A** for agent-to-agent coordination
- **UI protocols** for rendering and interaction

What is still missing is a shared way to describe **how an agent’s cognitive capabilities fit together before runtime wiring begins**.

The [&] Protocol fills that gap.

It provides a source-of-truth artifact, `ampersand.json`, that can be:

- validated against a schema
- checked for composition correctness
- transformed into runtime configuration
- audited through provenance metadata
- extended across implementations and providers

In short:

> MCP defines how agents call tools.  
> A2A defines how agents call agents.  
> [&] defines how capabilities compose into a coherent agent.

---

## Core model

The protocol starts from four capability primitives:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

Each primitive can be refined with namespaced subtypes:

- `&memory.graph`
- `&memory.episodic`
- `&reason.argument`
- `&reason.vote`
- `&time.anomaly`
- `&time.forecast`
- `&space.fleet`
- `&space.route`

Composition is defined with two operators:

- `&` — combine capabilities into a set
- `|>` — flow data through capability operations

---

## Example declaration

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "InfraOperator",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "graphonomous",
      "config": { "instance": "infra-ops" }
    },
    "&time.anomaly": {
      "provider": "ticktickclock",
      "config": { "streams": ["cpu", "mem"] }
    },
    "&space.fleet": {
      "provider": "geofleetic",
      "config": { "regions": ["us-east"] }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": { "governance": "constitutional" }
    }
  },
  "governance": {
    "hard": ["Never scale beyond 3x in a single action"],
    "soft": ["Prefer gradual scaling over spikes"],
    "escalate_when": {
      "confidence_below": 0.7,
      "cost_exceeds_usd": 1000
    }
  },
  "provenance": true
}
```

---

## What the repository contains

This repository is the canonical home for the protocol and its reference artifacts.

### Specification
- `protocol.html` — current HTML specification
- `SPEC.md` — markdown protocol specification
- `prompts/PROTOCOL_PROMPT.md` — implementation-oriented protocol prompt

### Schemas
- `schema/v0.1.0/ampersand.schema.json` — canonical schema for `ampersand.json`
- `schema/v0.1.0/capability-contract.schema.json` — schema for capability contracts
- `schema/v0.1.0/registry.schema.json` — schema for capability registry documents

### Examples
- `examples/infra-operator.ampersand.json`
- `examples/research-agent.ampersand.json`
- `examples/fleet-manager.ampersand.json`
- `examples/customer-support.ampersand.json`
- `examples/README.md` — explains the reference declarations and how to use them

### Contracts
- `contracts/v0.1.0/memory.graph.contract.json`
- `contracts/v0.1.0/memory.vector.contract.json`
- `contracts/v0.1.0/memory.episodic.contract.json`
- `contracts/v0.1.0/reason.argument.contract.json`
- `contracts/v0.1.0/reason.vote.contract.json`
- `contracts/v0.1.0/reason.plan.contract.json`
- `contracts/v0.1.0/time.anomaly.contract.json`
- `contracts/v0.1.0/time.forecast.contract.json`
- `contracts/v0.1.0/time.pattern.contract.json`
- `contracts/v0.1.0/space.fleet.contract.json`
- `contracts/v0.1.0/space.route.contract.json`
- `contracts/v0.1.0/space.geofence.contract.json`

### Registry
- `registry/v0.1.0/capabilities.registry.json` — capability registry artifact with subtype, provider, and contract metadata

### Capability pages
- `capabilities/memory.graph.md`
- `capabilities/memory.episodic.md`
- `capabilities/reason.argument.md`
- `capabilities/time.forecast.md`
- `capabilities/space.fleet.md`

### Reference implementation
- `reference/elixir/ampersand_core/` — minimal Elixir implementation with:
  - schema validation
  - capability composition
  - contract checking
  - MCP generation
  - A2A generation
  - `ampersand` CLI

### Documentation
- `docs/positioning.md`
- `docs/faq.md`
- `docs/comparison-table.md`

### Website source
- `site/index.html`
- `site/protocol.html`
- `site/portfolio_company_complete_research.html`

---

## Quick start

### 1. Validate an agent declaration

From the Elixir reference implementation:

```bash
cd reference/elixir/ampersand_core
mix escript.build
./ampersand validate ../../../examples/infra-operator.ampersand.json
```

### 2. Check composition

```bash
./ampersand compose ../../../examples/infra-operator.ampersand.json
```

### 3. Generate MCP config

```bash
./ampersand generate mcp ../../../examples/infra-operator.ampersand.json
```

### 4. Generate an A2A agent card

```bash
./ampersand generate a2a ../../../examples/infra-operator.ampersand.json
```

---

## Current implementation status

The repository currently includes working foundations for:

- canonical protocol schema
- validating example declarations
- minimal Elixir reference implementation
- MCP config generation
- A2A-style agent card generation
- CLI commands for validate / compose / generate

This is an early protocol implementation, but it is already grounded in machine-checkable artifacts rather than only prose.

---

## Design principles

### 1. Capabilities are interfaces, not products
`&memory.graph` is a protocol capability.  
`graphonomous` is one provider that may satisfy it.

### 2. Composition should be deterministic
Capability sets should behave like algebraic sets: order and duplication should not change the result.

### 3. Governance belongs in data
Constraints should be portable across implementations, not trapped in one runtime.

### 4. Provenance is part of the protocol
A conforming implementation should preserve where context came from and how decisions were derived.

### 5. The protocol complements the ecosystem
[&] does not replace MCP or A2A.

It compiles into them.

---

## Roadmap

Near-term priorities:

1. complete schema suite
2. expand capability contract registry artifacts
3. deepen reference implementation
4. improve CLI ergonomics
5. publish stronger docs and positioning
6. add documentation hub pages for each primitive
7. generate high-quality capability registry pages

---

## Intended audience

This project is for:

- protocol designers
- agent framework authors
- infrastructure engineers
- AI platform teams
- researchers working on memory, reasoning, planning, provenance, and agent safety

---

## Status

**Status:** active design + implementation  
**Scope:** open protocol + reference implementation  
**Goal:** a portable composition layer for the agent ecosystem

---