# Autonomous Systems: The Canonical [&] Use Case

**March 2026 · [&] Ampersand Box Design**

---

## Why autonomous vehicles and drones

The [&] Protocol was designed as a general composition layer for agent cognition. But not all applications exercise the protocol equally. Some agents need only memory and reasoning. Some need only tool connectivity. The protocol is useful in those cases, but it is not irreplaceable.

Autonomous military systems — robotic combat vehicles, drone swarms, manned-unmanned teams — are different. They exercise all five primitives simultaneously, under conditions where governance is not optional and disconnected operations are the baseline assumption. This document explains why, where the protocol fits in the stack, and where it does not.

---

## 1. Where [&] sits in the autonomy stack

The autonomous vehicle software stack has well-established layers. [&] does not replace any of them. It occupies a specific position between the operational data layer and the vehicle control layer.

```
┌─────────────────────────────────────────────────┐
│  Human Command                                   │
│  Mission objectives, rules of engagement,        │
│  commander's intent                              │
├─────────────────────────────────────────────────┤
│  Operational Data Layer                          │
│  Palantir TITAN/Maven/Gotham, JADC2 feeds,       │
│  intelligence fusion, ontology objects            │
├─────────────────────────────────────────────────┤
│  [&] Protocol — Cognitive Composition Layer      │
│  Capability declaration, typed pipelines,         │
│  governance constraints, κ-driven deliberation,  │
│  provenance chains                               │
├─────────────────────────────────────────────────┤
│  MCP / A2A                                       │
│  Tool invocation, agent-to-agent coordination    │
├─────────────────────────────────────────────────┤
│  Vehicle Autonomy Stack                          │
│  RTK, ROS2, PX4, navigation, obstacle avoidance, │
│  path planning, motor control                    │
├─────────────────────────────────────────────────┤
│  Hardware                                        │
│  Sensors (FLIR, LiDAR, radar, EO/IR), actuators, │
│  MANET radios, GPS/INS, APS                      │
└─────────────────────────────────────────────────┘
```

The data layer answers: *what is happening?* The control layer answers: *how do I move?* The [&] layer answers: *how should I think about what is happening, and what should I decide to do?*

That middle layer — structured cognition with governance — is what autonomous systems currently lack. Vehicle control stacks (RTK, ROS2) handle navigation. Intelligence platforms (Palantir Foundry, TITAN) handle data fusion. But the step between "here is what I know" and "here is what I should do" is either hardcoded in mission-specific logic or left to unstructured prompt engineering. [&] makes that step explicit, typed, and auditable.

---

## 2. Why all five primitives are load-bearing

Most agent applications use one or two [&] primitives meaningfully. An infrastructure monitor needs `&time.anomaly` and `&memory.graph`. A research agent needs `&memory` and `&reason`. The other primitives are present but not survival-critical.

Autonomous vehicles are the rare case where all five primitives are simultaneously essential and where failure in any one is catastrophic.

### `&memory.graph` — operational picture as agent memory

An autonomous vehicle's "memory" is not a vector store of past conversations. It is a structured knowledge graph of the operational environment: terrain features, threat positions, friendly force locations, no-go zones, previous engagement outcomes, supply routes, communication relay points.

In a Palantir-integrated system, this memory is the ontology itself. Palantir's Object Types (buildings, vehicles, units, routes) become the nodes. Link Types (threatens, observes, supplies) become the edges. The vehicle's `&memory.graph` capability binds to the Palantir Ontology via MCP, treating enterprise intelligence objects as its episodic and semantic memory.

This is not metaphorical. Palantir released Ontology MCP in 2025, exposing object types, action types, and query functions as MCP tools. An [&] declaration that binds `&memory.graph` to a Palantir Ontology MCP server is a concrete integration, not a theoretical one.

### `&time.anomaly` — threat detection through temporal intelligence

A vehicle that was stationary for six hours and begins moving toward a checkpoint. A radio signature that appears in a previously silent sector. A pattern-of-life deviation in a monitored area. These are temporal anomalies — deviations from established baselines that may indicate threats.

