# `&space.fleet` — Fleet State, Regional Context, and Spatial Operations

`&space.fleet` is the [&] Protocol capability for **fleet-aware spatial intelligence**.

It describes an agent's ability to reason about:

- where assets are
- which regions are affected
- how capacity is distributed
- what route or allocation options are feasible
- how spatial state should enrich downstream decisions

In the protocol's four-primitive model:

- `&memory` answers **what** the agent knows
- `&reason` answers **how** the agent decides
- `&time` answers **when** things change
- `&space` answers **where** things are

`&space.fleet` is one of the most practical `&space` subtypes because many real agents operate over:

- vehicles
- field teams
- datacenter regions
- delivery networks
- service territories
- distributed assets
- supply and dispatch systems

---

## 1. Definition

`&space.fleet` is the capability interface for **fleet-state and regional-context awareness**.

It is used when an agent must work with:

- distributed assets across regions
- current or near-current location state
- region-level capacity and utilization
- affected-area enrichment
- fleet-aware routing or allocation support
- operational boundaries tied to geography or logical regions

This capability is not limited to literal vehicle fleets.

It can also apply to:

- cloud regions and clusters
- service zones
- warehouse networks
- technician territories
- dispatchable units
- mobile robotics
- edge deployments

The key idea is that the system is managing a **set of distributed units in space**.

---

## 2. Why this capability exists

Many agent systems fail when they treat the world as if it were only text plus tools.

That works for simple demos, but it breaks down quickly in real workflows.

Examples:

- An infrastructure agent detects an anomaly, but cannot localize which regions are affected.
- A logistics agent forecasts demand, but cannot determine which fleet region has spare capacity.
- A support agent recommends action, but does not know which warehouse or field team owns the issue.
- A dispatch system can reason about urgency, but not whether the nearest viable unit is already overloaded.

In all of these cases, the missing layer is **spatially grounded fleet state**.

`&space.fleet` gives the protocol a standard way to declare that capability.

---

## 3. What problems `&space.fleet` solves

`&space.fleet` is useful when an agent needs to answer questions like:

- Which region is affected?
- Which assets are inside the impacted zone?
- Which fleet segment has spare capacity?
- Which unit is closest or most appropriate?
- Which operational region should receive rerouted work?
- Which datacenter or territory is under pressure?
- How does spatial distribution change the recommended action?

Without this capability, spatial reasoning tends to get buried inside:

- one-off service calls
- custom application logic
- hidden prompt assumptions
- vendor-specific code paths

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

`&space.fleet` is the right subtype when the main problem is **state across a distributed fleet or region graph**, not just route optimization or boundary checking.

---

## 5. Typical use cases

### Fleet operations
Track and enrich vehicle or field-unit state by region, capacity, and current location.

### Infrastructure operations
Map incidents or anomalies to production regions, clusters, facilities, or datacenters.

### Logistics
Determine which region can absorb demand or which assets should be reallocated.

### Service dispatch
Identify nearest or most appropriate dispatchable unit under current fleet constraints.

### Supply chain
Understand regional inventory or transport network pressure before a decision is made.

### Distributed robotics
Select or evaluate units across spatially distributed systems.

### Multi-region platform operations
Interpret failures, forecast load, or scale decisions in relation to regional topology.

---

## 6. Example capability contract

