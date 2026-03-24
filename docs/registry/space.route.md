# `&space.route` -- Route Intelligence, Path Optimization, and Explainable Navigation

`&space.route` is the [&] Protocol capability for **route-aware spatial intelligence**.

It describes an agent's ability to reason about:

- how assets or deliveries get from origin to destination
- which paths are feasible under current constraints
- how a route can be improved for cost, time, or service-level objectives
- why a particular route was selected over alternatives
- how spatial and temporal constraints shape navigation decisions

In the protocol's four-primitive model:

- `&memory` answers **what** the agent knows
- `&reason` answers **how** the agent decides
- `&time` answers **when** things change
- `&space` answers **where** things are

`&space.route` is the `&space` subtype for **sequenced movement through space**. Many real agents must plan, evaluate, or explain paths across:

- delivery networks
- field service territories
- supply chain corridors
- vehicle dispatch systems
- logistics and freight operations
- multi-stop service routes
- infrastructure maintenance circuits

---

## 1. Definition

`&space.route` is the capability interface for **path generation, route optimization, and explainable navigation**.

It is used when an agent must work with:

- route generation from origin to destination under constraints
- route improvement for efficiency, cost, or SLA compliance
- route explanation for operator review, auditing, or compliance
- constraint-aware path planning across regions or zones
- navigation decisions that must be justified after the fact

This capability is not limited to literal vehicle routing.

It can also apply to:

- data pipeline routing across regions
- network traffic path selection
- workflow routing through processing stages
- supply chain path decisions
- maintenance circuit planning
- evacuation or emergency routing

The key idea is that the system is planning or evaluating a **sequence of steps through space**.

---

## 2. Why this capability exists

Many agent systems can reason about what to do, but not about how to get there.

That gap shows up quickly in real workflows.

Examples:

- A logistics agent receives a delivery request, but has no structured way to generate or compare route options.
- A dispatch agent knows which unit to send, but cannot explain why a particular path was chosen over a shorter one.
- An operations agent detects a regional constraint, but cannot re-route affected deliveries under the new conditions.
- A planning agent optimizes cost, but does not account for SLA windows or restricted zones along the route.

In all of these cases, the missing layer is **structured route intelligence**.

`&space.route` gives the protocol a standard way to declare that capability.

---

## 3. What problems `&space.route` solves

`&space.route` is useful when an agent needs to answer questions like:

- What is the best route from A to B under current constraints?
- Can this route be improved for cost, travel time, or service compliance?
- Why was this route chosen instead of the obvious alternative?
- What tradeoffs were involved in the route selection?
- How should the route change now that a regional constraint has appeared?
- Which stops should be reordered to improve efficiency?
- What would the route look like if we added a new constraint or waypoint?

Without this capability, route reasoning tends to get buried inside:

- one-off service calls
- custom application logic
- hidden prompt assumptions
- vendor-specific optimization APIs

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

`&space.route` is the right subtype when the main problem is **planning or evaluating a path through space**, not tracking where assets currently are or checking whether a point falls inside a boundary.

A useful way to remember the difference:

- `&space.fleet` answers **where things are**
- `&space.route` answers **how things get there**
- `&space.geofence` answers **whether something is inside or outside a zone**

---

## 5. Typical use cases

### Delivery routing under constraints
Generate feasible delivery routes that respect time windows, vehicle capacity, restricted zones, and cost targets.

### Route optimization
Take an existing route plan and improve it for travel time, fuel cost, driver hours, or SLA compliance.

### Route explanation and auditing
Produce structured justifications for why a route was selected, what tradeoffs were made, and which constraints shaped the decision.

### Constraint-reactive re-routing
When a new constraint appears (road closure, weather, regional restriction), re-plan affected routes under updated conditions.

### Multi-stop service planning
Plan maintenance, inspection, or field-service routes across multiple stops with ordering constraints.

### Supply chain path selection
Choose transport corridors or logistics paths that balance cost, speed, and risk.

### Cross-region infrastructure routing
Select data, traffic, or workload routing paths across distributed infrastructure regions.

---

## 6. Example capability contract