Palantir's streaming pipelines and TITAN's multi-INT fusion produce the raw temporal data. The `&time.anomaly` capability gives the vehicle the cognitive faculty to notice deviations and reason about them, not just log them. The distinction matters: logging is passive infrastructure; anomaly detection is active cognition that triggers downstream deliberation.

### `&space` — survival through spatial reasoning

No other agent application has spatial reasoning as a survival requirement. For autonomous vehicles, `&space` is the primitive that keeps the system alive:

- **Path planning**: navigating through contested terrain while minimizing exposure
- **Formation geometry**: maintaining tactical spacing in a convoy or swarm
- **Terrain masking**: using terrain features to avoid detection
- **Threat proximity**: evaluating distance to known and suspected threats
- **Sensor coverage**: understanding what the vehicle can and cannot observe

`&space.fleet` becomes `&space.formation` or `&space.tactical` in this domain — the same interface contract (regions, positions, routes, topology) applied to a context where spatial errors have kinetic consequences.

### `&govern` — telemetry, identity, and escalation as infrastructure

Governance in autonomous systems is not a policy overlay — it is survival infrastructure. A vehicle that cannot authenticate friendly forces, track its own operational telemetry, or enforce escalation policies is as compromised as one that cannot see.

`&govern.identity` ensures the vehicle can authenticate itself to friendly systems and verify the identity of entities it communicates with — critical in contested electromagnetic environments where spoofing is a standard tactic. `&govern.telemetry` provides the operational metrics pipeline: ammunition status, fuel state, sensor health, communication link quality. `&govern.escalation` codifies the conditions under which autonomous action defers to a human operator, and — crucially — what happens when that deferral is impossible because comms are down.

Unlike the governance *block* in `ampersand.json` (which expresses constraints as data), the `&govern` *primitive* makes governance a composable, provider-backed capability that participates in pipelines, satisfies contracts, and generates provenance records like any other capability.

### `&reason.deliberate` — engagement decisions under governance

This is where autonomous systems diverge most sharply from other agent applications.

An infrastructure agent that makes a bad scaling decision wastes money. An autonomous vehicle that makes a bad engagement decision causes casualties. The reasoning capability is not a nice-to-have — it is the component that determines whether the system operates within its rules of engagement or violates them.

`&reason.deliberate` in this context means: evaluate candidate actions against hard constraints, weigh competing soft preferences, estimate confidence, and determine whether to act autonomously or escalate to a human operator. That is the exact function DoD Directive 3000.09 requires of autonomous and semi-autonomous weapon systems.

---

## 3. Governance as constraint envelope

The [&] governance model maps directly onto the DoD's human control framework.

### DoD autonomy levels → [&] governance blocks

| DoD Framework | [&] Governance | Meaning |
|---|---|---|
| Human-in-the-loop (HITL) | `require_approval_for: ["engage"]` | Human authorizes each engagement |
| Human-on-the-loop (HOTL) | `autonomy_level: "supervised"`, `escalate_when: { confidence_below: 0.85 }` | System acts autonomously; human monitors and can abort |
| Human-out-of-the-loop (HOOTL) | `autonomy_level: "autonomous"` | System operates independently (not currently permitted for U.S. lethal systems) |

### Hard constraints as rules of engagement

Rules of engagement are not suggestions. They are inviolable constraints that define the legal and ethical boundaries of autonomous action. In [&], they are expressed as `hard` constraints:

```json
"hard": [
  "Never engage without positive target identification",
  "Respect no-fire zones as defined in operational picture",
  "Do not engage targets within 500m of declared civilian structures",
  "Cease engagement immediately on loss of target track"
]
```

These constraints are declarative data, not runtime code. They travel with the vehicle's `ampersand.json` declaration. They can be validated before deployment. They can be audited after action. They do not depend on a network connection to a policy server.

### Soft constraints as tactical preferences

Soft constraints express preferences that guide reasoning without creating inviolable boundaries:

```json
"soft": [
  "Prefer non-lethal response options when available",
  "Minimize exposure time in open terrain",
  "Conserve ammunition when resupply route is contested",
  "Prefer terrain-masked positions for observation"
]
```

### Escalation as the human-machine handoff

The `escalate_when` block defines the conditions under which the system defers to a human operator:

```json
"escalate_when": {
  "confidence_below": 0.85,
  "target_near_civilian_structure": true,
  "engagement_type": "lethal",
  "comms_degraded": false
}
```

The last condition is important. When communications are degraded — the baseline assumption for peer conflict in GPS-denied, EW-contested environments — escalation to a human may be impossible. The governance model must account for this explicitly rather than failing silently.

---

## 4. The disconnected operations problem

This is where [&]'s declarative architecture provides its strongest differentiation over cloud-dependent governance systems.

In a contested electromagnetic environment, autonomous vehicles will routinely lose communications with command nodes. When that happens:

- **Cloud-based policy engines** become unreachable. The vehicle has no governance.
- **Role-based permission systems** cannot authenticate. The vehicle has no authorization.
- **Human-in-the-loop gates** have no human to loop in. The vehicle has no approval authority.

An [&] declaration is different. The `ampersand.json` is compiled onboard before deployment. The constraint envelope — hard constraints, soft constraints, escalation conditions, autonomy level, action budgets — is local data. The vehicle does not need a network connection to know its rules of engagement.

When comms are lost, the governance model degrades gracefully:

1. `escalate_when` conditions that require human approval become unfulfillable
2. The autonomy level can be pre-configured to shift: `"comms_lost_fallback": "autonomous_within_hard_constraints"`
3. Hard constraints remain inviolable regardless of connectivity state
4. Provenance chains accumulate locally using SHA-256 hash linking
5. When comms restore, the full audit trail syncs — every decision, every constraint check, every provenance record

This is the Terraform analogy applied to governance: the plan is compiled ahead of time; execution happens locally; state syncs when possible.

---

## 5. Swarm governance through κ

Drone swarms present a governance problem that no existing framework addresses well: *which drones should coordinate with which other drones on which decisions?*

### The topology-driven answer

A drone swarm is a directed graph. Each drone is a node. Edges represent mutual influence: shared sensor coverage, overlapping threat exposure, communication links, formation dependencies. Run Tarjan's SCC analysis on this graph:

- **κ = 0 (DAG region)**: Drones operating independently — different sectors, no shared threats, no sensor overlap. These drones can act autonomously within their constraint envelopes. No coordination overhead. Fast.

- **κ ≥ 1 (SCC region)**: Drones with mutual influence — shared threat exposure, overlapping sensor fields, formation dependencies where one drone's action changes the tactical picture for others. These drones must deliberate collectively before acting. Their states are entangled; unilateral action by one affects all.

### Why this adapts in real-time

Static role hierarchies (leader/follower, master/slave) break when the leader is destroyed or when the communication topology changes. κ-driven governance adapts because it is computed from the current graph state:

- A drone that loses comms with its SCC drops to κ = 0 and falls back to its local constraint envelope
- A drone that enters a new sensor overlap zone joins an SCC and gains deliberation rights with the drones it now mutually influences
- Formation changes reconfigure the graph; governance reconfigures with it
- No central coordinator is required — each drone can compute its local SCC membership from its knowledge of the swarm topology

### The engagement coordination example

Consider four drones (A, B, C, D) approaching a target area:

- A and B have overlapping sensor coverage of the target → SCC (κ = 1)
- C is providing overwatch from a different angle, sensor coverage overlaps with A → joins the SCC (κ = 1)
- D is on a separate ISR mission 5km away → DAG (κ = 0)

The engagement decision involves A, B, and C deliberating — they share mutual influence over the tactical picture. D continues its ISR mission autonomously. If B is destroyed, the SCC is recomputed: A and C may still form an SCC, or they may fall to DAG status if their sensor coverage no longer overlaps.

This is not a routing heuristic. It is a governance principle: **deliberation rights derive from the topology of mutual influence**.

---

