# `&time.anomaly` — Anomaly Detection as a Capability

`&time.anomaly` is a capability page for the [&] Protocol's temporal anomaly detection subtype.

It describes a composable interface for agents that need to detect unusual behavior in streaming or historical temporal signals. The goal is not to standardize one anomaly detection algorithm. The goal is to standardize how an agent declares, validates, and composes anomaly detection ability as part of its cognitive architecture.

In protocol terms:

- primitive: `&time`
- subtype: `anomaly`
- full capability id: `&time.anomaly`

---

## 1. Definition

`&time.anomaly` is the protocol capability for **temporal anomaly detection**.

It answers questions like:

- Is something unusual happening right now?
- Did a metric spike, drop, or drift outside expected behavior?
- Which signals are deviating from their historical norms?
- When did this anomalous behavior begin, and is it still active?
- How severe is this deviation relative to the system's baseline?

A provider that satisfies `&time.anomaly` should expose operations that turn temporal data into anomaly-oriented artifacts that downstream capabilities can consume.

This is distinct from:

- `&time.forecast` — predicting likely future values
- `&time.pattern` — identifying recurring or structural behavior over time

`&time.anomaly` is about **detecting deviations from expected present or past behavior**.

---

## 2. Why this capability matters

A large class of useful agents need more than prediction and pattern recognition over temporal signals.

They need to detect:

- infrastructure metric spikes
- sudden drops in throughput or availability
- unusual error rate behavior
- support volume surges
- regional demand anomalies
- fleet telemetry deviations
- latency drift
- capacity threshold breaches
- unexpected changes in operational cadence

Without an explicit anomaly detection capability, systems often hide detection logic inside:

- custom monitoring code
- static threshold alerts
- vendor-specific observability platforms
- ad hoc rule engines
- application-layer heuristics

That makes architectures hard to compare, validate, and reuse.

By treating anomaly detection as a protocol capability, the [&] Protocol makes it possible to:

- declare anomaly detection explicitly
- bind it to a provider
- validate pipelines that depend on anomaly output
- preserve provenance for anomaly-driven decisions
- generate downstream MCP and A2A artifacts from the same declaration

---

## 3. Capability role in the four-primitive model

The [&] Protocol organizes cognition around four top-level domains:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

Within that model, `&time.anomaly` provides the agent's ability to surface unexpected deviations in temporal context.

It often works best when composed with:

- `&memory.*` for historical baselines and incident context
- `&space.*` for region- or fleet-aware anomaly scoping
- `&reason.*` for turning detected anomalies into decisions or escalations

A useful shorthand is:

> `&time.anomaly` tells the agent that something unexpected is happening and provides structured context about the deviation.

---

## 4. Typical use cases

### Infrastructure incident detection
Surface anomalous CPU, memory, latency, or error rate behavior before static thresholds fire.

### Support volume spike detection
Detect unexpected surges in inbound support requests or ticket creation rates.

### Regional demand anomaly
Identify unusual demand patterns in specific geographic regions or market segments.

### Fleet telemetry anomaly
Detect deviations in vehicle, device, or node telemetry across a managed fleet.

### Operational drift detection
Surface gradual shifts in throughput, response time, or error distribution that indicate systemic change.

### Incident correlation
Provide anomaly context that downstream reasoning capabilities can use to correlate related events across signals.

---

## 5. Example declaration

A basic `ampersand.json` fragment using `&time.anomaly`:

```json
{
  "&time.anomaly": {
    "provider": "ticktickclock",
    "config": {
      "streams": ["cpu", "mem"],
      "sensitivity": "medium",
      "window_minutes": 15
    }
  }
}
```

A goal-driven version using auto resolution:

```json
{
  "&time.anomaly": {
    "provider": "auto",
    "need": "detect unusual latency or error rate behavior in production infrastructure"
  }
}
```

---

## 6. Compatible providers

The protocol is provider-agnostic. The capability is the contract; providers are implementations.

Representative providers for `&time.anomaly` may include:

- `ticktickclock`
- statistical anomaly detection services
- custom detection engines
- time-series platforms with anomaly detection APIs
- domain-specific monitoring and observability services

A provider should be considered compatible when it can satisfy the capability contract, not merely because it performs some anomaly-adjacent function in marketing language.

---

## 7. Example capability contract

