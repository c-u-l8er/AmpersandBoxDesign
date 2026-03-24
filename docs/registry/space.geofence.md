# `&space.geofence` --- Boundary Membership, Zone Logic, and Compliance Awareness

`&space.geofence` is the [&] Protocol capability for **geofence-aware spatial contracts**.

It describes an agent's ability to reason about:

- whether an entity is inside or outside a boundary
- when boundary crossings occur
- which compliance or service-area zones apply
- how zone membership should constrain downstream decisions
- how geofence context should enrich upstream artifacts

In the protocol's four-primitive model:

- `&memory` answers **what** the agent knows
- `&reason` answers **how** the agent decides
- `&time` answers **when** things change
- `&space` answers **where** things are

`&space.geofence` is one of the most compliance-relevant `&space` subtypes because many real agents operate over:

- restricted operating zones
- service area boundaries
- regulatory jurisdictions
- facility perimeters
- exclusion zones
- delivery coverage areas
- environmental or safety regions

---

## 1. Definition

`&space.geofence` is the capability interface for **boundary membership and zone-compliance logic**.

It is used when an agent must work with:

- spatial boundaries that define allowed or restricted areas
- membership evaluation for entities against those boundaries
- enter and exit event detection at zone edges
- compliance constraints tied to geographic or logical zones
- service-area enrichment for upstream artifacts
- zone-aware decision support

This capability is not limited to literal geographic fences.

It can also apply to:

- regulatory jurisdictions
- network security perimeters
- airspace restrictions
- emissions or environmental zones
- insurance coverage areas
- operational authority boundaries
- logical partitions with spatial semantics

The key idea is that the system is evaluating **membership within bounded regions**.

---

## 2. Why this capability exists

Many agent systems treat spatial constraints as simple metadata or post-hoc filters.

That works for demos, but it breaks down quickly in regulated or safety-critical workflows.

Examples:

- A dispatch agent routes a vehicle into a restricted zone because boundary logic was not part of the decision chain.
- A compliance agent cannot determine whether a field team is operating within its authorized service area.
- A facility management agent detects motion near a perimeter, but has no structured way to classify the crossing event.
- A logistics agent builds a plan that violates emissions-zone restrictions because zone boundaries were never consulted.

In all of these cases, the missing layer is **boundary-aware spatial evaluation**.

`&space.geofence` gives the protocol a standard way to declare that capability.

---

## 3. What problems `&space.geofence` solves

`&space.geofence` is useful when an agent needs to answer questions like:

- Is this entity inside the permitted zone?
- Has this asset crossed a restricted boundary?
- Which compliance region does this location fall within?
- Which service area applies to this request?
- Did a boundary crossing event just occur?
- Which zone constraints should apply to this planned action?
- How does zone membership change the recommended decision?

Without this capability, boundary logic tends to get buried inside:

- one-off geospatial queries
- custom application logic
- hardcoded coordinate checks
- vendor-specific geofencing APIs

The protocol makes it explicit instead.

---

## 4. Capability role in the `&space` namespace

The `&space` primitive can support multiple subtypes, including:

- `&space.fleet`
- `&space.route`
- `&space.geofence`

A helpful distinction is:

- `&space.fleet` = distributed assets and regional state
- `&space.route` = path and route computation
- `&space.geofence` = boundary and zone membership logic

`&space.geofence` is the right subtype when the main problem is **whether entities are inside or outside defined boundaries**, not tracking distributed fleet state or computing paths between points.

---

## 5. Typical use cases

### Compliance zone enforcement
Evaluate whether service vehicles, field agents, or autonomous systems are operating within their authorized zones.

### Facility access control
Detect and classify enter and exit events at facility perimeters, restricted areas, or secure zones.

### Service area validation
Determine whether a request, delivery, or dispatch falls within the applicable service area before committing resources.

### Regulatory jurisdiction mapping
Attach jurisdiction or regulatory-zone context to upstream artifacts so downstream reasoning respects local rules.

### Exclusion zone monitoring
Continuously evaluate whether tracked entities have entered prohibited or hazardous areas.

### Environmental compliance
Check whether operations are occurring within emissions zones, protected habitats, or other environmentally regulated boundaries.

### Insurance and liability boundaries
Determine which coverage area applies to a given location or event for liability and claims processing.

---

## 6. Example capability contract

