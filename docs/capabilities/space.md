# `&space`: Spatial Intelligence for Agents

The `&space` capability family represents an agent's ability to reason about **where things are, how they move, how regions relate to one another, and what actions are valid in a spatial context**.

In the [&] Protocol, `&space` is one of the four core cognitive primitives:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

Spatial capability matters whenever an agent operates over fleets, maps, routes, regions, geofences, topologies, facilities, service territories, supply chains, or any system where location and position change what a valid decision looks like.

---

## Why `&space` exists as a first-class primitive

A large number of agents fail in subtle ways because they treat the world as if it were only text plus tools.

That is often enough for toy demos, but it breaks down quickly in real systems.

A support agent may need to know which warehouse serves a customer.
A fleet agent may need to know which vehicles are inside a region.
An infrastructure agent may need to know which datacenter cluster is affected by an incident.
A delivery agent may need to know whether a route crosses a restricted area.
A security or compliance agent may need to know whether data or assets entered a prohibited zone.

Those are not just "tool calls." They are spatial questions.

Treating spatial intelligence as a first-class capability allows the protocol to express:

- that an agent has spatial awareness at all
- what kind of spatial awareness it has
- which provider implements it
- how it composes with memory, time, and reasoning
- what types it accepts and produces in a pipeline

Without `&space`, spatial reasoning tends to be hidden inside ad hoc prompt logic or application-specific glue code. The result is architecture that looks plausible but is difficult to validate, govern, or reuse.

---

## What `&space` means in the protocol

At the protocol level, `&space` is not a vendor, map service, or database.

It is a **capability interface**.

That means:

- `&space.fleet` is a protocol capability
- `geofleetic` is one provider that may satisfy it
- another provider could also satisfy `&space.fleet` if it implements the same contract

This separation is important.

If spatial intelligence were modeled only as provider names, then architecture would collapse into product branding. By modeling `&space` as an interface family, the protocol stays portable.

---

## Common `&space` subtypes

The current protocol direction suggests several useful subtype patterns.

### `&space.fleet`

Represents awareness of distributed assets, vehicles, units, nodes, or regions as a coordinated fleet-like system.

Typical concerns:

- region occupancy
- asset distribution
- nearest available unit
- affected-region lookup
- current fleet state
- capacity by territory

This is the subtype most relevant to logistics, dispatch, field operations, and infrastructure regions.

### `&space.route`

Represents route computation, path constraints, spatial transitions, and route optimization.

Typical concerns:

- shortest or cheapest path
- route feasibility
- route recomputation
- path explanation
- route impact under changing conditions

This subtype matters when sequence through space is more important than current static position.

### `&space.geofence`

Represents boundary-aware spatial logic.

Typical concerns:

- enter/exit events
- restricted zones
- compliance zones
- operating boundaries
- service areas
- event-triggered actions based on region membership

This subtype is useful whenever boundary conditions affect policy or action.

### Future subtype candidates

As the protocol evolves, additional spatial subtypes may emerge, for example:

- `&space.topology`
- `&space.facility`
- `&space.coverage`
- `&space.territory`

The protocol should stay conservative at the primitive level and extensible at the subtype level.

---

## What problems `&space` solves

`&space` gives the protocol a standard place to express capabilities like:

- finding where an event occurred
- mapping impact to regions or zones
- connecting a decision to real-world or logical geography
- constraining actions by allowed locations
- ranking options by distance, route cost, or region state
- enriching a decision with local spatial context

These are especially important when spatial context changes the meaning of the same underlying event.

Example:

An anomaly in CPU usage means something very different if it affects:

- one isolated test node
- every production node in `us-east`
- a route-optimization cluster near a major logistics hub
- a restricted compliance boundary

The anomaly itself may be temporal. The business meaning often becomes spatial.

That is why `&space` composes naturally with `&time`.

---

## Cognitive role of `&space`

A useful way to think about the four primitives is:

- `&memory` stores and recalls prior structure
- `&reason` evaluates and decides
- `&time` models change and sequence
- `&space` localizes state and action

In practice, `&space` helps answer:

- Where is this happening?
- What else is nearby or inside the same boundary?
- What region, route, zone, or topology is affected?
- What actions are allowed in this location?
- How does location change priority or response?