A representative contract artifact for `&time.anomaly`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&time.anomaly",
  "provider": "ticktickclock",
  "version": "0.1.0",
  "description": "Temporal anomaly detection contract for surfacing unusual behavior in streaming or historical signals and enriching downstream decision context.",
  "operations": {
    "detect": {
      "in": "stream_data",
      "out": "anomaly_set",
      "description": "Detect anomalous events, spikes, drops, or drift from temporal input signals.",
      "deterministic": false,
      "side_effects": false
    },
    "enrich": {
      "in": "context",
      "out": "enriched_context",
      "description": "Attach anomaly-derived temporal context to an existing payload for downstream reasoning or routing.",
      "deterministic": false,
      "side_effects": false
    },
    "learn": {
      "in": "observation",
      "out": "ack",
      "description": "Incorporate confirmed outcomes or operator feedback to improve later anomaly detection behavior.",
      "deterministic": false,
      "side_effects": true
    }
  },
  "accepts_from": [
    "&memory.*",
    "&space.*",
    "raw_data",
    "stream_data",
    "context",
    "observation"
  ],
  "feeds_into": [
    "&memory.*",
    "&reason.*",
    "&space.*",
    "output"
  ],
  "a2a_skills": [
    "temporal-anomaly-detection"
  ]
}
```

This contract matters because it makes anomaly detection composable in a typed system.

---

## 8. Example provider configuration patterns

The protocol does not hardcode one configuration shape, but these fields are common and useful.

### Streams
Which signals to monitor for anomalies.

```json
{
  "streams": ["cpu", "mem", "latency", "error_rate", "throughput"]
}
```

### Sensitivity
How aggressively to flag deviations.

```json
{
  "sensitivity": "medium"
}
```

### Window
How much recent history to consider when determining baseline behavior.

```json
{
  "window_minutes": 15
}
```

### Confidence threshold
Useful when anomaly output should trigger escalation or downstream filtering.

```json
{
  "min_confidence": 0.7
}
```

### Region or segment scope
Useful for spatially-aware anomaly detection.

```json
{
  "regions": ["us-east", "eu-west"]
}
```

These are implementation patterns, not mandatory protocol fields.

---

## 9. Architecture patterns

### Pattern A: detect -> reason
Use a detected anomaly directly as decision input.

```text
stream_data
|> &time.anomaly.detect()
|> &reason.argument.evaluate()
```

Use when an anomaly can directly support a decision, escalation, or incident response action.

### Pattern B: detect -> enrich -> reason
Attach anomaly context to graph memory before deciding.

```text
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &reason.argument.evaluate()
```

Use when anomaly context should be enriched with historical incidents or structural memory before a decision is made. This is the core anomaly enrichment pipeline.

### Pattern C: detect -> space -> reason
Add region or fleet state before deciding.

```text
fleet_telemetry
|> &time.anomaly.detect()
|> &space.fleet.enrich()
|> &reason.plan.evaluate()
```

Use when anomalies must be interpreted in spatial context, such as regional infrastructure or fleet-level behavior.

### Pattern D: memory -> detect -> reason
Use historical memory alongside anomaly detection.

```text
query_context
|> &memory.graph.recall()
|> &time.anomaly.enrich()
|> &reason.argument.evaluate()
```

Use when anomaly interpretation benefits from prior incidents, known failure modes, or analogous cases.

### Pattern E: detect -> memory.learn
Use confirmed outcomes to improve future detection.

```text
stream_data
|> &time.anomaly.detect()
|> &reason.argument.evaluate()
|> &memory.graph.learn()
```

Use when anomaly-driven decisions should become part of durable organizational memory and future detection baselines.

---

## 10. Architecture diagram

A simple conceptual view of `&time.anomaly` in composition:

```text
streaming data / historical signals
            |
            v
   +----------------------+
   |   &time.anomaly      |
   |  detect / enrich     |
   +----------------------+
            |
            v
       anomaly_set
            |
     +------+------+
     |             |
     v             v
&memory.*      &reason.*
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

A provider-specific API will vary, but an anomaly detection provider commonly exposes a shape like:

```json
{
  "operation": "detect",
  "input": {
    "stream": "cpu",
    "data": [
      { "timestamp": "2026-03-15T00:00:00Z", "value": 42.1 },
      { "timestamp": "2026-03-15T00:01:00Z", "value": 43.7 },
      { "timestamp": "2026-03-15T00:02:00Z", "value": 91.3 }
    ],
    "window_minutes": 15,
    "sensitivity": "medium"
  }
}
```

Representative response:

```json
{
  "anomalies": [
    {
      "timestamp": "2026-03-15T00:02:00Z",
      "stream": "cpu",
      "type": "spike",
      "severity": "high",
      "value": 91.3,
      "baseline": 43.0,
      "confidence": 0.92
    }
  ],
  "summary": "CPU spike detected at 00:02 — value 91.3 vs baseline 43.0."
}
```

The protocol does not require this exact transport shape. It requires that the provider satisfy the declared capability contract.

---

## 12. Governance implications

Anomalies are often used to trigger automated responses before a human fully reviews the situation. That makes governance important.

