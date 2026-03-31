# [&] Ecosystem Overview — How Everything Ties Together

**March 2026 · [&] Ampersand Box Design**

---

## The problem this ecosystem solves

Building a production AI agent today requires assembling 6-10 disconnected systems: a memory backend, an orchestration framework, a governance layer, an observability stack, a deployment platform, an identity system, a testing framework, and a distribution channel. Each is a separate vendor, separate API, separate mental model.

The [&] ecosystem is a **vertically integrated but open portfolio** where every product is designed to compose with every other product through a shared protocol layer. You can use any single product standalone — but when you use them together, you get typed composition, shared governance, and end-to-end provenance that no mix-and-match stack can provide.

---

## The five cognitive primitives

Everything in the ecosystem maps to five primitive capability domains:

| Primitive | Question it answers | Products that implement it |
|-----------|-------------------|---------------------------|
| `&memory` | **What** does the agent know? | Graphonomous (agent-learned), BendScript (human-curated) |
| `&reason` | **How** does the agent decide? | Deliberatic (argumentation), AgenTroMatic (orchestration) |
| `&time` | **When** do things happen? | TickTickClock (anomaly, forecast, pattern) |
| `&space` | **Where** are things? | GeoFleetic (fleet, route, geofence) |
| `&govern` | **Who** is acting, under what rules, at what cost? | Delegatic (policy), OpenSentience (enforcement), FleetPrompt (identity) |

---

## The twelve products and how they connect

### Layer 1: Protocol Foundation

#### [&] Protocol (AmpersandBoxDesign)
**Role:** The composition layer — defines how capabilities compose into coherent agents.

The protocol is the shared language. It provides:
- `ampersand.json` — the canonical agent declaration format
- Capability contracts — typed operation signatures with adjacency rules
- JSON Schema validation — machine-checkable declarations
- Pipeline validation — type-safe composition before deployment
- MCP/A2A generation — compile declarations into runtime artifacts

Every other product in the ecosystem either **produces**, **consumes**, or **validates** `ampersand.json` declarations.

```
[&] Protocol
├── consumed by: Agentelic (build input), FleetPrompt (manifest validation)
├── produced by: SpecPrompt (export), Agentelic (build output)
├── validated by: OpenSentience (deployment gate), Delegatic (policy check)
└── compiled into: MCP configs, A2A agent cards
```

#### SpecPrompt
**Role:** The behavioral specification standard — defines what agents do before they're built.

SpecPrompt provides:
- SPEC.md format with formal PEG grammar
- Acceptance test criteria (machine-parseable `Given X → Y` assertions)
- Bidirectional mapping to `ampersand.json` (capabilities ↔ spec sections)
- ADL interoperability for cross-ecosystem portability
- Validation CLI and MCP tools

```
SpecPrompt
├── consumed by: Agentelic (build pipeline input)
├── validated against: [&] Protocol (ampersand_ref field)
├── published to: FleetPrompt (spec linkage in manifests)
└── referenced by: OpenSentience (permission derivation from spec)
```

---

### Layer 2: Memory & Knowledge

#### Graphonomous
**Role:** The agent-side continual learning engine — agents build knowledge automatically from experience.

Graphonomous provides:
- Typed knowledge graph (episodic, semantic, procedural, temporal, outcome, goal nodes)
- κ-routing (topological cycle detection for deliberation vs. fast-path)
- Consolidation cycles (fast/medium/slow/glacial timescales)
- 15+ MCP tools for graph operations
- SQLite (edge) + PostgreSQL (server) with vector search

```
Graphonomous
├── provides: &memory.graph, &reason.deliberate, &reason.attend
├── consumes: outcomes from all other products (learn_from_outcome)
├── feeds: every agent's retrieval context
├── stores: cross-project learnings, decisions, outcomes
└── referenced by: Delegatic (goal_id), AgenTroMatic (feedback loop)
```

#### BendScript
**Role:** The human-side knowledge graph editor — humans build knowledge visually on a canvas.

BendScript provides:
- Visual canvas with force-directed physics and fractal Stargates
- AI-powered graph synthesis (4 tiers of topology-aware generation)
- KAG server (Knowledge Augmented Generation) via MCP and REST
- Multi-tenant workspaces with Supabase RLS

```
BendScript
├── provides: &memory.graph (human-curated knowledge)
├── complements: Graphonomous (agent-learned knowledge)
├── consumed by: any agent via MCP (search_nodes, traverse_path, query_graph)
├── feeds: domain-specific knowledge into agent reasoning pipelines
└── exports: JSON, Markdown, Mermaid for portability
```

