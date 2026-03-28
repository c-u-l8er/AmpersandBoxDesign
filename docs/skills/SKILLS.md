# [&] Protocol — Agent Skills

> **Purpose:** Teach any LLM or developer how to use the [&] Protocol correctly,
> idiomatically, and in the right sequence. These files cover everything from
> writing your first agent declaration to building providers that satisfy
> capability contracts.

---

## Quick Orientation

The [&] Protocol is a **language-agnostic specification for capability composition
in AI agents**. It defines how agents declare cognitive capabilities (`&memory`,
`&reason`, `&time`, `&space`), how those compose via `&` and `|>` operators, and
how declarations compile into MCP and A2A configurations.

[&] sits at the **composition layer** of the agent protocol stack — above MCP
(agent-to-tool) and A2A (agent-to-agent). It does not replace either protocol.
It generates configurations for both.

### The Core Workflow

Every interaction with [&] follows this rhythm:

```
1. DECLARE   → Write an ampersand.json agent declaration
2. VALIDATE  → Check it against the JSON Schema (draft 2020-12)
3. COMPOSE   → Verify capability compatibility and ACI properties
4. GENERATE  → Compile to MCP config and/or A2A agent card
```

---

## Skill Files

| File | What It Teaches |
|------|----------------|
| [01_DECLARATION.md](01_DECLARATION.md) | Writing ampersand.json declarations — structure, capabilities, providers, config |
| [02_VALIDATION.md](02_VALIDATION.md) | Schema validation via CLI and SDKs — running checks, reading errors, batch mode |
| [03_COMPOSITION.md](03_COMPOSITION.md) | Capability composition — `&` operator, `\|>` pipelines, ACI properties, type safety |
| [04_CONTRACTS.md](04_CONTRACTS.md) | Capability contracts — operations, accepts_from/feeds_into, A2A skill mapping |
| [05_GENERATION.md](05_GENERATION.md) | Compiling declarations to MCP configs and A2A agent cards |
| [06_CLI_REFERENCE.md](06_CLI_REFERENCE.md) | Complete CLI command reference — flags, output formats, exit codes |
| [07_INTEGRATION_PATTERNS.md](07_INTEGRATION_PATTERNS.md) | Real-world composition recipes — temporal enrichment, fleet intelligence, full cognitive stack |
| [08_PROVIDER_IMPLEMENTATION.md](08_PROVIDER_IMPLEMENTATION.md) | Building a provider that satisfies a capability contract |
| [09_GOVERNANCE_PROVENANCE.md](09_GOVERNANCE_PROVENANCE.md) | Governance constraints, escalation rules, provenance chains |
| [10_ANTI_PATTERNS.md](10_ANTI_PATTERNS.md) | Common mistakes and how to avoid them |

---

## Tool Inventory (CLI Commands)

| Command | Purpose | Key Args |
|---------|---------|----------|
| `ampersand validate <file>` | Validate declaration against JSON Schema | `--schema <path>`, `--format json` |
| `ampersand compose <file>` | Check capability compatibility and ACI properties | `--verbose` |
| `ampersand generate mcp <file>` | Generate MCP server configuration | `--output <path>` |
| `ampersand generate a2a <file>` | Generate A2A agent card | `--output <path>` |

---

## Capability Primitives

The protocol defines exactly four fundamental capability domains:

| Primitive | Domain | Question It Answers | Subtypes |
|-----------|--------|--------------------|---------|
| `&memory` | State persistence | What the agent knows | `.graph`, `.vector`, `.episodic`, `.semantic` |
| `&reason` | Decision logic | How the agent decides | `.argument`, `.vote`, `.plan`, `.chain`, `.deliberate`, `.attend` |
| `&time` | Temporal modeling | When things happen | `.anomaly`, `.forecast`, `.pattern`, `.baseline` |
| `&space` | Spatial modeling | Where things are | `.fleet`, `.geofence`, `.route`, `.region` |

Capabilities are **interfaces**. Providers are **implementations**. `&memory.graph`
can be satisfied by Graphonomous, Neo4j, or any MCP-compatible graph service.

---

## Composition Operators

| Operator | Name | Semantics |
|----------|------|-----------|
| `&` | Compose | Combines capabilities into a validated set. ACI properties: Associative, Commutative, Idempotent. |
| `\|>` | Pipeline | Flows data through capability operations in sequence. Type-checked via `accepts_from`/`feeds_into` contracts. |

**Compose example:**
```
&memory.graph & &time.anomaly & &reason.argument
```

**Pipeline example:**
```
stream_data |> &time.anomaly.detect() |> &memory.graph.enrich() |> &reason.argument.evaluate()
```

---

## Suggested Reading Order

**Getting started (first-time users):**
1. `01_DECLARATION.md` — learn the declaration format
2. `02_VALIDATION.md` — validate your first file
3. `06_CLI_REFERENCE.md` — understand the CLI

**Building compositions:**
4. `03_COMPOSITION.md` — learn `&` and `|>` operators
5. `04_CONTRACTS.md` — understand type contracts
6. `07_INTEGRATION_PATTERNS.md` — see real-world recipes

**Going deeper:**
7. `05_GENERATION.md` — compile to MCP/A2A
8. `08_PROVIDER_IMPLEMENTATION.md` — build your own provider
9. `09_GOVERNANCE_PROVENANCE.md` — add governance and audit trails
10. `10_ANTI_PATTERNS.md` — avoid common mistakes

---

## Related Documentation

- `SPEC.md` — Full protocol specification (root of repo)
- `protocol/schema/v0.1.0/` — JSON Schema artifacts
- `examples/` — Reference agent declarations
- `contracts/v0.1.0/` — Capability contract definitions
- `docs/quickstart.md` — Quick start guide
- `docs/architecture.md` — Architecture overview
- `docs/runtime-walkthrough.md` — Runtime execution walkthrough
