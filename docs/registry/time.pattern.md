# `&time.pattern` — Pattern Detection as a Capability

`&time.pattern` is a capability page for the [&] Protocol's temporal pattern detection subtype.

It describes a composable interface for agents that need to identify recurring temporal structures in historical or streaming data. The goal is not to standardize one pattern detection algorithm. The goal is to standardize how an agent declares, validates, and composes pattern detection ability as part of its cognitive architecture.

In protocol terms:

- primitive: `&time`
- subtype: `pattern`
- full capability id: `&time.pattern`

---

## 1. Definition

`&time.pattern` is the protocol capability for **temporal structure identification**.

It answers questions like:

- What recurring behaviors exist in this data?
- Is there a weekly or seasonal cycle driving this signal?
- Which motifs repeat across different time windows?
- How strong and stable is the detected periodicity?
- What rhythm characterizes the operational baseline?

A provider that satisfies `&time.pattern` should expose operations that turn temporal data into pattern-oriented artifacts that downstream capabilities can consume.

This is distinct from:

- `&time.anomaly` — detecting what is unusual in current or recent behavior
- `&time.forecast` — predicting what is likely to happen next

`&time.pattern` is about **identifying what recurs**.

---

## 2. Why this capability matters

A large class of useful agents need more than retrieval and reasoning over current context.

They need to recognize structure:

- support ticket seasonality
- recurring incident patterns
- demand rhythms
- research trend cycles
- periodic load spikes
- weekly or monthly behavioral shifts
- recurring failure modes
- staffing demand cadence
- cyclical resource consumption

Without an explicit pattern detection capability, systems often hide structural temporal logic inside:

- custom analytics code
- prompts
- ad hoc tool wrappers
- vendor-specific integrations
- application business logic

That makes architectures hard to compare, validate, and reuse.

By treating pattern detection as a protocol capability, the [&] Protocol makes it possible to:

- declare pattern detection explicitly
- bind it to a provider
- validate pipelines that depend on pattern output
- preserve provenance for pattern-driven decisions
- generate downstream MCP and A2A artifacts from the same declaration

---

## 3. Capability role in the four-primitive model

The [&] Protocol organizes cognition around four top-level domains:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

Within that model, `&time.pattern` provides the agent's ability to recognize recurring temporal structure in past and present data.

It often works best when composed with:

- `&time.forecast` for turning detected patterns into predictions
- `&memory.*` for pattern-enriched knowledge and structural context
- `&reason.*` for acting on detected rhythms and cycles

A useful shorthand is:

> `&time.pattern` tells the agent what temporal structures are stable enough to reason about.

---

## 4. Typical use cases

### Support ticket seasonality
Detect recurring weekly or monthly cycles in support volume to anticipate staffing needs.

### Research trend cycles
Identify periodic surges in topic interest, publication volume, or signal activity.

### Recurring incident patterns
Recognize repeating failure modes tied to deployment cadence, maintenance windows, or load cycles.

### Demand rhythm characterization
Profile the underlying periodicity of demand signals across regions, products, or service lines.

### Operational baseline profiling
Establish what normal recurring behavior looks like so that deviations become meaningful.

### Maintenance window optimization
Detect when recurring low-activity periods occur to inform scheduling decisions.

---

## 5. Example declaration

A basic `ampersand.json` fragment using `&time.pattern`:

```json
{
  "&time.pattern": {
    "provider": "ticktickclock",
    "config": {
      "windows": ["24h", "7d", "30d"],
      "targets": ["support_volume", "incident_rate"]
    }
  }
}
```

A goal-driven version using auto resolution:

```json
{
  "&time.pattern": {
    "provider": "auto",
    "need": "detect weekly seasonality in customer support ticket volume"
  }
}
```

See also: `customer-support.ampersand.json` and `research-agent.ampersand.json` for full declaration examples.

---

## 6. Compatible providers

The protocol is provider-agnostic. The capability is the contract; providers are implementations.

Representative providers for `&time.pattern` may include:

- `ticktickclock`
- seasonal decomposition services
- motif detection engines
- time-series analysis platforms with periodicity APIs
- domain-specific pattern recognition services

A provider should be considered compatible when it can satisfy the capability contract, not merely because it performs some pattern-related function in marketing language.

---

## 7. Example capability contract