**Why two memory products?** Graphonomous is what the agent learns from experience. BendScript is what humans curate from expertise. Agents can query both in a single pipeline:

```
query |> &memory.graph[bendscript].search() |> &memory.graph[graphonomous].enrich() |> &reason.argument.evaluate()
```

---

### Layer 3: Reasoning & Orchestration

#### Deliberatic
**Role:** The formal argumentation protocol — evidence-based multi-agent debate with constitutional guardrails.

Deliberatic provides:
- Dung/Potyka argumentation framework with graded semantics
- Constitutional hard/soft constraints
- Domain-aware ELO reputation with calibration tracking
- BFT consensus (3f+1 quorum) for conflict resolution
- Merkle-chained evidence logs

```
Deliberatic
├── provides: &reason.argument, &reason.vote
├── consumed by: AgenTroMatic (deliberation engine)
├── fed by: Delegatic (constitutions flow from policy trees)
├── produces: verdicts, evidence chains, reputation updates
└── stores evidence in: Graphonomous (knowledge graph)
```

#### AgenTroMatic
**Role:** The automatic deliberation engine — multi-agent task orchestration with reputation-weighted routing.

AgenTroMatic provides:
- 7-phase GenStateMachine (bid → overlap → negotiate → elect → execute → commit → reputation)
- Ra (Raft) consensus for distributed agreement
- Real-time Observatory (Phoenix LiveView)
- Per-capability reputation with trend detection

```
AgenTroMatic
├── provides: &reason.deliberate (multi-agent orchestration)
├── wraps: Deliberatic (argumentation), A2A (agent communication)
├── governed by: Delegatic (task routing policies)
├── feeds outcomes to: Graphonomous (learning loop)
└── observable via: &govern.telemetry (deliberation events)
```

---

### Layer 4: Temporal & Spatial Intelligence

#### TickTickClock
**Role:** The temporal intelligence engine — anomaly detection, forecasting, and pattern recognition on time-series streams.

TickTickClock provides:
- SSM-based anomaly detection (Mamba architecture, with EMA+Z-score fallback)
- Multi-timescale memory (fast/medium/slow/glacial consolidation)
- Spectral pattern recognition (FFT, autocorrelation, motif discovery)
- Delta-CRDT replication for edge deployment

```
TickTickClock
├── provides: &time.anomaly, &time.forecast, &time.pattern
├── composes with: GeoFleetic (&time |> &space — "when + where")
├── feeds anomalies to: Graphonomous (temporal knowledge), AgenTroMatic (triggers)
├── governed by: Delegatic (compute budgets), OpenSentience (autonomy levels)
└── degrades gracefully: SSM → EMA+Z-score when compute budget exceeded
```

#### GeoFleetic
**Role:** The spatial intelligence layer — digital twins, fleet tracking, federated learning, and route optimization.

GeoFleetic provides:
- Spatial digital twins (GenServer per asset with Delta-CRDT sync)
- GNN-based route optimization
- Geofencing engine (Tile38 or SQLite-first)
- Federated learning (LoRA adapters without EXLA)

```
GeoFleetic
├── provides: &space.fleet, &space.route, &space.geofence
├── composes with: TickTickClock (&space + &time — "where + when")
├── feeds spatial conflicts to: Deliberatic (dispute resolution)
├── governed by: Delegatic (geofence access control)
└── enriches: Graphonomous with spatial knowledge nodes
```

**Why TickTickClock + GeoFleetic compose:** A delivery demand forecast (`&time.forecast`) + regional fleet capacity (`&space.fleet.capacity()`) + route optimization (`&space.route.optimize()`) is a pipeline no single product can provide. The [&] Protocol makes this composition typed and validated.

---

### Layer 5: Governance & Runtime

#### Delegatic
**Role:** The governance policy engine — monotonic policy inheritance across org hierarchies.

Delegatic provides:
- Hierarchical org tree with monotonic policy merge
- Budget fields: `max_tokens_per_task`, `max_cost_usd_per_period`, etc.
- Boolean capabilities (AND down tree), numeric limits (MIN down tree)
- Allow-lists (INTERSECTION), deny-lists (UNION)
- Immutable audit log (Broadway pipeline)

```
Delegatic
├── provides: policy source for &govern.telemetry.budget_check()
├── consumed by: OpenSentience (runtime enforcement), FleetPrompt (install gate)
├── stores: org_id references to Graphonomous goal_id nodes
├── feeds constitutions to: Deliberatic (hard/soft constraints)
└── enforces: budget limits across all [&] capabilities
```