Common governance examples for anomaly-driven systems:

### Hard constraints
- never trigger irreversible action from a single anomaly detection alone
- never suppress audit logging for anomaly-driven responses
- never escalate to external systems without provenance attached

### Soft constraints
- prefer investigation over immediate remediation when confidence is moderate
- prefer correlating multiple signals before triggering high-severity responses
- prefer recent baselines over stale detection models

### Escalation rules
Anomaly-heavy systems often combine well with:

```json
{
  "escalate_when": {
    "confidence_below": 0.7,
    "severity_above": "high",
    "correlated_anomalies_exceed": 3,
    "hard_boundary_approached": true
  }
}
```

This is one reason `&time.anomaly` often composes closely with `&reason.argument` or `&reason.plan`.

---

## 13. Provenance implications

Anomalies can trigger automated incident response, scaling decisions, and operational escalations, so provenance should be explicit.

A provenance record for an anomaly detection step may include:

```json
{
  "source": "&time.anomaly",
  "provider": "ticktickclock",
  "operation": "detect",
  "timestamp": "2026-03-15T12:00:00Z",
  "input_hash": "sha256:abcd1234...",
  "output_hash": "sha256:efgh5678...",
  "parent_hash": "sha256:0000...",
  "mcp_trace_id": "ttc-anomaly-17"
}
```

This helps answer questions like:

- Why did the system trigger an incident response?
- Which anomaly provider flagged the deviation?
- What detection window and confidence profile informed the action?
- Which upstream signals produced this anomaly event?

Anomalies without provenance are difficult to audit and easy to over-trust.

---

## 14. A2A implications

An anomaly detection capability may map naturally to A2A-advertised skills such as:

- `temporal-anomaly-detection`

That means an agent card generated from an `ampersand.json` declaration can advertise anomaly detection as a reusable, discoverable coordination-facing skill.

This is one example of how the [&] Protocol complements A2A rather than replacing it.

---

## 15. MCP implications

An anomaly detection provider may also compile into MCP-facing configuration if the implementation exposes a tool or service endpoint.

For example, a declaration containing `&time.anomaly` may generate MCP configuration that wires in an anomaly detection provider alongside memory and reasoning providers.

This is one example of how the [&] Protocol complements MCP rather than replacing it.

---

## 16. Research references and grounding

The design of `&time.anomaly` is informed by overlapping areas of work:

- statistical anomaly detection
- time-series outlier identification
- change-point detection
- operational monitoring and observability
- streaming event detection
- drift detection in production systems
- temporal context in agent and planning architectures

The important protocol-level insight is not that anomaly detection is new. It is that **anomaly detection should be represented explicitly as a composable capability** rather than hidden in monitoring infrastructure.

That shift enables:

- schema validation
- typed pipelines
- provider interchangeability
- governance-aware responses
- provenance-preserving execution

---

## 17. Anti-patterns

### Anti-pattern 1: treat anomaly detection as generic alerting
If anomaly detection is bundled into a broad "alerting" or "monitoring" block, its contract and pipeline role become unclear.

### Anti-pattern 2: treat anomaly output as self-justifying
An anomaly is strong evidence that something unusual occurred, but not always enough for unsupervised remediation.

### Anti-pattern 3: conflate forecasting and anomaly detection
They are related temporal capabilities, but they are not the same interface. Forecasting predicts future values. Anomaly detection surfaces unexpected present or past values.

### Anti-pattern 4: conflate pattern recognition and anomaly detection
Pattern recognition identifies recurring structures such as seasonality or cycles. Anomaly detection identifies deviations from expected behavior.

### Anti-pattern 5: hardwire the protocol to one provider
`&time.anomaly` should remain a portable capability contract.

---

## 18. Good default guidance

Use `&time.anomaly` when:

- the system needs to detect unexpected deviations in temporal signals
- an incident response or escalation pipeline depends on anomaly context
- infrastructure, fleet, or operational metrics require continuous monitoring for unusual behavior
- a declaration should express temporal anomaly detection intelligence explicitly

Prefer composing it with:

- `&memory.*` when historical baselines or prior incident context improves interpretation
- `&space.*` when geography, fleet position, or regional state matters
- `&reason.*` when anomalies influence action selection, escalation, or remediation

---

## 19. Summary

`&time.anomaly` is the [&] Protocol capability for detecting temporal anomalies.

It exists to make temporal anomaly detection:

- explicit
- composable
- contract-aware
- provider-agnostic
- governable
- provenance-friendly
- generatable into MCP and A2A surfaces

In short:

> `&time.anomaly` gives an agent a standard way to declare that it can detect unexpected deviations in temporal signals and use that detection safely within a composed cognitive system.