A representative contract artifact for `&time.pattern`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&time.pattern",
  "provider": "ticktickclock",
  "version": "0.1.0",
  "description": "Temporal pattern detection contract for identifying recurring behaviors, seasonality, and trend cycles.",
  "operations": {
    "detect": {
      "in": "time_series",
      "out": "pattern_set",
      "description": "Identify recurring temporal structures including cycles, seasonality, and motifs.",
      "deterministic": false,
      "side_effects": false
    },
    "summarize": {
      "in": "pattern_set",
      "out": "pattern_summary",
      "description": "Convert detected patterns into interpretable signals with strength and periodicity metadata.",
      "deterministic": false,
      "side_effects": false
    },
    "enrich": {
      "in": "context",
      "out": "enriched_context",
      "description": "Attach pattern and seasonality context to an existing decision or planning payload.",
      "deterministic": false,
      "side_effects": false
    }
  },
  "accepts_from": [
    "&memory.*",
    "&space.*",
    "raw_data",
    "time_series",
    "context"
  ],
  "feeds_into": [
    "&time.forecast",
    "&reason.*",
    "&memory.*",
    "output"
  ],
  "a2a_skills": [
    "temporal-pattern-detection",
    "seasonality-analysis"
  ]
}
```

This contract matters because it makes pattern detection composable in a typed system.

---

## 8. Example provider configuration patterns

The protocol does not hardcode one configuration shape, but these fields are common and useful.

### Windows
Which time windows to analyze for recurring structure.

```json
{
  "windows": ["24h", "7d", "30d"]
}
```

### Targets
Which signals or domains are being analyzed for patterns.

```json
{
  "targets": ["support_volume", "incident_rate"]
}
```

### Minimum strength
Filter for patterns that meet a minimum strength threshold.

```json
{
  "min_strength": 0.6
}
```

### Pattern types
Optionally constrain which types of temporal structure to search for.

```json
{
  "pattern_types": ["seasonality", "cycle", "motif"]
}
```

### Region or segment scope
Useful for spatially-aware pattern detection.

```json
{
  "regions": ["us-east", "eu-west"]
}
```

These are implementation patterns, not mandatory protocol fields.

---

## 9. Architecture patterns

### Pattern A: pattern -> forecast
Use detected patterns to inform predictions.

```text
time_series
|> &time.pattern.detect()
|> &time.forecast.predict()
```

Use when recurring structure in historical data should improve forecast accuracy.

### Pattern B: pattern -> reason
Use detected patterns directly as decision input.

```text
time_series
|> &time.pattern.detect()
|> &time.pattern.summarize()
|> &reason.argument.evaluate()
```

Use when a detected rhythm or cycle can directly support a decision, recommendation, or escalation.

### Pattern C: pattern -> memory
Use detected patterns to enrich durable knowledge.

```text
time_series
|> &time.pattern.detect()
|> &time.pattern.enrich()
|> &memory.graph.store()
```

Use when identified patterns should become part of organizational memory for future retrieval.

### Pattern D: memory -> pattern -> forecast -> reason
Full temporal pipeline from history through structure to prediction and action.

```text
query_context
|> &memory.graph.recall()
|> &time.pattern.detect()
|> &time.forecast.predict()
|> &reason.argument.evaluate()
```

Use when the agent needs to recall historical data, identify its structure, project forward, and decide.

---

## 10. Architecture diagram

A simple conceptual view of `&time.pattern` in composition:

```text
historical data / stream data
            |
            v
   +----------------------+
   |   &time.pattern      |
   | detect / summarize   |
   +----------------------+
            |
            v
       pattern_set
            |
     +------+------+
     |             |
     v             v
&time.forecast  &memory.*
  predict        store
     |             |
     +------+------+
            |
            v
       &reason.*
        evaluate
            |
            v
         output