#### OpenSentience
**Role:** The runtime enforcement layer — 8 cognitive protocols that govern agent behavior at runtime.

OpenSentience provides:
- OS-001: Continual Learning (implemented by Graphonomous)
- OS-002: κ-Routing (implemented by Graphonomous)
- OS-003: Deliberation Orchestrator (implemented by AgenTroMatic)
- OS-004: Attention Engine (implemented by Graphonomous)
- OS-005: Model Tier Adaptation (hardware-adaptive budgets)
- OS-006: Agent Governance Shim (permission engine, lifecycle, autonomy)
- OS-007: Adversarial Robustness (5 threat categories, defenses)
- OS-008: Agent Harness (pipeline enforcement, quality gates, sprint contracts)

```
OpenSentience
├── provides: &govern.escalation, &govern.identity, &govern.telemetry (runtime)
├── enforces: Delegatic policies at runtime
├── governs: all agents deployed via Agentelic/FleetPrompt
├── implements: OS-006 (governance shim) and OS-008 (harness) directly
└── defines: research protocols that other products implement
```

---

### Layer 6: Build, Deploy, & Distribute

#### Agentelic
**Role:** The spec-driven agent builder — from SPEC.md to deployed agent in 4 stages.

Agentelic provides:
- 4-stage build pipeline: PARSE → GENERATE → COMPILE → TEST
- Deterministic testing DSL with 7 assertion types
- 7 MCP tools (agent_create, agent_build, agent_test, agent_deploy, etc.)
- Deployment gates: spec validation → test pass → approval → governance check

```
Agentelic
├── consumes: SpecPrompt SPEC.md + [&] ampersand.json
├── produces: built, tested, deployable agent artifacts
├── deploys to: OpenSentience (runtime), WebHost.Systems (hosting)
├── publishes to: FleetPrompt (marketplace)
└── governed by: Delegatic (deployment approval), &govern.identity (registration)
```

#### FleetPrompt
**Role:** The open agent marketplace — publish, discover, and deploy agents in one click.

FleetPrompt provides:
- Manifest-first registry with machine-readable agent descriptions
- Trust scores (30% test + 25% spec + 25% usage + 20% audit)
- One-click install: permission review → Delegatic check → OpenSentience deploy
- Fork system for customization and republishing

```
FleetPrompt
├── consumes: Agentelic build artifacts, SpecPrompt specs
├── validates against: [&] Protocol schema
├── registers: &govern.identity for published agents
├── gates installs via: Delegatic (policy check)
├── deploys to: OpenSentience (one-click)
└── connects to: Graphonomous (on deployment)
```

#### WebHost.Systems
**Role:** The hosting infrastructure — managed BEAM nodes for the Elixir products.

WebHost.Systems provides:
- Convex backend with Vite/React/Clerk frontend
- Managed hosting for Graphonomous, TickTickClock, GeoFleetic, etc.
- Isolated BEAM nodes per tenant
- The operational substrate the rest of the ecosystem runs on

---

## The full lifecycle

Here's how an agent goes from idea to production across the ecosystem:

```
1. SPECIFY     SpecPrompt SPEC.md          "What should this agent do?"
       ↓
2. DECLARE     [&] ampersand.json          "What capabilities does it need?"
       ↓
3. BUILD       Agentelic pipeline           PARSE → GENERATE → COMPILE → TEST
       ↓
4. PUBLISH     FleetPrompt marketplace      Manifest + trust score + identity
       ↓
5. DEPLOY      OpenSentience runtime        Permission check + autonomy level
       ↓
6. OPERATE     Graphonomous + &govern       Continual learning + governance
       ↓
7. GOVERN      Delegatic policies           Budget, identity, escalation
       ↓
8. LEARN       Graphonomous outcomes        Confidence updates, consolidation
       ↓
9. IMPROVE     Feed back to SPEC.md         Close the loop
```

Steps 6-9 form a continuous cycle. The agent learns from outcomes, governance enforces bounds, and learnings feed back into spec revisions. This is the same SCC (strongly connected component) structure that κ-routing detects at the graph level — here operating at the organizational level.

---

## Cross-product data flows

### Governance flow (top-down)
```
Delegatic org policy tree
  → OpenSentience runtime enforcement (OS-006)
    → OS-008 harness pipeline enforcement (retrieve-before-act, quality gates)
    → &govern.telemetry.budget_check() per operation
    → &govern.escalation.escalate() when thresholds crossed
    → &govern.identity.verify() on agent collaboration
```

