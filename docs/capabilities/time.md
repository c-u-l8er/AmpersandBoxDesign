# `&time`: Temporal Intelligence in the [&] Protocol

`&time` is the temporal capability domain in the [&] Protocol.

It answers questions like:

- **When** is something changing?
- **What** pattern is emerging over time?
- **Which** anomalies matter now?
- **How** should past trends influence present decisions?
- **What** forecast should a downstream reasoning or planning system act on?

In practical agent systems, temporal intelligence is often the difference between a system that merely retrieves facts and a system that can detect drift, anticipate change, and respond before a problem becomes obvious.

---

## Why `&time` exists

Many agent stacks treat time as an implementation detail:

- timestamps in a database
- ordering in an event stream
- time windows in analytics code
- recency weighting in retrieval

That is not enough.

Temporal capability deserves its own protocol domain because it affects:

- anomaly detection
- forecasting
- trend and seasonality analysis
- event sequencing
- recency-aware decision making
- SLA and threshold monitoring
- incident detection
- demand planning
- maintenance scheduling

A protocol that can declare memory and reasoning but cannot declare temporal intelligence is incomplete for real-world operations, logistics, finance, research, and support workflows.

---

## What `&time` represents

`&time` is the protocol primitive for **temporal perception and temporal inference**.

At a high level, it covers systems that can:

- inspect time series
- detect temporal anomalies
- identify patterns across time windows
- generate forecasts or predictions
- summarize change over time
- enrich other capabilities with time-based context

It is intentionally broad at the primitive level and more specific at the subtype level.

---

## Common `&time` subtypes

The current protocol direction includes these representative subtypes:

### `&time.anomaly`

Detect unusual changes, outliers, spikes, dips, or drift in time-oriented data.

Typical use cases:

- CPU or memory anomaly detection
- fraud spikes
- support volume surges
- unusual route delays
- abnormal sensor readings

### `&time.forecast`

Predict likely future values or states from historical data.

Typical use cases:

- demand forecasting
- load prediction
- staffing forecasts
- expected incident volume
- route or delivery timing estimates

### `&time.pattern`

Recognize recurring temporal structure, seasonality, trends, bursts, or operating rhythms.

Typical use cases:

- weekly support cycles
- business-hour traffic patterns
- recurring maintenance windows
- periodic usage peaks
- long-term trend analysis

These are not the only possible temporal subtypes, but they are a strong starting namespace.

---

## Temporal intelligence in cognitive terms

A useful way to think about the four protocol primitives is:

- `&memory` → what the agent knows
- `&reason` → how the agent decides
- `&time` → when things happen
- `&space` → where things happen

`&time` gives the agent a sense of:

- **sequence**
- **change**
- **rhythm**
- **recurrence**
- **prediction**
- **urgency**

Without it, many agents behave as if the world were static.

---

## Why temporal capability should be explicit

Making temporal capability explicit gives you four important benefits.

### 1. Better architecture clarity

You can distinguish:

- a memory-heavy agent
- a reasoning-heavy agent
- a temporally aware agent

instead of collapsing them all into a vague “smart agent” label.

### 2. Better compatibility checks

A pipeline can validate whether a temporal capability outputs a type that downstream capabilities understand.

Example:

- `&time.anomaly.detect()` → `anomaly_set`
- `&memory.graph.enrich()` expects `anomaly_set`

That compatibility is checkable.

### 3. Better provider interchangeability

`&time.anomaly` is an interface.
A provider like `ticktickclock` is an implementation.

That means another provider could satisfy the same capability later if it honors the same contract.

### 4. Better downstream generation

A declaration that includes `&time.*` can compile into:

- MCP config for a temporal provider
- A2A skills that advertise forecasting or anomaly detection capability
- runtime policy and provenance expectations

---

## Example provider mappings

The protocol is provider-agnostic, but representative mappings are useful.

### `&time.anomaly`

Possible providers:

- `ticktickclock`
- InfluxDB-backed anomaly services
- custom temporal analytics services

### `&time.forecast`

Possible providers:

- `ticktickclock`
- Prophet-backed services
- custom forecasting systems

### `&time.pattern`

Possible providers:

- `ticktickclock`
- custom temporal pattern systems
- analytics engines with seasonality or trend support

The important distinction is:

- capability = protocol contract
- provider = implementation that satisfies that contract

---

## Temporal architecture patterns

`&time` is rarely used alone. It usually becomes most valuable when composed with the other primitives.

### Pattern 1: time + memory