A representative contract for `&space.route`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&space.route",
  "provider": "geofleetic",
  "version": "0.1.0",
  "description": "Route intelligence contract for path generation, optimization, and explainable navigation decisions under spatial and operational constraints.",
  "operations": {
    "route": {
      "in": "route_request",
      "out": "route_plan",
      "description": "Generate a feasible route plan from an origin, destination, and operating constraints."
    },
    "optimize": {
      "in": "route_plan",
      "out": "optimized_route",
      "description": "Improve an existing route plan for efficiency, cost, or service-level objectives."
    },
    "explain": {
      "in": "route_plan",
      "out": "route_explanation",
      "description": "Explain route selection, tradeoffs, and constraint impacts for auditing and operator review."
    }
  },
  "accepts_from": [
    "&memory.*",
    "&time.*",
    "&space.*",
    "context",
    "route_request",
    "raw_data"
  ],
  "feeds_into": [
    "&reason.*",
    "&memory.*",
    "&space.*",
    "output"
  ],
  "a2a_skills": [
    "route-generation",
    "route-optimization"
  ]
}
```

### What this contract means

This contract says that `&space.route` can:

- generate feasible route plans
- optimize existing routes for cost, time, or SLA objectives
- explain route decisions for auditing and operator review

It also says that this capability composes well with:

- `&time.*` upstream, where temporal signals constrain route feasibility
- `&memory.*` upstream, where prior route history or incident context informs planning
- `&space.*` upstream, where fleet state or geofence boundaries shape available paths
- `&reason.*` downstream, where route options feed into action selection
- `&memory.*` downstream, where route decisions should be recorded for future reference

---

## 7. Core operations

### `route`

Purpose:
- generate a feasible route plan from origin to destination under constraints

Typical input:
- `route_request`

Typical output:
- `route_plan`

Use when:
- the agent needs to produce one or more candidate routes for a trip, delivery, or movement

### `optimize`

Purpose:
- improve an existing route plan for efficiency, cost, or service objectives

Typical input:
- `route_plan`

Typical output:
- `optimized_route`

Use when:
- a route exists but may not be optimal, and the system should try to reduce cost, travel time, or SLA risk

### `explain`

Purpose:
- produce a structured justification for route selection and tradeoffs

Typical input:
- `route_plan`

Typical output:
- `route_explanation`

Use when:
- an operator, auditor, or downstream agent needs to understand why a route was chosen and what constraints shaped the decision

---

## 8. Architecture patterns

### Pattern A: anomaly -> route re-planning -> reasoning

```text
stream_data
|> &time.anomaly.detect()
|> &space.route.route()
|> &reason.argument.evaluate()
```

Use this when:
- a temporal signal (anomaly, disruption, delay) invalidates current routes and requires re-planning

Example:
- detect a regional weather disruption
- generate alternative routes that avoid the affected area
- evaluate which re-route option best balances cost and SLA

### Pattern B: fleet state -> route generation -> planning

```text
dispatch_request
|> &space.fleet.locate()
|> &space.route.route()
|> &reason.plan.plan()
```

Use this when:
- current fleet positions should inform route generation before action is selected

Example:
- locate available delivery vehicles
- generate candidate routes from nearest vehicle to destination
- build a dispatch plan

### Pattern C: route generation -> optimization -> explanation

```text
delivery_request
|> &space.route.route()
|> &space.route.optimize()
|> &space.route.explain()
```

Use this when:
- the system should generate, improve, and then justify a route in sequence

Example:
- generate an initial delivery route
- optimize for fuel cost and driver hours
- produce an explanation for the dispatcher

### Pattern D: memory -> route planning -> reasoning

```text
incident_context
|> &memory.graph.enrich()
|> &space.route.route()
|> &reason.argument.evaluate()
```

Use this when:
- prior operational context (past incidents, known constraints) should inform route selection before a decision is made

---

## 9. Architecture diagram

A simplified conceptual flow for `&space.route`:

```text
incoming request / constraint / forecast
              |
              v
      +-------------------+
      |   &space.route    |
      |                   |
      | route             |
      | optimize          |
      | explain           |
      +---------+---------+
                |
                v
      +-------------------+
      | route_plan        |
      | optimized_route   |
      | route_explanation |
      +---------+---------+
                |
                v
      +-------------------+
      | &reason.* /       |
      | &memory.* /       |
      | &space.* /        |
      | output            |
      +-------------------+
```

The capability's job is to turn movement requests and constraints into **actionable and explainable route intelligence**.

---

## 10. Example declaration

A concrete `ampersand.json` fragment:

```json
{
  "&space.route": {
    "provider": "geofleetic",
    "config": {
      "regions": ["us-east", "us-central"],
      "mode": "constraint-aware-routing"
    }
  }
}
```

A fuller declaration:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "RouteManager",
  "version": "0.1.0",
  "capabilities": {
    "&time.anomaly": {
      "provider": "auto",
      "need": "real-time anomaly detection over regional telemetry streams"
    },
    "&space.route": {
      "provider": "geofleetic",
      "config": {
        "regions": ["us-east", "us-central"],
        "mode": "constraint-aware-routing"
      }
    },
    "&reason.argument": {
      "provider": "auto",
      "need": "auditable route decision evaluation with governance-aware justification"
    }
  },
  "governance": {
    "hard": [
      "Never route through restricted zones without authorization",
      "Never exceed maximum allowable transit time for priority shipments"
    ],
    "soft": [
      "Prefer lower-cost routes when SLA compliance is not at risk"
    ],
    "escalate_when": {
      "confidence_below": 0.75,
      "hard_boundary_approached": true
    }
  },
  "provenance": true
}
```

