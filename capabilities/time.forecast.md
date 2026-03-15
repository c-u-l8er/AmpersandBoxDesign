# `time.forecast` — Forecasting as a Capability

`time.forecast` is a capability page for the [&] Protocol's temporal forecasting subtype.

It describes a composable interface for agents that need to predict future state from historical or streaming temporal data. The goal is not to standardize one forecasting algorithm. The goal is to standardize how an agent declares, validates, and composes forecasting ability as part of its cognitive architecture.

In protocol terms:

- primitive: `&time`
- subtype: `forecast`
- full capability id: `&time.forecast`

---

## 1. Definition

`&time.forecast` is the protocol capability for **predictive temporal inference**.

It answers questions like:

- What is likely to happen next?
- How much demand should we expect over the next hour, day, or week?
- Which regions are likely to exceed capacity soon?
- What future load should a planner or reasoner prepare for?
- How confident is the system in its temporal prediction?

A provider that satisfies `&time.forecast` should expose operations that turn temporal data into forecast-oriented artifacts that downstream capabilities can consume.

This is distinct from:

- `&time.anomaly` — detecting unusual current or recent behavior
- `&time.pattern` — identifying recurring or structural behavior over time

`&time.forecast` is about **future-oriented estimation**.

---

## 2. Why this capability matters

A large class of useful agents need more than retrieval and reasoning over current context.

They need to anticipate:

- traffic spikes
- incident volume
- regional load
- staffing demand
- inventory or route pressure
- support queue growth
- resource exhaustion
- maintenance windows
- operational drift

Without an explicit forecasting capability, systems often hide predictive logic inside:

- custom analytics code
- prompts
- ad hoc tool wrappers
- vendor-specific integrations
- application business logic

That makes architectures hard to compare, validate, and reuse.

By treating forecasting as a protocol capability, the [&] Protocol makes it possible to:

- declare forecasting explicitly
- bind it to a provider
- validate pipelines that depend on forecast output
- preserve provenance for forecast-driven decisions
- generate downstream MCP and A2A artifacts from the same declaration

---

## 3. Capability role in the four-primitive model

The [&] Protocol organizes cognition around four top-level domains:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

Within that model, `&time.forecast` provides the agent's ability to project temporal context forward.

It often works best when composed with:

- `&memory.*` for historical evidence
- `&space.*` for region- or fleet-aware forecasting
- `&reason.*` for turning predictions into decisions

A useful shorthand is:

> `&time.forecast` tells the agent what future state is plausible enough to plan around.

---

## 4. Typical use cases

### Capacity planning
Forecast expected demand or load before thresholds are crossed.

### Staffing and support
Predict inbound ticket volume or call center load.

### Infrastructure operations
Estimate future CPU, memory, traffic, or storage pressure.

### Logistics and fleet management
Forecast regional fleet demand, route congestion, or service backlog.

### Maintenance and reliability
Project failure likelihood, incident volume, or wear-related workload windows.

### Research and trend monitoring
Predict likely changes in topic volume, signal growth, or event frequency.

---

## 5. Example declaration

A basic `ampersand.json` fragment using `&time.forecast`:

```json
{
  "&time.forecast": {
    "provider": "ticktickclock",
    "config": {
      "horizon_hours": 24,
      "granularity": "hourly",
      "targets": ["regional_demand", "support_volume"]
    }
  }
}
```

A goal-driven version using auto resolution:

```json
{
  "&time.forecast": {
    "provider": "auto",
    "need": "predict next-day support ticket demand by region"
  }
}
```

---

## 6. Compatible providers

The protocol is provider-agnostic. The capability is the contract; providers are implementations.

Representative providers for `&time.forecast` may include:

- `ticktickclock`
- Prophet-based forecasting services
- custom forecasting engines
- time-series platforms with predictive APIs
- domain-specific planning and prediction services

A provider should be considered compatible when it can satisfy the capability contract, not merely because it performs some predictive function in marketing language.

---

## 7. Example capability contract