Use temporal signals to retrieve or enrich historical context.

Example:

- detect anomaly
- recall similar prior incidents
- compare current spike against past spikes

Composition shape:

- `&time.anomaly`
- `&memory.graph`

### Pattern 2: time + reason

Use forecasts or temporal patterns to drive a decision policy.

Example:

- forecast demand
- decide staffing or scaling plan
- escalate if confidence is low

Composition shape:

- `&time.forecast`
- `&reason.argument`

### Pattern 3: time + space

Use temporal intelligence to localize change across regions or fleets.

Example:

- detect route delays over time
- identify which regions are drifting from expected behavior

Composition shape:

- `&time.pattern`
- `&space.fleet`

### Pattern 4: time + memory + reason

This is one of the most useful real-world patterns.

Example:

- anomaly detection produces `anomaly_set`
- memory recalls similar historical situations
- reasoning evaluates likely responses

Composition shape:

- `&time.anomaly`
- `&memory.graph`
- `&reason.argument`

### Pattern 5: time + space + reason

Useful when a system must choose actions based on both temporal signals and spatial state.

Example:

- predict regional demand surge
- inspect region capacity
- choose reallocation strategy

Composition shape:

- `&time.forecast`
- `&space.fleet`
- `&reason.plan`

---

## Protocol declaration examples

### Explicit provider binding

A direct binding to a known temporal provider:

```json
{
  "&time.anomaly": {
    "provider": "ticktickclock",
    "config": {
      "streams": ["cpu", "mem"],
      "window_minutes": 5
    }
  }
}
```

### Auto provider resolution

A declaration that leaves provider choice to the registry/runtime:

```json
{
  "&time.forecast": {
    "provider": "auto",
    "need": "predict next-day support ticket volume"
  }
}
```

This is useful when the requirement matters more than the specific implementation.

---

## Example `&time` contract

A representative temporal anomaly contract might look like this:

```json
{
  "capability": "&time.anomaly",
  "operations": {
    "detect": {
      "in": "stream_data",
      "out": "anomaly_set"
    },
    "enrich": {
      "in": "context",
      "out": "enriched_context"
    },
    "learn": {
      "in": "observation",
      "out": "ack"
    }
  },
  "accepts_from": ["&memory.*", "&space.*", "raw_data"],
  "feeds_into": ["&memory.*", "&reason.*", "&space.*", "output"],
  "a2a_skills": ["temporal-anomaly-detection"]
}
```

This matters because it makes temporal behavior machine-checkable rather than purely descriptive.

---

## Primitive-specific schema shape

Within `ampersand.json`, a temporal capability appears under `capabilities` as a standard capability binding.

