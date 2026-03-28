# Skill 01 — Writing Agent Declarations

> How to write `ampersand.json` files that declare an agent's capabilities,
> governance, and provenance requirements.

---

## Why This Matters

The `ampersand.json` declaration is the source of truth for what an agent can do.
Everything else — validation, composition, MCP/A2A generation — flows from this
file. Get the declaration right and the rest follows.

---

## Basic Structure

Every declaration has these top-level fields:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "AgentName",
  "version": "1.0.0",
  "capabilities": { ... },
  "governance": { ... },
  "provenance": true
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `$schema` | Recommended | Points to the JSON Schema for validation |
| `agent` | Yes | Agent identifier (PascalCase by convention) |
| `version` | Yes | Semver version string |
| `capabilities` | Yes | Map of capability identifiers to provider configs |
| `governance` | No | Hard/soft constraints, escalation rules, autonomy |
| `pipelines` | No | Named data-flow pipelines through capabilities |
| `provenance` | No | Boolean — enable hash-linked provenance chain |

---

## Capability Identifier Patterns

Capabilities follow the pattern `&primitive.subtype`:

```
&memory.graph        — graph-structured persistent memory
&memory.vector       — vector similarity search
&memory.episodic     — event-based recall
&reason.argument     — structured argumentation
&reason.deliberate   — topology-aware focused reasoning
&reason.attend       — proactive attention engine
&time.anomaly        — temporal anomaly detection
&time.forecast       — time-series prediction
&space.fleet         — fleet-wide spatial awareness
&space.geofence      — geographic boundary management
```

Custom subtypes are permitted if they satisfy the primitive's capability contract.

---

## Provider Binding

Each capability declares a provider — the service that implements it:

**Explicit provider:**
```json
"&memory.graph": {
  "provider": "graphonomous",
  "config": { "instance": "infra-ops" }
}
```

**Auto-resolved provider:**
```json
"&memory.vector": {
  "provider": "auto",
  "config": { "index": "documents" }
}
```

When `provider` is `"auto"`, the runtime resolves the provider from the
capability registry at composition time.

---

## Config Objects

The `config` object is provider-specific. It passes through to the provider
at bind time. Common patterns:

| Provider | Typical Config |
|----------|---------------|
| `graphonomous` | `instance`, `budget` |
| `ticktickclock` | `streams`, `window_days`, `granularity` |
| `geofleetic` | `regions`, `precision` |
| `deliberatic` | `governance`, `mode` |

The schema does not constrain `config` contents — that is the provider's
responsibility via its capability contract.

---

## Working Examples

### Minimal declaration (single capability)

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "SimpleMemoryAgent",
  "version": "0.1.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "graphonomous",
      "config": {}
    }
  }
}
```

### Research agent (three capabilities, governance)

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "ResearchAgent",
  "version": "0.1.0",
  "capabilities": {
    "&memory.vector": {
      "provider": "pgvector",
      "config": { "index": "papers", "namespace": "research-corpus" }
    },
    "&time.pattern": {
      "provider": "ticktickclock",
      "config": { "window_days": 30, "granularity": "daily" }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": { "governance": "evidence-first" }
    }
  },
  "governance": {
    "hard": ["Never present unsupported conclusions as facts"],
    "soft": ["Prefer recent peer-reviewed evidence"],
    "escalate_when": { "confidence_below": 0.65 }
  },
  "provenance": true
}
```

### Full infrastructure agent (six capabilities, pipelines, governance)

See `examples/infra-operator.ampersand.json` for the complete InfraOperator
declaration with `&memory.graph`, `&time.anomaly`, `&space.fleet`,
`&reason.argument`, `&reason.deliberate`, `&reason.attend`, plus a named
`incident_triage` pipeline and full governance block.

---

## Governance Block

The `governance` object declares constraints the agent must respect:

```json
"governance": {
  "hard": ["Never scale beyond 3x in a single action"],
  "soft": ["Prefer gradual scaling over spikes"],
  "escalate_when": {
    "confidence_below": 0.7,
    "cost_exceeds_usd": 1000
  },
  "autonomy": {
    "level": "advise",
    "model_tier": "local_small",
    "heartbeat_seconds": 300,
    "budget": {
      "max_actions_per_hour": 5,
      "require_approval_for": ["act", "propose"]
    }
  }
}
```

See `09_GOVERNANCE_PROVENANCE.md` for full governance documentation.

---

## Common Mistakes

| Mistake | Why It Fails | Fix |
|---------|-------------|-----|
| Missing `agent` field | Schema validation rejects it | Always include agent name |
| Using bare primitives (`&memory`) | Subtypes are required in declarations | Use `&memory.graph`, `&memory.vector`, etc. |
| Omitting `provider` | Runtime cannot bind the capability | Specify a provider or use `"auto"` |
| Putting pipeline logic in capabilities | Capabilities declare what, not how | Use the `pipelines` block for data flow |
| Duplicating capability keys | JSON keys must be unique | Each `&primitive.subtype` appears once |
| Non-semver version strings | Schema requires semver | Use `"1.0.0"`, not `"v1"` or `"latest"` |
