# Capability Registry Pages

This directory contains the **capability registry pages** for the [&] Protocol.

These pages are intended to serve two purposes at the same time:

1. **human-readable documentation**
2. **stable, structured content for indexing, generation, and publishing**

Each page describes one concrete protocol capability such as:

- `memory.graph`
- `memory.episodic`
- `reason.argument`
- `time.forecast`
- `space.fleet`

The canonical protocol identifiers for these are:

- `&memory.graph`
- `&memory.episodic`
- `&reason.argument`
- `&time.forecast`
- `&space.fleet`

---

## What these pages are for

A capability page is the protocol-level explanation of a single capability subtype.

It should help a reader answer questions like:

- What does this capability mean?
- Why does it exist?
- When should an agent use it?
- What operations does it usually support?
- What inputs and outputs does it work with?
- What other capabilities does it compose well with?
- Which providers can satisfy it?
- What governance and provenance concerns apply?
- What MCP or A2A implications does it have?

In other words, these pages are the bridge between:

- the formal schema and contract artifacts
- the broader protocol specification
- concrete implementation and integration decisions

---

## Relationship to the rest of the repository

These pages complement several other protocol artifacts.

### Protocol specification
- `SPEC.md`
- `protocol.html`

These define the formal model, grammar, and architecture of the protocol.

### Schemas
- `schema/v0.1.0/ampersand.schema.json`
- `schema/v0.1.0/capability-contract.schema.json`
- `schema/v0.1.0/registry.schema.json`

These make the protocol machine-readable.

### Contract examples
- `contracts/v0.1.0/`

These define typed capability behavior such as operations, `accepts_from`, `feeds_into`, and `a2a_skills`.

### Registry artifact
- `registry/v0.1.0/capabilities.registry.json`

This publishes discoverable provider and subtype metadata.

### Deep-dive documentation
- `docs/capabilities/memory.md`
- `docs/capabilities/reason.md`
- `docs/capabilities/time.md`
- `docs/capabilities/space.md`

These explain the primitive domains.
The files in this directory explain specific capability pages inside those domains.

---

## Naming convention

Files in this directory use the capability subtype name as the filename.

Examples:

- `memory.graph.md`
- `memory.episodic.md`
- `reason.argument.md`
- `time.forecast.md`
- `space.fleet.md`

This mirrors the public route shape envisioned in the protocol roadmap:

- `/capabilities/memory.graph`
- `/capabilities/memory.episodic`
- `/capabilities/reason.argument`
- `/capabilities/time.forecast`
- `/capabilities/space.fleet`

---

## What a capability page should include

Each capability page should be substantial enough to stand on its own.

Recommended sections:

1. **Definition**  
   A concise explanation of the capability.

2. **Why it exists**  
   The architectural reason the capability is a first-class subtype.

3. **Position in the primitive family**  
   How it fits under `&memory`, `&reason`, `&time`, or `&space`.

4. **Capability contract summary**  
   A representative contract or contract excerpt.

5. **Operations**  
   Typical operations and what they do.

6. **Architecture patterns**  
   How the capability composes with other capabilities.

7. **Example declaration**  
   A realistic `ampersand.json` fragment.

8. **Example API or payload shape**  
   A representative implementation-facing example.

9. **Compatible providers**  
   Providers that may satisfy the capability contract.

10. **Governance implications**  
    Hard constraints, soft constraints, and escalation considerations.

11. **Provenance implications**  
    What should be preserved in the provenance chain.

12. **A2A and MCP implications**  
    How this capability may compile into downstream protocol artifacts.

13. **Research grounding**  
    Theoretical or systems background that motivates the capability.

14. **Anti-patterns**  
    Common mistakes in modeling or implementing the capability.

15. **Summary**  
    A short closing explanation of why the capability matters.

---

## Quality standard

These are **not** meant to be thin SEO pages.

A good capability page should be:

- technically useful
- accurate
- specific
- provider-agnostic at the protocol level
- grounded in the actual schema and contract model
- helpful to both implementers and readers discovering the protocol

A weak capability page usually does one or more of the following:

- repeats the subtype name without explaining it
- talks only in marketing language
- confuses provider names with capability identifiers
- has no contract or architecture context
- has no realistic examples
- is too short to help an engineer use the capability

---

## Current pages

At the moment, this directory includes:

- `memory.graph.md`
- `memory.episodic.md`
- `reason.argument.md`
- `time.forecast.md`
- `space.fleet.md`

These pages are the first set of high-quality registry entries and can act as templates for future pages.

---

## Suggested future pages

As the protocol expands, useful additions include:

- `memory.vector.md`
- `reason.vote.md`
- `reason.plan.md`
- `time.anomaly.md`
- `time.pattern.md`
- `space.route.md`
- `space.geofence.md`

These should be added only when they can be documented with enough quality and grounded protocol detail.

---

## Authoring guidance

When writing a new capability page:

- start from the protocol capability identifier, not the provider name
- keep the capability/provider distinction explicit
- use realistic examples
- align terminology with `SPEC.md`
- align contracts with `contracts/v0.1.0/`
- align registry metadata with `registry/v0.1.0/capabilities.registry.json`
- mention governance and provenance when they materially matter
- prefer clarity over hype

A simple rule of thumb:

> Write each page so that an engineer could understand what the capability is, how it composes, and how to implement or consume it without reading the whole repository first.

---

## Short summary

This directory is the protocol’s **capability-level documentation surface**.

The top-level spec explains the model.
The schemas validate the artifacts.
The contracts define typed behavior.
The registry publishes discovery metadata.

These pages explain what each capability actually means.