An auto-resolved declaration using `&space.route`:

```json
{
  "&space.route": {
    "provider": "auto",
    "need": "route feasibility checks and optimization under regional constraints"
  }
}
```

---

## 11. Example API shape

A provider-specific API will vary, but a typical `route` request might look like:

```json
{
  "operation": "route",
  "input": {
    "origin": { "lat": 40.7128, "lon": -74.0060 },
    "destination": { "lat": 39.9526, "lon": -75.1652 },
    "constraints": {
      "avoid_regions": ["restricted-zone-3"],
      "max_transit_hours": 4,
      "vehicle_type": "standard"
    }
  }
}
```

Representative response:

```json
{
  "route_plan": {
    "route_id": "rt_20260315_001",
    "origin": { "lat": 40.7128, "lon": -74.0060 },
    "destination": { "lat": 39.9526, "lon": -75.1652 },
    "estimated_duration_hours": 2.1,
    "estimated_cost_usd": 48.50,
    "waypoints": [
      { "lat": 40.2301, "lon": -74.7699, "label": "interchange-17" }
    ],
    "constraints_satisfied": true
  }
}
```

An `optimize` request might look like:

```json
{
  "operation": "optimize",
  "input": {
    "route_plan": {
      "route_id": "rt_20260315_001",
      "origin": { "lat": 40.7128, "lon": -74.0060 },
      "destination": { "lat": 39.9526, "lon": -75.1652 },
      "waypoints": [
        { "lat": 40.2301, "lon": -74.7699, "label": "interchange-17" }
      ]
    },
    "optimize_for": ["cost", "travel_time"]
  }
}
```

Representative response:

```json
{
  "optimized_route": {
    "route_id": "rt_20260315_001_opt",
    "estimated_duration_hours": 1.9,
    "estimated_cost_usd": 41.20,
    "improvement": {
      "duration_reduction_pct": 9.5,
      "cost_reduction_pct": 15.1
    },
    "waypoints": []
  }
}
```

The protocol does not standardize this exact transport payload. It standardizes the capability contract.

---

## 12. Compatible providers

Representative compatible providers include:

- `geofleetic`
- custom route planning services
- logistics optimization backends exposed behind MCP-compatible surfaces
- vehicle routing problem (VRP) solvers with stable contract wrappers
- last-mile delivery platforms with route generation APIs
- infrastructure path selection systems

### Default ecosystem fit

The most natural default ecosystem example in this repository is:

- `geofleetic`

Why it fits:
- route-aware domain model with constraint handling
- optimization and explanation semantics built in
- strong compatibility with logistics, delivery, and dispatch use cases

The protocol stance remains:

> `&space.route` is the capability.
> `geofleetic` is one provider that may satisfy it.

---

## 13. Governance implications

Route decisions often have real operational and safety consequences, so governance matters.

### Common hard constraints

Examples:
- Never route through restricted or unsafe zones without authorization.
- Never exceed maximum allowable transit time for priority shipments.
- Never generate routes that violate vehicle weight, height, or hazmat restrictions.
- Never disclose route details outside authorized workflows.

### Common soft constraints

Examples:
- Prefer lower-cost routes when SLA compliance is not at risk.
- Prefer routes that minimize driver fatigue or hours-of-service pressure.
- Prefer fewer stops when delivery density allows consolidation.
- Prefer routes with established operational history over untested alternatives.

### Common escalation rules

Examples:
- escalate when no feasible route can be found under current constraints
- escalate when route cost exceeds budget thresholds
- escalate when a hard constraint is approached or violated
- escalate when optimization produces only marginal improvement
- escalate when route explanation reveals conflicting constraints

Representative governance block:

```json
{
  "governance": {
    "hard": [
      "Never route through restricted zones without authorization",
      "Never exceed maximum transit time for priority shipments"
    ],
    "soft": [
      "Prefer lower-cost routes when SLA compliance is not at risk"
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

Route decisions should participate in the provenance chain.

Representative provenance record:

```json
{
  "source": "&space.route",
  "provider": "geofleetic",
  "operation": "optimize",
  "timestamp": "2026-03-15T14:30:00Z",
  "input_hash": "sha256:4e8a...",
  "output_hash": "sha256:d31f...",
  "parent_hash": "sha256:9a77...",
  "mcp_trace_id": "groute-opt-118"
}
```

This matters because route context can strongly influence downstream action.

Provenance should help answer questions like:

- Why was this route chosen instead of the more direct path?
- Which constraints caused the route to change from the original plan?
- Which provider produced the route recommendation?
- Which upstream anomaly or fleet state led to the re-routing?
- What optimization criteria were applied and what tradeoffs resulted?

---

## 15. A2A-facing skills

A `&space.route` capability may advertise skills such as:

- `route-generation`
- `route-optimization`

These are useful when generating A2A-style agent cards, because they let an external coordination surface say more than "has routing awareness."

Instead, it can say the agent can:

- generate feasible route plans under constraints
- optimize routes for cost, time, or service objectives

---

## 16. MCP-facing implications

A declaration containing `&space.route` may compile into MCP-facing configuration for a compatible route intelligence provider.

That makes `&space.route` a good example of the protocol's overall claim:

- the declaration captures capability composition
- downstream tools can generate runtime config from that declaration

In other words:

> [&] declares the route intelligence capability
> MCP can carry the provider-facing integration

---

## 17. Research grounding

`&space.route` is supported by several overlapping research and systems traditions:

- vehicle routing and path planning
- combinatorial optimization and operations research
- logistics and supply chain management
- constraint satisfaction and constraint programming
- explainable AI and decision auditing
- multi-objective optimization
- spatial reasoning and geographic information systems

The important protocol-level insight is not that route optimization is new.

It is that **route intelligence should be explicit in the agent's capability declaration**, rather than buried in framework code or provider-specific prompts.

That explicitness enables:

- schema validation
- contract checking
- provider interchangeability
- governance-aware composition
- provenance-preserving decisions
- downstream MCP and A2A generation

---

## 18. Anti-patterns

### Anti-pattern 1: collapse route into fleet state
Fleet state answers where things are. Route answers how things get there. These are related but distinct interfaces.

### Anti-pattern 2: treat route optimization as a black box
If route decisions affect cost, SLA, or safety, the optimization should be explainable and auditable, not opaque.

### Anti-pattern 3: let reasoning guess routes from text
A reasoner may describe a plausible path and still be wrong about feasibility, cost, or constraint satisfaction.

### Anti-pattern 4: use route decisions without provenance
If a route recommendation changes the outcome, lineage should record which constraints, inputs, and provider produced it.

### Anti-pattern 5: skip explanation when routes change
When a route is re-planned due to new constraints, operators need to understand what changed and why. Route changes without explanation erode trust.

---

## 19. Practical guidance

Use `&space.route` when:

- the system must plan or evaluate paths from one location to another
- route decisions involve constraints that affect feasibility or cost
- routes must be explainable to operators, auditors, or downstream agents
- optimization should consider multiple objectives (cost, time, SLA, safety)

Prefer composing it with:

- `&time.*` when temporal signals constrain route feasibility or timing
- `&space.fleet` when current asset positions inform route generation
- `&space.geofence` when zone boundaries restrict available paths
- `&memory.*` when prior route history or incidents should influence planning
- `&reason.*` when route options must be evaluated before action

Common high-value compositions:

- `&time.anomaly` + `&space.route` + `&reason.argument`
- `&space.fleet` + `&space.route` + `&reason.plan`
- `&memory.graph` + `&space.route` + `&reason.argument`

---

## 20. Example scenarios

### Delivery routing under constraints
- receive delivery request with time window and vehicle constraints
- generate feasible route candidates
- optimize for cost and travel time
- explain selected route to dispatcher

### Constraint-reactive re-routing
- detect regional disruption (weather, closure, capacity limit)
- identify affected routes
- re-plan under updated constraints
- explain changes to affected operators

### Multi-stop service route planning
- receive set of service appointments across a territory
- generate initial route with stop ordering
- optimize for technician hours and travel distance
- justify stop ordering decisions

### Route auditing and compliance
- receive completed route for review
- explain why the route was selected over alternatives
- verify constraint satisfaction
- record provenance for regulatory compliance

---

## 21. Summary

`&space.route` is the [&] Protocol capability for **route intelligence and explainable navigation**.

It is the right capability when an agent needs to know:

- how to get from origin to destination under constraints
- how to improve a route for cost, time, or service objectives
- why a particular route was selected over alternatives
- how constraints and tradeoffs shaped the navigation decision
- how route decisions should be recorded for auditing and provenance

In one sentence:

> `&space.route` gives an agent a protocol-native way to generate, optimize, and explain paths through space.

---