A representative contract for `&space.geofence`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&space.geofence",
  "provider": "geofleetic",
  "version": "0.1.0",
  "description": "Geofence-aware spatial contract for boundary membership evaluation, crossing detection, and compliance-context enrichment.",
  "operations": {
    "contains": {
      "in": "location_query",
      "out": "membership_result",
      "description": "Evaluate whether a location or entity is within one or more defined boundaries."
    },
    "enter_exit": {
      "in": "crossing_query",
      "out": "crossing_event",
      "description": "Detect and classify boundary crossing events for tracked entities."
    },
    "enrich": {
      "in": "context",
      "out": "geofence_context",
      "description": "Attach geofence, service-area, or compliance-zone context to an upstream artifact."
    }
  },
  "accepts_from": [
    "&memory.*",
    "&time.*",
    "&space.fleet",
    "raw_data",
    "context"
  ],
  "feeds_into": [
    "&reason.*",
    "&memory.*",
    "&space.route",
    "output"
  ],
  "a2a_skills": [
    "geofence-membership-evaluation",
    "boundary-alerting"
  ]
}
```

### What this contract means

This contract says that `&space.geofence` can:

- evaluate location membership against defined boundaries
- detect boundary crossing events
- enrich upstream context with zone and compliance information

It also says that this capability composes well with:

- `&time.*` upstream, where temporal signals must be evaluated against zone boundaries
- `&space.fleet` upstream, where fleet positions must be checked against permitted zones
- `&reason.*` downstream, where zone membership affects action selection
- `&space.route` downstream, where routes must respect zone constraints

---

## 7. Core operations

### `contains`

Purpose:
- evaluate whether a location or entity falls within one or more defined boundaries

Typical input:
- `location_query`

Typical output:
- `membership_result`

Use when:
- the agent needs to know whether something is inside or outside a specific zone

### `enter_exit`

Purpose:
- detect and classify boundary crossing events

Typical input:
- `crossing_query`

Typical output:
- `crossing_event`

Use when:
- the system must respond to entities entering or leaving defined zones

### `enrich`

Purpose:
- attach geofence, service-area, or compliance-zone context to another artifact

Typical input:
- `context`

Typical output:
- `geofence_context`

Use when:
- another capability has already produced a useful signal and zone-boundary grounding is required before a decision

---

## 8. Architecture patterns

### Pattern A: fleet state -> geofence check -> reasoning

```text
fleet_positions
|> &space.fleet.locate()
|> &space.geofence.contains()
|> &reason.argument.evaluate()
```

Use this when:
- current fleet positions must be validated against permitted operating zones before action is chosen

Example:
- locate service vehicles
- check whether any are inside restricted zones
- decide whether to recall, reroute, or escalate

### Pattern B: crossing event -> geofence enrichment -> alerting

```text
position_stream
|> &space.geofence.enter_exit()
|> &space.geofence.enrich()
|> &reason.argument.evaluate()
```

Use this when:
- real-time or near-real-time boundary crossings must trigger zone-aware responses

Example:
- detect that a vehicle has entered a restricted area
- enrich the event with zone classification and compliance requirements
- evaluate whether the crossing requires an alert, recall, or escalation

### Pattern C: route planning -> geofence constraint -> route validation

```text
route_candidate
|> &space.geofence.contains()
|> &space.route.plan()
|> &reason.plan.evaluate()
```

Use this when:
- planned routes must be validated against zone boundaries before commitment

Example:
- check whether a proposed route passes through restricted zones
- replan the route to avoid prohibited areas
- evaluate the adjusted plan against operational constraints

### Pattern D: anomaly -> geofence enrichment -> compliance reasoning

```text
anomaly_signal
|> &time.anomaly.detect()
|> &space.geofence.enrich()
|> &reason.argument.evaluate()
```

Use this when:
- a temporal anomaly must be evaluated in the context of zone boundaries and compliance requirements

Example:
- detect an anomalous boundary crossing pattern
- enrich with zone classification and historical crossing data
- determine whether this represents a compliance violation or expected behavior

---

## 9. Architecture diagram

A simplified conceptual flow for `&space.geofence`:

```text
incoming signal / location / crossing event
              |
              v
      +-------------------+
      | &space.geofence   |
      |                   |
      | contains          |
      | enter_exit        |
      | enrich            |
      +---------+---------+
                |
                v
      +-------------------+
      | membership_result |
      | crossing_event    |
      | geofence_context  |
      +---------+---------+
                |
                v
      +-------------------+
      | &reason.* /       |
      | &space.route /    |
      | &memory.* /       |
      | output            |
      +-------------------+