A representative contract for `&space.fleet`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/capability-contract.schema.json",
  "capability": "&space.fleet",
  "provider": "geofleetic",
  "version": "0.1.0",
  "description": "Spatial fleet-state contract for regional asset lookup, route-aware enrichment, and capacity snapshots.",
  "operations": {
    "locate": {
      "in": "asset_query",
      "out": "location_set",
      "description": "Resolve current fleet or asset locations from an asset query."
    },
    "enrich": {
      "in": "context",
      "out": "spatial_context",
      "description": "Attach fleet, region, or topology context to an upstream artifact."
    },
    "capacity": {
      "in": "region_query",
      "out": "capacity_snapshot",
      "description": "Return region- or fleet-level capacity state for planning and routing."
    },
    "route": {
      "in": "route_request",
      "out": "route_plan",
      "description": "Produce a fleet-aware route recommendation under current spatial constraints."
    }
  },
  "accepts_from": [
    "&memory.*",
    "&time.*",
    "raw_data",
    "context"
  ],
  "feeds_into": [
    "&reason.*",
    "&memory.*",
    "output"
  ],
  "a2a_skills": [
    "fleet-state-enrichment",
    "regional-capacity-lookup",
    "route-feasibility-evaluation"
  ]
}
```

### What this contract means

This contract says that `&space.fleet` can:

- locate assets
- enrich upstream context with spatial information
- provide regional capacity snapshots
- assist routing under spatial constraints

It also says that this capability composes well with:

- `&time.*` upstream, where temporal signals must be localized
- `&memory.*` upstream, where prior context should be tied to a region or asset cluster
- `&reason.*` downstream, where spatial state affects action selection

---

## 7. Core operations

### `locate`

Purpose:
- resolve current position or placement of assets

Typical input:
- `asset_query`

Typical output:
- `location_set`

Use when:
- the agent needs to know where relevant units or resources are right now

### `enrich`

Purpose:
- attach spatial fleet context to another artifact

Typical input:
- `context`

Typical output:
- `spatial_context`

Use when:
- another capability has already produced a useful signal and spatial grounding is required before a decision

### `capacity`

Purpose:
- return regional or fleet-wide capacity state

Typical input:
- `region_query`

Typical output:
- `capacity_snapshot`

Use when:
- planning, routing, or escalation depends on whether a region is overloaded or underutilized

### `route`

Purpose:
- provide a route or path recommendation informed by fleet conditions

Typical input:
- `route_request`

Typical output:
- `route_plan`

Use when:
- path choice depends on current distributed fleet state, not only geometry

---

## 8. Architecture patterns

### Pattern A: anomaly -> fleet enrichment -> reasoning

```text
stream_data
|> &time.anomaly.detect()
|> &space.fleet.enrich()
|> &reason.argument.evaluate()
```

Use this when:
- a temporal signal needs to be localized to affected regions or assets before action is chosen

Example:
- detect a load anomaly
- determine which regions are actually constrained
- decide whether to reroute, scale, or escalate

### Pattern B: forecast -> fleet capacity -> planning

```text
demand_history
|> &time.forecast.predict()
|> &space.fleet.capacity()
|> &reason.plan.plan()
```

Use this when:
- future demand should be compared against current or projected regional capacity

Example:
- forecast next-day delivery demand
- inspect available fleet capacity by region
- build a reallocation plan

### Pattern C: memory -> fleet enrichment -> reasoning

```text
incident_context
|> &memory.graph.enrich()
|> &space.fleet.enrich()
|> &reason.argument.evaluate()
```

Use this when:
- prior operational or incident knowledge should be combined with live regional state before making a decision

### Pattern D: fleet route support

```text
dispatch_request
|> &space.fleet.locate()
|> &space.fleet.route()
|> &reason.plan.evaluate()
```

Use this when:
- the system needs both current fleet placement and a route-aware recommendation

---

## 9. Architecture diagram

A simplified conceptual flow for `&space.fleet`:

```text
incoming signal / query / forecast
              |
              v
      +-------------------+
      |   &space.fleet    |
      |                   |
      | locate            |
      | enrich            |
      | capacity          |
      | route             |
      +---------+---------+
                |
                v
      +-------------------+
      | spatial_context   |
      | location_set      |
      | capacity_snapshot |
      | route_plan        |
      +---------+---------+
                |
                v
      +-------------------+
      | &reason.* /       |
      | &memory.* /       |
      | output            |
      +-------------------+