A representative contract artifact for `&time.forecast`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/capability-contract.schema.json",
  "capability": "&time.forecast",
  "provider": "ticktickclock",
  "version": "0.1.0",
  "description": "Temporal forecasting contract for predicting near-term demand, load, and trend-driven state changes.",
  "operations": {
    "predict": {
      "in": "time_series",
      "out": "forecast_set",
      "description": "Generate a forecast over a requested horizon from historical or streaming temporal data.",
      "deterministic": false,
      "side_effects": false
    },
    "explain": {
      "in": "forecast_set",
      "out": "forecast_explanation",
      "description": "Return an explanation of forecast drivers, confidence, and major contributing signals.",
      "deterministic": false,
      "side_effects": false
    },
    "enrich": {
      "in": "context",
      "out": "enriched_context",
      "description": "Attach forecast-derived temporal context to an existing decision or planning payload.",
      "deterministic": false,
      "side_effects": false
    },
    "learn": {
      "in": "observation",
      "out": "ack",
      "description": "Incorporate realized outcomes for later calibration or model improvement.",
      "deterministic": false,
      "side_effects": true
    }
  },
  "accepts_from": [
    "&memory.*",
    "&space.*",
    "raw_data",
    "time_series",
    "context",
    "observation"
  ],
  "feeds_into": [
    "&reason.*",
    "&space.*",
    "&memory.*",
    "output"
  ],
  "a2a_skills": [
    "temporal-forecasting",
    "demand-prediction",
    "trend-explanation"
  ]
}
```

This contract matters because it makes forecasting composable in a typed system.

---

## 8. Example provider configuration patterns

The protocol does not hardcode one configuration shape, but these fields are common and useful.

### Horizon
How far forward to predict.

```json
{
  "horizon_hours": 24
}
```

### Granularity
How coarse or fine the forecast should be.

```json
{
  "granularity": "hourly"
}
```

### Targets
Which signals or domains are being forecast.

```json
{
  "targets": ["regional_demand", "support_volume"]
}
```

### Confidence threshold
Useful when forecast output should trigger escalation or downstream filtering.

```json
{
  "min_confidence": 0.7
}
```

### Region or segment scope
Useful for spatially-aware forecasts.

```json
{
  "regions": ["us-east", "eu-west"]
}
```

These are implementation patterns, not mandatory protocol fields.

---

## 9. Architecture patterns

### Pattern A: forecast -> reason
Use a forecast directly as decision input.

```text
time_series
|> &time.forecast.predict()
|> &reason.argument.evaluate()
```

Use when a forecast can directly support a decision, recommendation, or escalation.

### Pattern B: forecast -> space -> reason
Add region or fleet state before deciding.

```text
demand_history
|> &time.forecast.predict()
|> &space.fleet.enrich()
|> &reason.plan.evaluate()
```

Use when future demand must be interpreted in spatial context.

### Pattern C: memory -> forecast -> reason
Use historical memory before or alongside forecasting.

```text
query_context
|> &memory.graph.recall()
|> &time.forecast.enrich()
|> &reason.argument.evaluate()
```

Use when forecast interpretation benefits from prior incidents, structural memory, or analogous cases.

### Pattern D: forecast -> memory.learn
Use realized outcomes to improve future behavior.

```text
time_series
|> &time.forecast.predict()
|> &reason.argument.evaluate()
|> &memory.graph.learn()
```

Use when forecast-driven decisions should become part of durable organizational memory.

---

## 10. Architecture diagram

A simple conceptual view of `&time.forecast` in composition:

```text
historical data / stream data
            |
            v
   +----------------------+
   |   &time.forecast     |
   |  predict / explain   |
   +----------------------+
            |
            v
      forecast_set
            |
     +------+------+
     |             |
     v             v
&space.*       &reason.*
 enrich         evaluate
     |             |
     +------+------+
            |
            v
         output