```

This is why contract typing matters: downstream capabilities need to know what kind of artifact they are receiving.

---

## 11. Example API shape

A provider-specific API will vary, but a pattern detection provider commonly exposes a shape like:

```json
{
  "operation": "detect",
  "input": {
    "series": [
      { "timestamp": "2026-02-22T00:00:00Z", "value": 142 },
      { "timestamp": "2026-02-22T01:00:00Z", "value": 155 },
      { "timestamp": "2026-02-23T00:00:00Z", "value": 148 },
      { "timestamp": "2026-02-23T01:00:00Z", "value": 160 }
    ],
    "windows": ["24h", "7d"]
  }
}
```

Representative response:

```json
{
  "patterns": [
    {
      "type": "seasonality",
      "period": "24h",
      "strength": 0.87,
      "description": "Strong daily cycle with peak activity between 09:00 and 11:00 UTC."
    },
    {
      "type": "cycle",
      "period": "7d",
      "strength": 0.72,
      "description": "Moderate weekly rhythm with reduced activity on weekends."
    }
  ],
  "summary": "Two recurring patterns detected: a strong daily peak and a moderate weekly cycle."
}
```

The protocol does not require this exact transport shape. It requires that the provider satisfy the declared capability contract.

---

## 12. Governance implications

Patterns are often used to justify structural assumptions about system behavior. That makes governance important.

Common governance examples for pattern-driven systems:

### Hard constraints
- never treat a detected pattern as ground truth without sufficient observation windows
- never automate staffing changes from pattern output alone
- never suppress audit logging for pattern-driven decisions

### Soft constraints
- prefer longer observation windows over short ones when pattern stability is uncertain
- prefer explicit seasonality detection over inferred periodicity
- prefer validated patterns over single-window detections

### Escalation rules
Pattern-driven systems often combine well with:

```json
{
  "escalate_when": {
    "pattern_strength_below": 0.5,
    "conflicting_patterns_detected": true,
    "observation_window_insufficient": true
  }
}
```

This is one reason `&time.pattern` often composes closely with `&reason.argument` or `&reason.plan`.

---

## 13. Provenance implications

Patterns can strongly influence planning, resource allocation, and operational assumptions, so provenance should be explicit.

A provenance record for a pattern detection step may include:

```json
{
  "source": "&time.pattern",
  "provider": "ticktickclock",
  "operation": "detect",
  "timestamp": "2026-03-15T12:00:00Z",
  "input_hash": "sha256:abcd1234...",
  "output_hash": "sha256:efgh5678...",
  "parent_hash": "sha256:0000...",
  "mcp_trace_id": "ttc-pattern-17"
}
```

This helps answer questions like:

- Why did the system assume weekly seasonality?
- Which provider identified this recurring structure?
- What observation windows informed the detected pattern?
- Which upstream context produced this pattern set?

Patterns without provenance are difficult to audit and easy to over-trust.

---

## 14. A2A implications

A pattern detection capability may map naturally to A2A-advertised skills such as:

- `temporal-pattern-detection`
- `seasonality-analysis`

That means an agent card generated from an `ampersand.json` declaration can advertise pattern detection as a reusable, discoverable coordination-facing skill.

This is one example of how the [&] Protocol complements A2A rather than replacing it.

---

## 15. MCP implications

A pattern detection provider may also compile into MCP-facing configuration if the implementation exposes a tool or service endpoint.

For example, a declaration containing `&time.pattern` may generate MCP configuration that wires in a pattern detection provider alongside memory and reasoning providers.

This is one example of how the [&] Protocol complements MCP rather than replacing it.

---

## 16. Research references and grounding

The design of `&time.pattern` is informed by overlapping areas of work:

- seasonal decomposition
- motif discovery
- periodicity detection
- cycle analysis
- temporal data mining
- time-series structural analysis
- recurring behavior characterization in operational systems

The important protocol-level insight is not that pattern detection is new. It is that **pattern detection should be represented explicitly as a composable capability** rather than hidden in framework logic.

That shift enables:

- schema validation
- typed pipelines
- provider interchangeability
- governance-aware decisions
- provenance-preserving execution

---

## 17. Anti-patterns

### Anti-pattern 1: conflate pattern detection and anomaly detection
They are complementary temporal capabilities, but they are not the same interface. Anomaly detection finds what is unusual. Pattern detection finds what recurs.

### Anti-pattern 2: treat detected patterns as permanent
Patterns can decay, shift, or disappear. A pattern detected over one window may not hold over another.

### Anti-pattern 3: treat pattern detection as generic analytics
If pattern detection is bundled into a broad "analytics" block, its contract and pipeline role become unclear.

### Anti-pattern 4: hardwire the protocol to one provider
`&time.pattern` should remain a portable capability contract.

---

## 18. Good default guidance

Use `&time.pattern` when:

- the system needs to identify recurring temporal structures
- a planner or forecaster must act on detected periodicity or seasonality
- demand, load, or incident rhythms matter operationally
- a declaration should express structural temporal intelligence explicitly

Prefer composing it with:

- `&time.forecast` when detected patterns should inform predictions
- `&memory.*` when patterns should enrich durable knowledge
- `&reason.*` when detected rhythms influence action selection

Recommended observation windows: 24h, 7d, 30d.

---

## 19. Summary

`&time.pattern` is the [&] Protocol capability for detecting recurring temporal structure.

It exists to make structural temporal intelligence:

- explicit
- composable
- contract-aware
- provider-agnostic
- governable
- provenance-friendly
- generatable into MCP and A2A surfaces

In short:

> `&time.pattern` gives an agent a standard way to declare that it can identify recurring temporal structures and use that knowledge safely within a composed cognitive system.