```

The capability's job is to turn generic or upstream context into **spatially actionable state**.

---

## 10. Example declaration

A concrete `ampersand.json` fragment:

```json
{
  "&space.fleet": {
    "provider": "geofleetic",
    "config": {
      "regions": ["us-east", "us-central"],
      "mode": "regional-capacity-awareness"
    }
  }
}
```

A fuller declaration:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "FleetManager",
  "version": "0.1.0",
  "capabilities": {
    "&time.forecast": {
      "provider": "ticktickclock",
      "config": {
        "horizon_hours": 24,
        "granularity": "hourly"
      }
    },
    "&space.fleet": {
      "provider": "geofleetic",
      "config": {
        "regions": ["us-east", "us-central"],
        "mode": "regional-capacity-awareness"
      }
    },
    "&reason.plan": {
      "provider": "auto",
      "need": "fleet reallocation planning with policy-aware tradeoffs"
    }
  },
  "governance": {
    "hard": [
      "Never route assets through restricted zones without authorization"
    ],
    "soft": [
      "Prefer local-region balancing before cross-region escalation"
    ],
    "escalate_when": {
      "confidence_below": 0.75,
      "hard_boundary_approached": true
    }
  },
  "provenance": true
}
```

---

## 11. Example API shape

A provider-specific API will vary, but a typical `locate` request might look like:

```json
{
  "operation": "locate",
  "input": {
    "asset_ids": ["veh_102", "veh_104", "veh_201"],
    "region_scope": ["us-east", "us-central"]
  }
}
```

Representative response:

```json
{
  "location_set": [
    {
      "asset_id": "veh_102",
      "region": "us-east",
      "lat": 40.7128,
      "lon": -74.0060,
      "status": "available"
    },
    {
      "asset_id": "veh_104",
      "region": "us-east",
      "lat": 39.9526,
      "lon": -75.1652,
      "status": "busy"
    }
  ]
}
```

A `capacity` request might look like:

```json
{
  "operation": "capacity",
  "input": {
    "regions": ["us-east", "us-central"],
    "window": "next_24h"
  }
}
```

Representative response:

```json
{
  "capacity_snapshot": {
    "us-east": {
      "available_units": 14,
      "utilization": 0.87
    },
    "us-central": {
      "available_units": 22,
      "utilization": 0.61
    }
  }
}
```

The protocol does not standardize this exact transport payload. It standardizes the capability contract.

---

## 12. Compatible providers

Representative compatible providers include:

- `geofleetic`
- custom geospatial fleet services
- dispatch and field-service backends exposed behind MCP-compatible surfaces
- routing and regional operations systems with stable contract wrappers
- infrastructure topology services that expose region-state as a fleet-like capability

### Default ecosystem fit

The most natural default ecosystem example in this repository is:

- `geofleetic`

Why it fits:
- fleet-aware domain model
- regional and route-aware spatial semantics
- strong compatibility with logistics and distributed operations use cases

The protocol stance remains:

> `&space.fleet` is the capability.  
> `geofleetic` is one provider that may satisfy it.

---

## 13. Governance implications

Spatial fleet decisions often have real operational consequences, so governance matters.

### Common hard constraints

Examples:
- Never route assets through restricted or unsafe operating regions.
- Never disclose sensitive fleet location outside authorized workflows.
- Never exceed regional operational limits without approval.
- Never rebalance fleet state in a way that violates service boundaries or compliance zones.

### Common soft constraints

Examples:
- Prefer local-region balancing before cross-region failover.
- Prefer lower-disruption route changes when confidence is moderate.
- Prefer maintaining emergency reserve capacity in critical regions.

### Common escalation rules

Examples:
- escalate when route feasibility is uncertain
- escalate when a hard boundary is approached
- escalate when regional capacity falls below a critical threshold
- escalate when the best spatial option exceeds cost or policy thresholds

Representative governance block:

```json
{
  "governance": {
    "hard": [
      "Never route assets through restricted geofences",
      "Never disclose customer or fleet location outside authorized workflows"
    ],
    "soft": [
      "Prefer local-region remediation before cross-region failover"
    ],
    "escalate_when": {
      "hard_boundary_approached": true,
      "confidence_below": 0.75
    }
  }
}
```

---

## 14. Provenance implications

Spatial enrichment should participate in the provenance chain.

Representative provenance record:

```json
{
  "source": "&space.fleet",
  "provider": "geofleetic",
  "operation": "enrich",
  "timestamp": "2026-03-15T12:00:00Z",
  "input_hash": "sha256:9a77...",
  "output_hash": "sha256:bc12...",
  "parent_hash": "sha256:7b2c...",
  "mcp_trace_id": "gfleet-enrich-204"
}
```

This matters because spatial context can strongly influence downstream action.

Provenance should help answer questions like:

- Why did the system choose `us-east` instead of `us-central`?
- Which fleet-state snapshot informed the decision?
- Which provider produced the location or capacity context?
- Which upstream anomaly or forecast led to this spatial query?

---

## 15. A2A-facing skills

A `&space.fleet` capability may advertise skills such as:

- `fleet-state-enrichment`
- `regional-capacity-lookup`
- `route-feasibility-evaluation`

These are useful when generating A2A-style agent cards, because they let an external coordination surface say more than “has spatial awareness.”

Instead, it can say the agent can:

- enrich tasks with fleet state
- evaluate regional capacity
- support route feasibility judgments

---

## 16. MCP-facing implications

A declaration containing `&space.fleet` may compile into MCP-facing configuration for a compatible spatial provider.

That makes `&space.fleet` a good example of the protocol's overall claim:

- the declaration captures capability composition
- downstream tools can generate runtime config from that declaration

In other words:

> [&] declares the fleet-aware spatial capability  
> MCP can carry the provider-facing integration

---

## 17. Research grounding

`&space.fleet` is supported by several overlapping research and systems traditions:

- spatial reasoning
- geospatial information systems
- fleet optimization and dispatch
- route planning and logistics
- situated and embodied decision systems
- distributed operations management
- topology-aware infrastructure control

The important protocol-level insight is not that fleet optimization is new.

It is that **fleet-aware spatial reasoning should be explicit in the agent's capability declaration**, rather than buried in framework code or provider-specific prompts.

That explicitness enables:

- schema validation
- contract checking
- provider interchangeability
- governance-aware composition
- provenance-preserving decisions
- downstream MCP and A2A generation

---

## 18. Anti-patterns

### Anti-pattern 1: treat fleet state as generic metadata
If fleet context changes the meaning of a decision, it should be modeled explicitly.

### Anti-pattern 2: collapse route, fleet, and geofence into one opaque spatial block
These are related, but not identical, interfaces.

### Anti-pattern 3: let reasoning guess spatial truth from text
A reasoner may explain well and still be the wrong source of authoritative fleet state.

### Anti-pattern 4: use spatial decisions without provenance
If region, asset, or route context affects the outcome, lineage should be preserved.

---

## 19. Practical guidance

Use `&space.fleet` when:

- the system manages distributed assets or regions
- current or projected capacity matters
- the agent must localize events before acting
- the system should choose actions differently depending on region or fleet state

Prefer composing it with:

- `&time.*` when temporal signals need localization
- `&memory.*` when prior incidents or cases should be mapped to spatial context
- `&reason.*` when action selection depends on regional or fleet constraints

Common high-value compositions:

- `&time.anomaly` + `&space.fleet` + `&reason.argument`
- `&time.forecast` + `&space.fleet` + `&reason.plan`
- `&memory.graph` + `&space.fleet` + `&reason.argument`

---

## 20. Example scenarios

### Regional infrastructure remediation
- detect anomaly
- localize affected region
- inspect region capacity
- choose safe remediation

### Fleet rebalancing
- forecast demand surge
- compare regional fleet availability
- generate reallocation plan

### Field dispatch
- identify nearest viable unit
- check territory constraints
- select dispatch candidate

### Multi-region support operations
- determine which region owns the issue
- check handoff capacity
- escalate or reroute appropriately

---

## 21. Summary

`&space.fleet` is the [&] Protocol capability for **fleet-aware spatial context**.

It is the right capability when an agent needs to know:

- where distributed assets are
- which regions are affected
- how capacity is distributed
- what route or reallocation decisions are feasible
- how spatial state should constrain downstream action

In one sentence:

> `&space.fleet` gives an agent a protocol-native way to understand and act on distributed spatial state.

---