```

This is why contract typing matters: downstream capabilities need to know what kind of artifact they are receiving.

---

## 11. Example API shape

A provider-specific API will vary, but a forecast provider commonly exposes a shape like:

```json
{
  "operation": "predict",
  "input": {
    "series": [
      { "timestamp": "2026-03-15T00:00:00Z", "value": 142 },
      { "timestamp": "2026-03-15T01:00:00Z", "value": 155 }
    ],
    "horizon_hours": 24,
    "granularity": "hourly"
  }
}
```

Representative response:

```json
{
  "forecast": [
    { "timestamp": "2026-03-16T00:00:00Z", "value": 181, "confidence": 0.83 },
    { "timestamp": "2026-03-16T01:00:00Z", "value": 187, "confidence": 0.81 }
  ],
  "summary": "Demand is likely to increase overnight with moderate confidence."
}
```

The protocol does not require this exact transport shape. It requires that the provider satisfy the declared capability contract.

---

## 12. Governance implications

Forecasts are often used to justify action before a situation fully materializes. That makes governance important.

Common governance examples for forecast-driven systems:

### Hard constraints
- never trigger irreversible action from a forecast alone
- never exceed regional scale limits without human approval
- never suppress audit logging for forecast-driven decisions

### Soft constraints
- prefer gradual changes over aggressive one-step responses
- prefer conservative capacity increases when forecast confidence is moderate
- prefer recent calibrated models over stale forecasting baselines

### Escalation rules
Forecast-heavy systems often combine well with:

```json
{
  "escalate_when": {
    "confidence_below": 0.7,
    "cost_exceeds_usd": 1000,
    "hard_boundary_approached": true
  }
}
```

This is one reason `&time.forecast` often composes closely with `&reason.argument` or `&reason.plan`.

---

## 13. Provenance implications

Forecasts can strongly influence planning, cost, and operational risk, so provenance should be explicit.

A provenance record for a forecasting step may include:

```json
{
  "source": "&time.forecast",
  "provider": "ticktickclock",
  "operation": "predict",
  "timestamp": "2026-03-15T12:00:00Z",
  "input_hash": "sha256:abcd1234...",
  "output_hash": "sha256:efgh5678...",
  "parent_hash": "sha256:0000...",
  "mcp_trace_id": "ttc-forecast-42"
}
```

This helps answer questions like:

- Why did the system scale this region?
- Which forecast provider influenced the decision?
- What horizon and confidence profile informed the action?
- Which upstream context produced this prediction?

Forecasts without provenance are difficult to audit and easy to over-trust.

---

## 14. A2A implications

A forecast capability may map naturally to A2A-advertised skills such as:

- `temporal-forecasting`
- `demand-prediction`
- `trend-explanation`

That means an agent card generated from an `ampersand.json` declaration can advertise forecasting as a reusable, discoverable coordination-facing skill.

This is one example of how the [&] Protocol complements A2A rather than replacing it.

---

## 15. MCP implications

A forecast provider may also compile into MCP-facing configuration if the implementation exposes a tool or service endpoint.

For example, a declaration containing `&time.forecast` may generate MCP configuration that wires in a forecasting provider alongside memory and reasoning providers.

This is one example of how the [&] Protocol complements MCP rather than replacing it.

---

## 16. Research references and grounding

The design of `&time.forecast` is informed by overlapping areas of work:

- time-series forecasting
- predictive analytics
- trend analysis
- operational forecasting
- demand planning
- sequence-aware decision systems
- temporal context in agent and planning architectures

The important protocol-level insight is not that forecasting is new. It is that **forecasting should be represented explicitly as a composable capability** rather than hidden in framework logic.

That shift enables:

- schema validation
- typed pipelines
- provider interchangeability
- governance-aware decisions
- provenance-preserving execution

---

## 17. Anti-patterns

### Anti-pattern 1: treat forecasting as generic analytics
If forecasting is bundled into a broad "analytics" block, its contract and pipeline role become unclear.

### Anti-pattern 2: treat forecast output as self-justifying
A forecast is often strong evidence, but not always enough for unsupervised action.

### Anti-pattern 3: conflate anomaly detection and forecasting
They are related temporal capabilities, but they are not the same interface.

### Anti-pattern 4: hardwire the protocol to one provider
`&time.forecast` should remain a portable capability contract.

---

## 18. Good default guidance

Use `&time.forecast` when:

- the system needs future-oriented temporal estimates
- a planner or reasoner must act on projected state
- demand, load, or trend pressure matters operationally
- a declaration should express predictive temporal intelligence explicitly

Prefer composing it with:

- `&space.*` when geography or regional state matters
- `&memory.*` when historical structure improves interpretation
- `&reason.*` when predictions influence action selection

---

## 19. Summary

`time.forecast` is the [&] Protocol capability for forecasting future temporal state.

It exists to make predictive temporal intelligence:

- explicit
- composable
- contract-aware
- provider-agnostic
- governable
- provenance-friendly
- generatable into MCP and A2A surfaces

In short:

> `&time.forecast` gives an agent a standard way to declare that it can project likely future state and use that projection safely within a composed cognitive system.