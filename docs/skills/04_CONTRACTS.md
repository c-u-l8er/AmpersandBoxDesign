# Skill 04 — Capability Contracts

> How to read and write capability contracts — the typed interfaces that
> define what a capability does, what it accepts, and what it feeds into.

---

## Why This Matters

Contracts are how the protocol enforces pipeline type safety. Without
contracts, composition is just syntax. With contracts, the protocol can
verify at declaration time that your pipeline will work at runtime.

---

## Contract Schema Structure

Every contract follows this shape:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&time.anomaly",
  "provider": "ticktickclock",
  "version": "0.1.0",
  "description": "Temporal anomaly detection for streaming or historical signals.",
  "operations": { ... },
  "accepts_from": [ ... ],
  "feeds_into": [ ... ],
  "a2a_skills": [ ... ],
  "metadata": { ... }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `capability` | Yes | The capability identifier (`&primitive.subtype`) |
| `provider` | Yes | Provider that satisfies this contract |
| `version` | Yes | Contract version (semver) |
| `description` | Yes | Human-readable description |
| `operations` | Yes | Map of operation names to input/output types |
| `accepts_from` | Yes | Types this capability can receive as input |
| `feeds_into` | Yes | Types this capability can produce as output targets |
| `a2a_skills` | No | A2A skill identifiers this maps to |
| `metadata` | No | Additional structured data |

---

## Operations Definition

Operations define what a capability can do. Each operation has typed
input and output:

```json
"operations": {
  "detect": {
    "in": "stream_data",
    "out": "anomaly_set",
    "description": "Detect anomalous events from temporal input signals.",
    "deterministic": false,
    "side_effects": false
  },
  "enrich": {
    "in": "context",
    "out": "enriched_context",
    "description": "Attach anomaly-derived context to an existing payload.",
    "deterministic": false,
    "side_effects": false
  },
  "learn": {
    "in": "observation",
    "out": "ack",
    "description": "Incorporate feedback to improve detection.",
    "deterministic": false,
    "side_effects": true
  }
}
```

| Field | Description |
|-------|-------------|
| `in` | Input type token this operation expects |
| `out` | Output type token this operation produces |
| `description` | What the operation does |
| `deterministic` | Whether same input always produces same output |
| `side_effects` | Whether the operation modifies state |

---

## accepts_from and feeds_into

These fields define the **type compatibility** of a capability:

```json
"accepts_from": ["&memory.*", "&space.*", "raw_data", "stream_data", "context"],
"feeds_into": ["&memory.*", "&reason.*", "&space.*", "output"]
```

**`accepts_from`** — What types can flow INTO this capability. Used to
validate that the previous pipeline step's output is compatible.

**`feeds_into`** — What types can flow OUT of this capability. Used to
validate that the next pipeline step can accept this output.

### Type token categories

| Category | Examples | Meaning |
|----------|---------|---------|
| Capability wildcards | `&memory.*`, `&reason.*` | Output from any capability in that domain |
| Literal types | `raw_data`, `stream_data`, `context` | Specific data shapes |
| Terminal | `output` | Pipeline result, no further steps |
| Acknowledgment | `ack` | Confirmation of a side-effecting operation |

---

## Wildcard Matching Rules

Wildcards match any subtype within a primitive domain:

| Pattern | Matches | Does Not Match |
|---------|---------|---------------|
| `&memory.*` | `&memory.graph`, `&memory.vector`, `&memory.episodic` | `&reason.argument`, `&time.anomaly` |
| `&reason.*` | `&reason.argument`, `&reason.deliberate`, `&reason.attend` | `&memory.graph` |
| `&time.*` | `&time.anomaly`, `&time.forecast` | `&space.fleet` |
| `&space.*` | `&space.fleet`, `&space.geofence` | `&memory.graph` |

A literal type like `"stream_data"` matches only itself — no wildcards.

---

## A2A Skill Mapping

The `a2a_skills` field maps capability operations to A2A skill identifiers:

```json
"a2a_skills": ["temporal-anomaly-detection"]
```

When generating an A2A agent card, these skill identifiers appear in the
agent's skill registry. This allows other agents to discover capabilities
via the A2A protocol.

Multiple skills per contract are permitted:

```json
"a2a_skills": [
  "topology-aware-deliberation",
  "knowledge-graph-reasoning"
]
```

---

## How Providers Satisfy Contracts

A provider satisfies a contract when:

1. It implements all operations listed in the contract
2. Each operation accepts the declared input type
3. Each operation produces the declared output type
4. The provider responds via MCP transport (stdio or HTTP)

The contract is a promise. The provider is the implementation. The protocol
validates the promise at composition time; the runtime enforces it at
execution time.

---

## Real Contract Examples

### `&memory.graph` (Graphonomous)

```json
{
  "capability": "&memory.graph",
  "operations": {
    "recall":   { "in": "query",   "out": "retrieval_result" },
    "store":    { "in": "context", "out": "ack" },
    "enrich":   { "in": "context", "out": "enriched_context" },
    "topology": { "in": "node_set", "out": "topology_result" }
  },
  "accepts_from": ["&time.*", "&space.*", "&reason.*", "query", "context"],
  "feeds_into": ["&reason.*", "&time.*", "&space.*", "output"]
}
```

### `&reason.deliberate` (Graphonomous)

```json
{
  "capability": "&reason.deliberate",
  "operations": {
    "deliberate": { "in": "topology_result", "out": "deliberation_result" },
    "decompose":  { "in": "topology_result", "out": "partitions" },
    "reconcile":  { "in": "intermediate_conclusions", "out": "deliberation_result" }
  },
  "accepts_from": ["&memory.graph", "&memory.*"],
  "feeds_into": ["&memory.graph", "&reason.*", "output"]
}
```

Full contracts are in `contracts/v0.1.0/` — one file per capability.

---

## Contract Versioning

Contracts use semver. When a provider changes its operations, types, or
compatibility:

- **Patch** (`0.1.1`): Bug fixes, no interface changes
- **Minor** (`0.2.0`): New operations added, existing operations unchanged
- **Major** (`1.0.0`): Breaking changes to existing operations or types

Declarations should pin contract versions to avoid unexpected breakage.