## 6. Manned-unmanned teaming (MUM-T)

The U.S. Army's vision for 2028-2030 includes M1E3 Abrams crews supervising 2-4 Robotic Combat Vehicles (RCVs) alongside small reconnaissance drones. This is a heterogeneous capability graph — different platforms with different sensors, different weapons, different movement capabilities, unified under a human supervisor.

[&] gives this composition a schema.

### The composition problem

Without a composition layer, the crew supervises each asset separately: one interface for the RCV-M, another for the recon drone, a third for their own vehicle systems. Cognitive load scales linearly with asset count.

With [&], the heterogeneous fleet is declared as a composed system:

```json
{
  "agent": "MUM-T_Section",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "palantir-ontology-mcp",
      "config": { "scope": "battalion_operational_picture" }
    },
    "&space.formation": {
      "provider": "rtk-formation-planner",
      "config": {
        "platforms": ["m1e3", "rcv-m-1", "rcv-m-2", "rq-11b"],
        "formation_doctrine": "bounding_overwatch"
      }
    },
    "&time.anomaly": {
      "provider": "titan-stream",
      "config": {
        "feeds": ["eo-ir", "radar", "sigint", "aps-threat"]
      }
    },
    "&reason.deliberate": {
      "provider": "deliberatic",
      "config": {
        "budget": "kappa",
        "engagement_doctrine": "3000.09_compliant"
      }
    },
    "&govern.identity": {
      "provider": "delegatic",
      "config": { "auth": "blue_force_tracker" }
    },
    "&govern.telemetry": {
      "provider": "delegatic",
      "config": { "streams": ["ammo", "fuel", "sensor_health", "comms_quality"] }
    },
    "&govern.escalation": {
      "provider": "delegatic",
      "config": { "comms_lost_fallback": "autonomous_within_hard_constraints" }
    }
  },
  "governance": {
    "hard": [
      "All lethal engagements require crew authorization",
      "RCVs do not advance beyond line of departure without crew command",
      "Cease fire on loss of positive target identification",
      "Respect no-fire zones from operational picture"
    ],
    "soft": [
      "RCVs take first contact before manned platforms",
      "Prefer terrain-masked advance routes",
      "Conserve RCV ammunition when resupply is >2 hours"
    ],
    "escalate_when": {
      "confidence_below": 0.8,
      "target_classification": "uncertain",
      "civilian_proximity": true,
      "engagement_type": "lethal"
    },
    "autonomy": {
      "level": "supervised",
      "heartbeat_seconds": 5,
      "budget": {
        "max_actions_per_hour": 20,
        "require_approval_for": ["engage", "advance_past_phase_line"]
      }
    }
  },
  "pipelines": {
    "threat_response": {
      "source_type": "sensor_fusion",
      "source_ref": "aps_radar_contact",
      "steps": [
        { "capability": "&time.anomaly", "operation": "detect" },
        { "capability": "&memory.graph", "operation": "enrich" },
        { "capability": "&space.formation", "operation": "evaluate_exposure" },
        { "capability": "&reason.deliberate", "operation": "recommend_action" },
        { "capability": "&govern.escalation", "operation": "evaluate" },
        { "capability": "&govern.telemetry", "operation": "emit" }
      ]
    }
  },
  "provenance": true
}
```

The pipeline tells the story: a sensor contact is detected (`&time.anomaly`), enriched with known intelligence (`&memory.graph`), evaluated for formation exposure (`&space.formation`), and fed into deliberation that produces an action recommendation (`&reason.deliberate`). The escalation policy is evaluated (`&govern.escalation`) — does this require crew approval? — and operational telemetry is emitted (`&govern.telemetry`). The crew sees the recommendation, the provenance chain, and the constraint evaluation — then approves or overrides.

### Supervisory ratio

The Army's near-term goal is 1:N control — one operator supervising 2-4 unmanned vehicles. The far-term goal (2030+) is supervisory control over 6-10 vehicles, with AI handling navigation, formation, and target detection while humans approve engagements.

[&]'s governance model supports this transition directly. As trust increases:

- `autonomy_level` shifts from `"supervised"` to `"autonomous_within_constraints"`
- `require_approval_for` narrows from `["engage", "advance", "reposition"]` to `["engage"]`
- `heartbeat_seconds` lengthens
- `max_actions_per_hour` increases

The same declaration format scales from tight supervision to high autonomy. The constraint envelope widens; the governance structure remains.

---

## 7. The Palantir integration

Palantir and [&] are complementary, not competitive. They occupy different layers of the same stack.

### What Palantir provides

- **Ontology**: structured representation of the operational environment — objects (vehicles, buildings, units), links (threatens, observes, supplies), properties (location, classification, movement vector)
- **TITAN**: multi-INT sensor fusion and AI-assisted targeting for long-range precision fires
- **Maven**: computer vision and ML for ISR data analysis — object detection, change detection, pattern-of-life
- **AIP**: generative AI for operational planning and intelligence analysis
- **Edge Ontology**: lightweight ontology runtime for mobile devices and drones

### What [&] provides

- **Cognitive architecture**: how the autonomous system reasons about ontology objects — not just storing them but deliberating over them
- **Governance as data**: constraint envelopes that travel with the vehicle and work offline
- **κ-driven deliberation**: topology-derived coordination for multi-vehicle decisions
- **Provenance**: hash-linked audit trail of every reasoning step, from sensor input to action recommendation

### The integration surface

Palantir's Ontology MCP server exposes objects and actions as MCP tools. [&] declarations compile into MCP configurations. The connection point is concrete:

```
Palantir Ontology Objects → Ontology MCP Server → MCP Tools
                                                      ↑
[&] Declaration → ampersand compose → MCP Config ─────┘
```

An [&]-declared agent binds `&memory.graph` to a Palantir Ontology MCP server. The agent's graph memory *is* the operational picture. When the agent runs `&memory.graph.enrich`, it is querying Palantir ontology objects through MCP. When it runs `&reason.deliberate`, it is reasoning over those objects under [&] governance constraints. When the crew reviews the recommendation, the provenance chain traces back through both layers.

### What neither system does alone

Palantir tells the vehicle what exists. [&] tells the vehicle how to think about what exists. Neither replaces the other:

- Palantir without [&]: the vehicle has intelligence data but no structured cognitive architecture for reasoning about it under governance constraints
- [&] without Palantir: the vehicle has a cognitive architecture but no operational data substrate to reason about
- Together: structured intelligence data flows through typed cognitive pipelines under declarative governance with full provenance

---

## 8. What [&] explicitly does not do

Maintaining credibility requires being precise about boundaries.

### Not vehicle control

[&] does not replace RTK, ROS2, PX4, or any motion planning stack. It does not compute trajectories, avoid obstacles, or control actuators. The `&space` primitive models spatial reasoning at the tactical/cognitive level — threat proximity, formation geometry, route evaluation — not at the control loop level.

### Not sensor processing

[&] does not perform computer vision, radar signal processing, FLIR image analysis, or automatic target recognition. Those are ML inference tasks that sit below the composition layer. Palantir Maven, ATLAS, and similar systems handle sensor processing. [&] consumes their outputs as typed inputs to cognitive pipelines.

### Not communications infrastructure

[&] does not replace MANET radios, satellite links, or tactical network protocols. It does not solve the bandwidth, latency, or jamming problems that constrain autonomous operations. It does benefit from its declarative architecture when communications fail — the governance model works offline — but it does not provide the communications themselves.

### Not a targeting system

[&] does not compute firing solutions, weapon-target pairings, or ballistic trajectories. TITAN and similar systems handle targeting. [&]'s `&reason.deliberate` capability evaluates whether an engagement is appropriate under governance constraints — a cognitive and governance function, not a fire control function.

### Not FPV drone control

First-person-view combat drones are human-piloted with no autonomous cognition. They do not need a cognitive architecture. [&] applies to autonomous and semi-autonomous systems, not teleoperated ones.

---

## 9. Platform applicability

