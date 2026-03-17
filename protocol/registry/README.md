# Capability Registry Artifacts

This directory contains machine-readable registry artifacts for the [&] Protocol.

A registry artifact describes the currently known capability namespaces, their subtypes, compatible providers, and optional references to capability contracts. These files are intended to support discovery, validation, generation, and documentation workflows.

## Purpose

The registry layer exists to answer questions such as:

- Which capability subtypes are currently recognized by the protocol?
- Which providers claim to satisfy those subtypes?
- Which operations are associated with a subtype?
- Which A2A-facing skills can be derived from a capability?
- Which contract artifact should a validator or generator consult?

This is especially important for declarations that use:

- `provider: "auto"`

In that mode, the agent declaration expresses **what capability is needed**, while the registry helps resolve **which provider can satisfy it**.

## Relationship to the rest of the protocol

A useful way to think about the protocol artifact stack is:

1. `ampersand.json`
   - declares one agent's capabilities
2. capability contracts
   - define the typed operational behavior of one capability
3. registry artifacts
   - publish which subtypes and providers are available across the ecosystem

In other words:

- declarations describe a specific agent
- contracts describe a specific capability interface
- registries describe the available capability landscape

## Current layout

Artifacts in this directory are versioned.

Example structure:

- `v0.1.0/capabilities.registry.json`

That file is the canonical generated registry snapshot for protocol version `0.1.0`.

## Schema

Registry artifacts should validate against:

- `../protocol/schema/v0.1.0/registry.schema.json`

The schema defines the allowed structure for:

- registry metadata
- primitive roots such as `&memory`, `&reason`, `&time`, and `&space`
- subtype definitions
- provider definitions
- optional transport and metadata fields

## What a registry artifact contains

A typical registry artifact may include:

- top-level metadata
  - `$schema`
  - `version`
  - `registry`
  - `generated_at`
- primitive namespaces
  - `&memory`
  - `&reason`
  - `&time`
  - `&space`
- subtype entries for each primitive
- provider entries for each primitive
- optional references to contract artifacts
- optional A2A skill mappings
- optional provider transport details

## Example use cases

Registry artifacts are useful for:

### 1. Provider resolution

Given a declaration such as:

```json
{
  "&time.forecast": {
    "provider": "auto",
    "need": "predict next-day support volume"
  }
}
```

a registry can help a runtime determine which providers support `forecast` under `&time`.

### 2. CLI and validation tooling

Validation and generation tools can use the registry to:

- check whether a provider/subtype pairing is recognized
- list compatible providers for a capability
- enrich error messages and suggestions
- support future `ampersand registry` commands

### 3. MCP and A2A generation

Registry metadata can support downstream generation by exposing:

- provider transport type
- provider command or URL hints
- subtype operation sets
- A2A skill mappings

### 4. Documentation and programmatic pages

Registry data is a natural source for generating capability pages such as:

- `capabilities/memory.graph.md`
- `capabilities/reason.argument.md`
- `capabilities/time.forecast.md`
- `capabilities/space.fleet.md`

## Generated vs hand-authored data

Registry files should be treated as structured protocol artifacts, not ad hoc notes.

A registry artifact may be:

- written by hand early in the project
- generated from contract files and provider metadata later
- regenerated as the ecosystem grows

The important rule is that it should remain:

- machine-readable
- schema-valid
- versioned
- conservative about provider claims

## Grounding rule

Do not invent provider runtime details that are not backed by implementation evidence or documentation.

If a provider is known conceptually but its transport or launch details are not yet stable, prefer:

- omitting those fields
- marking the provider as experimental
- leaving richer resolution to future registry versions

Explicitly incomplete data is better than fabricated data.

## Versioning guidance

When the protocol evolves:

- create a new versioned registry artifact
- preserve older registry snapshots where possible
- update contract references to match the appropriate schema and contract version
- avoid silently mutating published registry meaning under the same version path

Example:

- `v0.1.0/capabilities.registry.json`
- `v0.2.0/capabilities.registry.json`

## Suggested future additions

As the registry layer matures, this directory may grow to include:

- generated indexes by provider
- generated indexes by primitive
- provider compatibility summaries
- changelogs between registry versions
- separate registries for stable vs experimental providers
- tooling that compiles contracts into registry artifacts

## Related paths

Useful related files in this repository:

- `../protocol/schema/v0.1.0/registry.schema.json`
- `../protocol/schema/v0.1.0/capability-contract.schema.json`
- `../contracts/v0.1.0/`
- `../examples/`
- `../reference/elixir/ampersand_core/`
- `../capabilities/`

## Summary

This directory holds the generated registry view of the [&] Protocol ecosystem.

If `ampersand.json` tells you what one agent declares, the registry tells you what the broader capability ecosystem currently makes available.