Representative shape:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "InfraOperator",
  "version": "1.0.0",
  "capabilities": {
    "&time.anomaly": {
      "provider": "ticktickclock",
      "config": {
        "streams": ["cpu", "mem"],
        "window_minutes": 5
      }
    }
  },
  "provenance": true
}
```

Important rules inherited from the canonical schema:

- capability key must match the `&time.<subtype>` pattern
- `provider` is required
- `config` is optional
- if `provider` is `"auto"`, `need` is required
- the capability declaration remains provider-agnostic at the protocol level

---

## Recommended config patterns for `&time`

Because provider config is implementation-specific, the protocol does not hardcode one exact config object.
Still, a few patterns are useful to keep consistent.

### Stream selection

Useful for anomaly detection:

```json
{
  "streams": ["cpu", "mem", "latency"]
}
```

### Time windows

Useful for anomaly, pattern, and forecast models:

```json
{
  "window_minutes": 5,
  "lookback_days": 30
}
```

### Granularity

Useful when pattern or forecast systems must know the temporal resolution:

```json
{
  "granularity": "hourly"
}
```

### Horizon

Useful for forecast systems:

```json
{
  "horizon_hours": 24
}
```

These are not protocol-required keys; they are common implementation patterns.

---

## Example pipelines using `&time`

### Pipeline A: anomaly detection → memory enrichment → reasoning

Use case: infrastructure incident response

```text
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &reason.argument.evaluate()
```

Interpretation:

1. temporal capability detects anomalies in incoming stream data
2. memory capability enriches with similar historical incidents
3. reasoning capability evaluates what action to take

### Pipeline B: forecasting → spatial enrichment → planning

Use case: fleet or regional capacity planning

```text
demand_history
|> &time.forecast.predict()
|> &space.fleet.enrich()
|> &reason.plan.evaluate()
```

Interpretation:

1. temporal capability predicts future demand
2. spatial capability adds regional or fleet capacity context
3. reasoning/planning capability determines the action plan

### Pipeline C: pattern detection → memory learning

Use case: support operations trend learning

```text
ticket_history
|> &time.pattern.detect()
|> &memory.episodic.learn()
```

Interpretation:

1. temporal capability finds recurring support patterns
2. memory stores those findings for future use

---

## Temporal provenance

Temporal capability is especially important for provenance because time-based claims can strongly influence downstream action.

When `provenance` is enabled, a temporal step should preserve context like:

- source capability: `&time.anomaly`
- provider: `ticktickclock`
- operation: `detect`
- timestamp
- input hash
- output hash
- parent hash
- optional runtime trace id

Representative record:

```json
{
  "source": "&time.anomaly",
  "provider": "ticktickclock",
  "operation": "detect",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:a3f8...",
  "output_hash": "sha256:7b2c...",
  "parent_hash": "sha256:0000...",
  "mcp_trace_id": "ttc-inv-9f3a..."
}
```

This matters because temporal outputs often trigger urgency-sensitive decisions.

---

## Governance considerations for `&time`

Temporal capabilities are often tightly connected to automation and escalation, so governance matters.

Common governance patterns include:

### Hard constraints

Examples:

- never auto-scale beyond a fixed threshold from one anomaly signal alone
- never approve a refund or shutdown solely from a forecast without corroboration
- never suppress anomaly alerts without preserving an audit trail

### Soft constraints

Examples:

- prefer recent evidence over stale signals
- prefer gradual responses to short-lived spikes
- prefer seasonal baselines when available

### Escalation triggers

Examples:

- `confidence_below`
- `cost_exceeds_usd`
- `hard_boundary_approached`

This is one reason `&time` often composes closely with `&reason`: the temporal signal is not always the decision itself.

---

## Research grounding

Temporal intelligence in agents draws support from several overlapping research and systems traditions:

- time-series analysis
- anomaly detection
- forecasting systems
- temporal pattern mining
- sequence modeling
- operations monitoring and observability
- event-driven systems
- recency-aware retrieval and decision making

At the protocol level, the important insight is not that time-series analysis is new.
It is that **temporal capability should be represented explicitly as part of agent composition**.

That shift matters because it makes the architecture:

- visible
- testable
- composable
- provider-agnostic
- suitable for downstream generation

---

## Anti-patterns

A few anti-patterns are worth avoiding when modeling `&time`.

### Anti-pattern 1: treat time as only metadata

If timestamps exist but no temporal capability exists, the system may still be unable to detect pattern, anomaly, or forecast behavior.

### Anti-pattern 2: collapse all temporal functions into one opaque “analytics” block

This makes it hard to distinguish anomaly detection from forecasting or recurring-pattern detection.

### Anti-pattern 3: let temporal output bypass governance

A strong anomaly signal is still not always enough for unsupervised action.

### Anti-pattern 4: couple the protocol directly to one provider

`&time.anomaly` should not mean “ticktickclock and nothing else.”

---

## Practical implementation guidance

If you are implementing `&time` in a runtime or SDK, a good minimum approach is:

1. support a small subtype set first
   - `anomaly`
   - `forecast`
   - `pattern`

2. define explicit contracts for each subtype

3. validate pipeline compatibility with downstream capabilities

4. preserve provenance by default where possible

5. keep provider config flexible and provider-specific

6. avoid inventing runtime details for unknown providers

---

## Good first examples for `&time`

If you are adding more example declarations or demos, strong `&time` scenarios include:

- infrastructure anomaly response
- support demand forecasting
- fleet delay prediction
- recurring incident pattern detection
- fraud spike detection
- equipment maintenance forecasting

These make the value of temporal capability obvious very quickly.

---

## Summary

`&time` is the protocol’s temporal intelligence domain.

It exists because many useful agents need more than memory and reasoning alone. They need to understand change across time.

At the protocol level, `&time` gives you a way to declare and validate capabilities like:

- anomaly detection
- forecasting
- temporal pattern recognition

At the architectural level, it composes especially well with:

- `&memory` for historical context
- `&reason` for decision making
- `&space` for regional or fleet-aware interpretation

At the implementation level, it enables:

- clearer agent design
- typed compatibility checks
- provenance-friendly execution
- generation into downstream MCP and A2A artifacts

In short:

> `&time` is how the [&] Protocol makes temporal intelligence explicit.