This makes `&space` an essential primitive for situated agents.

---

## Typical providers

The protocol does not require one provider, but a few provider patterns are common.

### `geofleetic`

A natural example provider for `&space.fleet`.

This kind of provider may expose:

- region state
- fleet distribution
- geofencing
- location enrichment
- affected-region queries

### GIS and geospatial databases

A geospatial database or service can satisfy parts of `&space` if it exposes the right contract.

Examples might include systems built around:

- PostGIS
- custom geospatial indexes
- spatial event stores
- topology services

### Routing engines

A routing engine may satisfy parts of `&space.route`.

What matters is not the brand name, but whether the implementation satisfies the protocol contract for that subtype.

### Custom domain-specific spatial systems

A warehouse graph, datacenter topology model, maritime route service, or airspace constraint system could all act as `&space` providers if they are wrapped behind the expected capability surface.

---

## Example declaration

A simple spatial capability declaration in `ampersand.json` might look like this:

    {
      "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
      "agent": "FleetManager",
      "version": "0.1.0",
      "capabilities": {
        "&space.fleet": {
          "provider": "geofleetic",
          "config": {
            "regions": ["us-east", "us-central"],
            "mode": "regional-capacity-awareness"
          }
        }
      },
      "provenance": true
    }

A goal-driven variant might use auto-resolution:

    {
      "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
      "agent": "RouteCoordinator",
      "version": "0.1.0",
      "capabilities": {
        "&space.route": {
          "provider": "auto",
          "need": "regional route optimization with compliance boundaries"
        }
      },
      "governance": {
        "infer_from_goal": true
      },
      "provenance": true
    }

---

## Example contract shape

A capability contract for `&space.fleet` might express operations like these:

    {
      "capability": "&space.fleet",
      "operations": {
        "locate": { "in": "asset_query", "out": "location_set" },
        "enrich": { "in": "context", "out": "spatial_context" },
        "capacity": { "in": "region_query", "out": "capacity_snapshot" }
      },
      "accepts_from": ["&time.*", "&memory.*", "raw_data"],
      "feeds_into": ["&reason.*", "&memory.*", "output"],
      "a2a_skills": ["fleet-state-enrichment", "regional-capacity-lookup"]
    }

The point is not that every provider must use exactly these names.

The point is that spatial capability should expose:

- explicit operations
- explicit input/output types
- explicit compatibility boundaries

That is what makes composition validateable.

---

## Example pipelines involving `&space`

### Temporal event localized spatially

A common flow is:

    stream_data
      |> &time.anomaly.detect()
      |> &space.fleet.enrich()
      |> &reason.argument.evaluate()

Interpretation:

1. detect anomalies
2. map those anomalies to affected regions or assets
3. reason over the enriched operational context

### Memory + spatial context

Another common pattern is:

    incident_context
      |> &memory.graph.enrich()
      |> &space.geofence.enrich()
      |> &reason.argument.evaluate()

Interpretation:

1. retrieve similar prior incidents
2. determine whether current assets or actions intersect constrained zones
3. reason under both historical and spatial constraints

### Route-aware planning

A route-sensitive planning flow may look like:

    delivery_request
      |> &space.route.enrich()
      |> &time.forecast.enrich()
      |> &reason.plan.evaluate()

Interpretation:

1. produce route options or route context
2. enrich with temporal expectation such as demand or congestion window
3. select or evaluate a plan

---

## How `&space` composes with the other primitives

### `&space` + `&memory`

Memory helps answer what happened before.
Space helps answer where it is happening now.

Together they support questions like:

- Have we seen incidents like this in this region?
- Which routes historically fail under these conditions?
- Which service zones tend to exceed capacity after similar events?

This pairing is especially strong for historical localization.

### `&space` + `&time`

Time detects sequence, trend, anomaly, or forecast.
Space localizes the effect.

Together they support questions like:

- Which region is drifting toward overload?
- Where are anomalies clustering over time?
- Which route becomes invalid during a forecasted demand spike?

This pairing is essential for operational and logistics agents.

### `&space` + `&reason`

Spatial context often changes which decisions are acceptable.

Reasoning without spatial awareness can choose actions that are technically coherent but operationally invalid.

Together they support questions like:

- Is scaling in this region allowed under policy?
- Which region should receive rerouted capacity?
- Which route balances service level and compliance risk?

### `&space` + `&memory` + `&time` + `&reason`

This is the full composition story for many real systems:

- memory gives history
- time gives dynamics
- space gives localization
- reason gives decision logic

That combination is why the protocol models all four primitives rather than reducing everything to one generic intelligence bucket.

---

## Governance implications of `&space`

Spatial systems often have strong governance requirements.

Examples:

- never route assets through a restricted zone
- never expose private location data outside authorized context
- always escalate when operations cross a jurisdictional boundary
- prefer routes that remain inside approved service areas
- prefer region-local action over cross-region action when confidence is low

This makes `&space` especially relevant to declarative governance.

A governance block might include rules like:

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

The protocol's value here is that spatial constraints become portable data, not hidden application logic.

---

## Provenance implications of `&space`

Spatial enrichment should be provenance-aware.

If an agent reasons over spatial context, a provenance chain should preserve facts like:

- which spatial capability produced the region mapping
- which provider supplied the spatial enrichment
- which operation was called
- which input led to the spatial result
- what downstream reasoning consumed that result

That is important for questions like:

- Why did the agent choose `us-east` over `us-central`?
- Why did the system reject this route?
- Which geofence triggered escalation?
- Which provider determined regional capacity?

Spatial claims can have major operational consequences, so they should be auditable.

---

## Design patterns for `&space`

### Pattern 1: Spatial enrichment before reasoning

Good when the decision depends on location-aware context.

Example:
detect first, localize second, reason third.

### Pattern 2: Boundary validation before execution

Good for compliance and operational safety.

Example:
check geofence or route legality before the planner or executor commits an action.

### Pattern 3: Region-aware memory lookup

Good when similarity depends on both event type and location.

Example:
retrieve prior incidents from the same facility type, same region class, or same route family.

### Pattern 4: Spatial fallback routing

Good when a preferred route or region becomes invalid.

Example:
route planner requests an alternative region or path under governance constraints.

---

## Anti-patterns

### Anti-pattern 1: Treating space as just metadata

If location meaningfully changes action, `&space` should be modeled explicitly, not buried in arbitrary JSON fields.

### Anti-pattern 2: Collapsing all spatial problems into one provider call

Route planning, geofencing, and fleet-state enrichment are related but not identical. Subtypes exist to keep those concerns distinct.

### Anti-pattern 3: Letting reasoners infer geography from raw text alone

A reasoner may be excellent at explanation and still be a poor source of authoritative spatial state.

### Anti-pattern 4: Ignoring provenance for location-sensitive decisions

Spatial decisions without lineage are hard to debug and risky to audit.

---

## How `&space` should evolve

The protocol should keep `&space` simple at the primitive level and expressive at the subtype and contract level.

That suggests a few healthy directions:

- preserve `&space` as a stable top-level primitive
- allow subtypes to evolve as use cases become clearer
- keep providers separate from capabilities
- encourage typed contracts instead of loose "map" outputs
- expand examples and registry entries only when grounded in real use cases

A good `&space` ecosystem is not one with the most subtype names. It is one where spatial capability is explicit, composable, and trustworthy.

---

## Practical examples in this repository

The protocol repository already points toward several spatially relevant examples:

- `&space.fleet` in infrastructure and fleet-oriented declarations
- provider patterns such as `geofleetic`
- composition with `&time.anomaly` and `&reason.argument`

As the docs hub expands, useful next additions would include:

- a route-planning example declaration
- a geofence/compliance example
- a contract artifact for `&space.fleet`
- registry entries for additional spatial providers
- diagrams showing `&space` composition with time and reason

---

## Summary

`&space` is the protocol's answer to the question:

**How does an agent represent and reason about where things are?**

It matters because many real agent systems are not purely textual or purely symbolic. They are situated.

`&space` makes spatial intelligence:

- explicit in the declaration
- separable from providers
- contract-aware
- composable with memory, time, and reason
- governable
- provenance-aware
- compilable into downstream agent artifacts

If `&memory` helps the agent remember,
and `&reason` helps it decide,
and `&time` helps it understand change,

then `&space` helps it stay grounded in the world the decision actually affects.
