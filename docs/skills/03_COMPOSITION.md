# Skill 03 — Capability Composition

> How capabilities compose via the `&` operator and `|>` pipeline operator.
> ACI algebra properties, type compatibility, and composition validation.

---

## Why This Matters

Composition is the core thesis of the [&] Protocol. Individual capabilities
are useful; composed capabilities are powerful. The protocol defines two
operators that make composition formal, validated, and portable.

---

## The `&` Operator — Capability Sets

The `&` operator combines capabilities into a validated set. It is the
fundamental composition mechanism.

```
&memory.graph & &time.anomaly & &reason.argument
```

This declares an agent with graph memory, temporal anomaly detection, and
structured argumentation — composed as a single unit.

### ACI Properties

The `&` operator satisfies ACI (Associative, Commutative, Idempotent):

| Property | Meaning | Example |
|----------|---------|---------|
| **Associative** | Grouping does not matter | `(&memory & &time) & &space = &memory & (&time & &space)` |
| **Commutative** | Order does not matter | `&memory & &time = &time & &memory` |
| **Idempotent** | Duplicates collapse | `&memory & &memory = &memory` |
| **Identity** | Composing with nothing changes nothing | `&none & &memory = &memory` |

These are the same properties CRDTs use for conflict-free convergence. They
ensure capability sets are deterministic regardless of declaration order.

### Composition validation

When you run `ampersand compose`, the tool checks:

1. All capability identifiers are valid (`&primitive.subtype`)
2. All referenced providers exist in the registry (or are `"auto"`)
3. No conflicting providers for the same capability
4. ACI properties hold (duplicate removal, order normalization)

---

## The `|>` Operator — Pipelines

The `|>` operator flows data through capability operations in sequence:

```
stream_data
  |> &time.anomaly.detect()
  |> &memory.graph.enrich()
  |> &reason.argument.evaluate()
```

Each step receives the output of the previous step as input. The pipeline
is type-checked against capability contracts.

### Type Compatibility

Pipelines are validated using `accepts_from` / `feeds_into` contracts:

```
Step 1: &time.anomaly.detect()
  Input:  stream_data
  Output: anomaly_set

Step 2: &memory.graph.enrich()
  Accepts: anomaly_set (via &time.* wildcard in accepts_from)
  Output:  enriched_context

Step 3: &reason.argument.evaluate()
  Accepts: enriched_context (via &memory.* wildcard in accepts_from)
  Output:  evaluation_result
```

If Step N's output type does not match Step N+1's `accepts_from` list,
composition fails with a type error.

### Wildcard matching

Contract types support wildcard matching:

| Pattern | Matches |
|---------|---------|
| `&memory.*` | Any memory capability output |
| `&reason.*` | Any reasoning capability output |
| `raw_data` | Literal type `raw_data` |
| `output` | Terminal — pipeline result |

---

## Pipeline Declarations in JSON

Pipelines are declared in the `pipelines` block of `ampersand.json`:

```json
"pipelines": {
  "incident_triage": {
    "source_type": "stream_data",
    "source_ref": "raw_data",
    "steps": [
      { "capability": "&time.anomaly", "operation": "detect" },
      { "capability": "&memory.graph", "operation": "enrich" },
      { "capability": "&reason.argument", "operation": "evaluate" }
    ]
  }
}
```

Each step references a capability declared in the `capabilities` block and
an operation defined in that capability's contract.

---

## Multi-Capability Declarations

An agent can declare any combination of capabilities across all four
primitive domains:

```json
"capabilities": {
  "&memory.graph":      { "provider": "graphonomous", "config": {} },
  "&memory.vector":     { "provider": "pgvector", "config": {} },
  "&time.anomaly":      { "provider": "ticktickclock", "config": {} },
  "&time.forecast":     { "provider": "ticktickclock", "config": {} },
  "&space.fleet":       { "provider": "geofleetic", "config": {} },
  "&reason.argument":   { "provider": "deliberatic", "config": {} },
  "&reason.deliberate": { "provider": "graphonomous", "config": {} }
}
```

Multiple subtypes of the same primitive are allowed. Each is independently
bound to a provider.

---

## Composition Validation via CLI

```bash
./ampersand compose agent.ampersand.json
```

**Success output:**
```
OK  agent.ampersand.json
  Capability set: &memory.graph & &time.anomaly & &reason.argument
  ACI normal form: &memory.graph & &reason.argument & &time.anomaly
  Pipelines: incident_triage (3 steps, type-safe)
  Providers: graphonomous, ticktickclock, deliberatic
```

**Failure output:**
```
FAIL  agent.ampersand.json
  errors:
    - Pipeline "incident_triage" step 2: &memory.graph.enrich() does not
      accept type "forecast_set" (output of &time.forecast.predict())
    - Provider "unknown_service" not found in registry
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Incompatible pipeline steps | Output type does not match next step's `accepts_from` | Check contracts; insert a compatible intermediary |
| Circular pipeline dependencies | `|>` is strictly linear | Use capability-level feedback, not pipeline cycles |
| Composing without validating | Errors surface late at generation time | Always `compose` before `generate` |
| Ignoring ACI normalization | Assuming order matters when it does not | Trust the normal form; do not rely on declaration order |
| Over-composing | Declaring 15 capabilities when 3 suffice | Start minimal; add capabilities when needed |

---

## Elixir DSL Equivalent

In the Elixir reference implementation, composition uses native syntax:

```elixir
capabilities do
  &memory.graph(:graphonomous, instance: "infra-ops")
  &time.anomaly(:ticktickclock, streams: [:cpu, :mem])
  &reason.argument(:deliberatic, governance: :constitutional)
end
```

Pipeline usage:

```elixir
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &reason.argument.evaluate()
```

The `&` leverages Elixir's capture operator. The `|>` is Elixir's native
pipe. Both map directly to the protocol's formal operators.