```

The capability's job is to turn location data into **boundary-aware, compliance-grounded spatial context**.

---

## 10. Example declaration

A concrete `ampersand.json` fragment:

```json
{
  "&space.geofence": {
    "provider": "geofleetic",
    "config": {
      "zones": ["restricted-ops", "service-area-west"],
      "mode": "compliance-boundary-enforcement"
    }
  }
}
```

A fuller declaration:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "ZoneComplianceAgent",
  "version": "0.1.0",
  "capabilities": {
    "&space.fleet": {
      "provider": "geofleetic",
      "config": {
        "regions": ["us-east", "us-central"],
        "mode": "regional-capacity-awareness"
      }
    },
    "&space.geofence": {
      "provider": "geofleetic",
      "config": {
        "zones": ["restricted-ops", "service-area-west", "emissions-zone-a"],
        "mode": "compliance-boundary-enforcement"
      }
    },
    "&reason.argument": {
      "provider": "auto",
      "need": "compliance evaluation with boundary-aware constraint checking"
    }
  },
  "governance": {
    "hard": [
      "Never allow operations inside restricted zones without explicit authorization",
      "Never suppress boundary crossing alerts for compliance-critical zones"
    ],
    "soft": [
      "Prefer early warning when an entity approaches a restricted boundary",
      "Prefer zone-local remediation before cross-zone escalation"
    ],
    "escalate_when": {
      "confidence_below": 0.8,
      "hard_boundary_crossed": true
    }
  },
  "provenance": true
}
```

---

## 11. Example API shape

A provider-specific API will vary, but a typical `contains` request might look like:

```json
{
  "operation": "contains",
  "input": {
    "entity_id": "veh_102",
    "lat": 40.7128,
    "lon": -74.0060,
    "zones": ["restricted-ops", "service-area-west"]
  }
}
```

Representative response:

```json
{
  "membership_result": {
    "entity_id": "veh_102",
    "evaluations": [
      {
        "zone": "restricted-ops",
        "inside": false,
        "distance_to_boundary_m": 340
      },
      {
        "zone": "service-area-west",
        "inside": true,
        "compliance_status": "compliant"
      }
    ]
  }
}
```

An `enter_exit` request might look like:

```json
{
  "operation": "enter_exit",
  "input": {
    "entity_id": "veh_104",
    "zone": "restricted-ops",
    "position_history": [
      { "lat": 40.7120, "lon": -74.0050, "ts": "2026-03-15T11:58:00Z" },
      { "lat": 40.7135, "lon": -74.0070, "ts": "2026-03-15T12:00:00Z" }
    ]
  }
}
```

Representative response:

```json
{
  "crossing_event": {
    "entity_id": "veh_104",
    "zone": "restricted-ops",
    "event_type": "enter",
    "crossing_time": "2026-03-15T11:59:12Z",
    "confidence": 0.94
  }
}
```

The protocol does not standardize this exact transport payload. It standardizes the capability contract.

---

## 12. Compatible providers

Representative compatible providers include:

- `geofleetic`
- custom geofencing and boundary management services
- compliance and regulatory zone databases exposed behind MCP-compatible surfaces
- facility management and access control systems with stable contract wrappers
- environmental zone registries that expose boundary membership as a capability

### Default ecosystem fit

The most natural default ecosystem example in this repository is:

- `geofleetic`

Why it fits:
- boundary-aware domain model
- zone membership and compliance semantics
- strong compatibility with logistics, fleet, and regulatory use cases

The protocol stance remains:

> `&space.geofence` is the capability.
> `geofleetic` is one provider that may satisfy it.

---

## 13. Governance implications

Geofence decisions are often directly tied to compliance, making governance especially important for this capability.

### Common hard constraints

Examples:
- Never allow operations inside restricted zones without explicit authorization.
- Never suppress or delay boundary crossing alerts for safety-critical zones.
- Never override compliance-zone restrictions based on soft preferences alone.
- Never disclose sensitive zone boundary definitions outside authorized workflows.

### Common soft constraints

Examples:
- Prefer early warning when entities approach restricted boundaries.
- Prefer zone-local remediation before cross-zone escalation.
- Prefer conservative boundary classification when confidence is moderate.
- Prefer maintaining buffer distances from hard boundaries when feasible.

### Common escalation rules

Examples:
- escalate when a hard boundary is crossed
- escalate when an entity approaches a restricted zone within a configurable threshold
- escalate when zone membership status is ambiguous or conflicting
- escalate when a compliance-critical crossing event cannot be classified with high confidence

Representative governance block:

```json
{
  "governance": {
    "hard": [
      "Never permit operations inside restricted zones without authorization",
      "Never suppress compliance-zone crossing alerts"
    ],
    "soft": [
      "Prefer early boundary-approach warnings over post-crossing alerts"
    ],
    "escalate_when": {
      "hard_boundary_crossed": true,
      "confidence_below": 0.8
    }
  }
}
```

---

## 14. Provenance implications

Geofence evaluation should participate in the provenance chain.

Representative provenance record:

```json
{
  "source": "&space.geofence",
  "provider": "geofleetic",
  "operation": "contains",
  "timestamp": "2026-03-15T12:00:00Z",
  "input_hash": "sha256:4c11...",
  "output_hash": "sha256:e83a...",
  "parent_hash": "sha256:7b2c...",
  "mcp_trace_id": "gfence-contains-107"
}
```

This matters because zone membership can directly determine whether an action is permitted or prohibited.

Provenance should help answer questions like:

- Why was this entity classified as inside the restricted zone?
- Which boundary definition was used for the evaluation?
- Which provider produced the membership or crossing result?
- Which upstream fleet position or anomaly triggered the geofence query?

---

## 15. A2A-facing skills

A `&space.geofence` capability may advertise skills such as:

- `geofence-membership-evaluation`
- `boundary-alerting`

These are useful when generating A2A-style agent cards, because they let an external coordination surface say more than "has boundary awareness."

Instead, it can say the agent can:

- evaluate zone membership for entities and locations
- detect and alert on boundary crossing events

---

## 16. MCP-facing implications

A declaration containing `&space.geofence` may compile into MCP-facing configuration for a compatible geofence provider.

That makes `&space.geofence` a good example of the protocol's overall claim:

- the declaration captures capability composition
- downstream tools can generate runtime config from that declaration

In other words:

> [&] declares the geofence-aware spatial capability
> MCP can carry the provider-facing integration

---

## 17. Research grounding

`&space.geofence` is supported by several overlapping research and systems traditions:

- geospatial information systems
- computational geometry and point-in-polygon evaluation
- geofencing and location-based services
- regulatory and compliance automation
- facility and perimeter security systems
- environmental monitoring and zone management
- situated decision systems with spatial constraints

The important protocol-level insight is not that geofencing is new.

It is that **boundary-aware zone logic should be explicit in the agent's capability declaration**, rather than buried in framework code or provider-specific APIs.

That explicitness enables:

- schema validation
- contract checking
- provider interchangeability
- governance-aware composition
- provenance-preserving decisions
- downstream MCP and A2A generation

---

## 18. Anti-patterns

### Anti-pattern 1: collapse geofence logic into fleet state
Fleet state tracks where assets are. Geofence logic evaluates whether those positions satisfy boundary constraints. They are related but distinct interfaces.

### Anti-pattern 2: treat zone boundaries as static configuration only
Boundaries may change over time (temporary restrictions, seasonal zones, emergency exclusions). The capability should support dynamic boundary definitions.

### Anti-pattern 3: let reasoning infer boundary membership from coordinates alone
A reasoner may estimate proximity, but authoritative zone membership should come from a dedicated boundary evaluation, not text-based spatial guessing.

### Anti-pattern 4: use geofence decisions without provenance
If zone membership or a crossing event affects the outcome, lineage should be preserved. Compliance audits depend on it.

---

## 19. Practical guidance

Use `&space.geofence` when:

- the system must evaluate whether entities are inside or outside defined zones
- boundary crossing events must be detected and classified
- compliance, safety, or regulatory constraints are tied to geographic boundaries
- zone membership should influence downstream action selection

Prefer composing it with:

- `&space.fleet` when fleet positions must be checked against zone boundaries
- `&space.route` when routes must respect zone constraints
- `&time.anomaly` when anomalous boundary crossings need detection
- `&reason.*` when action selection depends on zone membership or compliance status

Common high-value compositions:

- `&space.fleet` + `&space.geofence` + `&reason.argument`
- `&space.geofence` + `&space.route` + `&reason.plan`
- `&time.anomaly` + `&space.geofence` + `&reason.argument`

---

## 20. Example scenarios

### Restricted zone compliance
- locate service vehicles
- evaluate zone membership against restricted areas
- flag violations and trigger recall or reroute

### Facility enter/exit monitoring
- stream entity positions near facility perimeters
- detect crossing events at controlled boundaries
- classify and log each event for security and audit

### Compliance-boundary enrichment
- receive upstream dispatch or routing artifact
- enrich with applicable compliance zones and restrictions
- pass enriched context to reasoning for constraint-aware planning

### Anomalous boundary crossing detection
- detect unusual crossing patterns via temporal anomaly
- evaluate crossing against zone classification and historical baselines
- escalate or alert when crossing is unexplained or policy-violating

---

## 21. Summary

`&space.geofence` is the [&] Protocol capability for **boundary-aware zone logic and compliance evaluation**.

It is the right capability when an agent needs to know:

- whether entities are inside or outside defined boundaries
- when boundary crossings occur
- which compliance or service-area zones apply
- how zone membership should constrain downstream decisions
- how geofence context should enrich upstream artifacts

In one sentence:

> `&space.geofence` gives an agent a protocol-native way to evaluate and enforce spatial boundary constraints.

---