Not every military autonomous system benefits equally from [&]. The protocol is most valuable where autonomous cognition and governance are both present and critical.

| System | Autonomy Level | [&] Relevance | Why |
|---|---|---|---|
| **RCV-Medium** | Level 3 (supervised autonomous) | **High** | All five primitives active; governance is engagement-critical; designed for MUM-T |
| **RCV-Light** | Level 2-3 | **High** | Armed scout role requires spatial reasoning + engagement governance |
| **Drone swarms** | Level 3-4 | **High** | κ-driven swarm governance; multi-vehicle deliberation; disconnected ops |
| **M1E3 (as MUM-T hub)** | N/A (manned) | **Medium** | Orchestration declaration for supervised unmanned assets |
| **Loitering munitions** (Switchblade 600) | Level 2 | **Medium** | Governance constraints on terminal engagement; simpler cognitive needs |
| **Recon UAS** (SRR program) | Level 2 | **Low-Medium** | Primarily ISR; `&space` and `&time` useful, `&reason.deliberate` less critical |
| **Counter-UAS** (Coyote) | Level 3 (defensive) | **Low** | Time-critical intercept; reaction speed > deliberation depth |
| **Perimeter robots** (Ghost V60) | Level 2 | **Low** | Patrol + alert; governance model is simple; fewer competing constraints |
| **FPV drones** | Level 1 (teleoperated) | **None** | No autonomous cognition |
| **Logistics robots** | Level 2-3 | **Low** | Navigation autonomy but no engagement governance |

The pattern: [&] value increases with autonomy level × governance complexity × number of simultaneously active cognitive primitives.

---

## 10. The provenance requirement

Military autonomous systems will face legal and ethical scrutiny for every engagement decision. The question "why did the system do that?" will be asked by JAG officers, congressional committees, and international bodies.

[&]'s hash-linked provenance chains provide a structured answer:

```
provenance_record_1:
  capability: "&time.anomaly"
  operation: "detect"
  input_hash: "sha256:a3f8..."
  output_hash: "sha256:7c2e..."
  timestamp: "2026-03-24T14:23:07Z"
  result: "anomaly_detected: vehicle_movement_deviation"

provenance_record_2:
  capability: "&memory.graph"
  operation: "enrich"
  parent_hash: "sha256:7c2e..."
  input_hash: "sha256:7c2e..."
  output_hash: "sha256:9b1d..."
  result: "enriched_with: known_hostile_unit_marker"

provenance_record_3:
  capability: "&reason.deliberate"
  operation: "recommend_action"
  parent_hash: "sha256:9b1d..."
  input_hash: "sha256:9b1d..."
  output_hash: "sha256:4e5f..."
  governance_check: {
    "hard_constraints_satisfied": true,
    "soft_constraints_applied": ["prefer_non_lethal"],
    "confidence": 0.91,
    "escalation_triggered": false
  }
  result: "recommend: observe_and_track"
```

Each record is hash-linked to its predecessor. The chain is tamper-evident. It can be replayed, audited, and presented as evidence that the system operated within its constraint envelope. This is not logging — it is a protocol-level requirement for explainable autonomous action.

---

## Summary

Autonomous military systems are the canonical [&] use case because they uniquely require:

1. **All five cognitive primitives simultaneously** — memory, reasoning, time, space, and governance are each survival-critical
2. **Governance as a structural requirement** — not optional, not aspirational, legally mandated
3. **Disconnected operations** — the governance model must work without network connectivity
4. **Multi-vehicle coordination** — κ-driven topology governance for swarms and MUM-T
5. **Full auditability** — every decision must be explainable after the fact
6. **Graceful autonomy scaling** — from tight supervision to high autonomy as trust increases

The protocol does not replace vehicle control stacks, sensor processing, communications infrastructure, or targeting systems. It occupies the cognitive composition layer between "what do I know" and "what should I do" — and it makes that layer explicit, typed, governable, and auditable.

That is the missing layer for autonomous systems.

---

*[&] Ampersand Box Design · ampersandboxdesign.com · Apache 2.0*