### Knowledge flow (bottom-up)
```
Agent actions produce outcomes
  → Graphonomous learn_from_outcome() updates confidence
    → Consolidation prunes low-confidence, reinforces high-confidence
      → Retrieval context improves next decision
```

### Build flow (left-to-right)
```
SpecPrompt SPEC.md + [&] ampersand.json
  → Agentelic PARSE → GENERATE → COMPILE → TEST
    → FleetPrompt publish (manifest + trust score)
      → OpenSentience deploy (permission + autonomy)
```

### Deliberation flow (circular)
```
Task arrives → AgenTroMatic collects bids
  → Deliberatic argumentation (evidence + reputation)
    → Ra consensus (Raft quorum)
      → Execution + outcome
        → Reputation update → better routing next time
```

---

## What makes this ecosystem different

### 1. Protocol-first, not framework-first
Most agent ecosystems start with a framework and add governance later. [&] starts with a typed protocol and derives everything else from it. This means governance, provenance, and composition are structural — not bolted on.

### 2. Five primitives, not one intelligence bucket
By decomposing cognition into memory, reasoning, time, space, and governance, the ecosystem avoids the "one model to rule them all" trap. Each primitive has dedicated infrastructure optimized for its concern.

### 3. Monotonic governance
Delegatic's monotonic policy inheritance (children can only tighten parent restrictions) is a structural guarantee, not a runtime check. This makes governance composable across org hierarchies.

### 4. κ-driven deliberation rights
Governance participation is earned by feedback topology, not assigned by role. Nodes that can't influence each other have no structural basis for joint deliberation. This prevents both unnecessary committee overhead and unsafe unilateral action.

### 5. Continuous learning as infrastructure
Graphonomous isn't a feature — it's the shared memory substrate for the entire ecosystem. Every product can store learnings and retrieve context. Knowledge compounds across products, not within silos.

### 6. Open core with typed composition
Each product is independently useful. But when composed through the [&] Protocol, you get typed pipelines, shared governance, and end-to-end provenance that no mix-and-match stack can provide.

---

## Composition matrix

Which products connect to which:

| | Graphonomous | BendScript | Deliberatic | AgenTroMatic | TickTickClock | GeoFleetic | Delegatic | OpenSentience | Agentelic | FleetPrompt | SpecPrompt | WebHost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Graphonomous** | — | complement | evidence store | feedback loop | anomaly knowledge | spatial knowledge | goal_id refs | OS-001,002,004 | memory integration | connect on deploy | constraint source | hosting |
| **BendScript** | complement | — | — | — | — | — | routing queries | KAG backend | dependency | capability provider | — | — |
| **Deliberatic** | evidence store | — | — | argumentation engine | temporal evidence | spatial evidence | constitutions | OS-003 | — | — | — | — |
| **AgenTroMatic** | feedback loop | — | wraps | — | triggers | triggers | task routing | OS-003 | — | — | — | — |
| **TickTickClock** | temporal knowledge | — | temporal evidence | triggers | — | &time+&space | compute budgets | OS-005 | — | — | — | hosting |
| **GeoFleetic** | spatial knowledge | — | spatial disputes | triggers | &time+&space | — | geofence policies | — | — | — | — | hosting |
| **Delegatic** | goal_id refs | routing | constitutions | policies | budgets | policies | — | enforcement | approval gate | install gate | — | — |
| **OpenSentience** | OS-001,002,004 | KAG backend | OS-003 | OS-003 | OS-005 | — | enforcement | — | deploy target | deploy target | permissions | hosting |
| **Agentelic** | integration | dependency | — | — | — | — | approval | deploy target | — | publish target | build input | — |
| **FleetPrompt** | connect on deploy | provider | — | — | — | — | install gate | deploy target | publish source | — | spec linkage | — |
| **SpecPrompt** | constraints | — | — | — | — | — | — | permissions | build input | spec linkage | — | — |
| **WebHost** | hosting | — | — | — | hosting | hosting | — | hosting | — | — | — | — |

---

## Summary

The [&] ecosystem is twelve products, five primitives, one protocol.

Each product solves a specific problem. Together, they form a vertically integrated stack for building, deploying, governing, and evolving AI agents at production scale.

The key insight is not that agents need all these components — most do. The insight is that these components should **compose through a shared protocol** rather than being glued together with ad hoc integration code.

That shared protocol is [&].
