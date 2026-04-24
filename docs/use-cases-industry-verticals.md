# Industry Verticals: Where All Six Primitives Compose

**March 2026 · [&] Ampersand Box Design**

---

## Beyond autonomous vehicles

The companion document [Autonomous Systems](use-cases-autonomous-systems.md) explains why military drones and AVs are the canonical [&] use case. But autonomous vehicles are not the only domain where all six primitives compose naturally.

This document maps **seven commercial industries** where `&memory + &reason + &time + &space + &body + &govern` deliver value that no single-primitive solution can match. For each vertical, we show the six-primitive pipeline, the products that implement it, and the business problem it solves.

---

## 1. Field Service Management

**The $5.2B industry where all six primitives are table stakes.**

Field service — HVAC repair, elevator maintenance, medical equipment servicing, telecom installation — is the commercial vertical that most completely exercises the [&] Protocol. Every work order involves: what the technician knows (memory), how to prioritize and dispatch (reason), when the equipment will fail next (time), where the technician and equipment are (space), and who approved the work under what SLA (govern).

### The six-primitive pipeline

```
equipment_telemetry
  |> &time.anomaly.detect()           # TickTickClock: detect failing HVAC unit
  |> &time.forecast.predict()          # TickTickClock: predict failure within 48h
  |> &govern.telemetry.emit()          # Cost tracking for the prediction
  |> &memory.graph.enrich()            # Graphonomous: retrieve repair history for this model
  |> &space.fleet.locate()             # GeoFleetic: find nearest qualified technician
  |> &space.route.optimize()           # GeoFleetic: compute route with traffic + SLA window
  |> &govern.telemetry.budget_check()  # Delegatic: check dispatch cost vs. contract budget
  |> &reason.plan.evaluate()           # Deliberatic: evaluate dispatch plan
  |> &govern.escalation.escalate()     # OpenSentience: escalate if confidence < 0.7
```

### Why single-primitive solutions fail

| Current approach | What breaks |
|-----------------|-------------|
| ServiceMax / Salesforce Field Service | No predictive failure detection. Reactive dispatch only. No spatial optimization beyond "nearest tech." |
| IoT anomaly platforms (Datadog, PagerDuty) | Detect anomalies but can't dispatch, route, or reason about repair history |
| Route optimization (Google OR-Tools, Routific) | Optimize routes but don't know which equipment is failing or which tech is qualified |
| Knowledge management (ServiceNow KB) | Store repair procedures but don't learn from outcomes or compose with spatial/temporal signals |

**[&] advantage:** The typed pipeline composes prediction + knowledge + dispatch + routing + governance in a single auditable flow. No glue code.

### Example `ampersand.json`

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "FieldServiceDispatcher",
  "version": "1.0.0",
  "capabilities": {
    "&time.anomaly": { "provider": "ticktickclock", "config": { "streams": ["hvac_vibration", "hvac_temp"] } },
    "&time.forecast": { "provider": "ticktickclock", "config": { "horizon_hours": 48 } },
    "&memory.graph": { "provider": "graphonomous", "config": { "instance": "repair-history" } },
    "&space.fleet": { "provider": "geofleetic", "config": { "regions": ["northeast", "mid-atlantic"] } },
    "&space.route": { "provider": "geofleetic", "config": { "mode": "sla-aware-routing" } },
    "&reason.plan": { "provider": "auto", "need": "dispatch optimization with qualification matching" },
    "&govern.telemetry": { "provider": "opensentience", "config": { "org_id": "org_fieldco" } },
    "&govern.escalation": { "provider": "opensentience", "config": { "timeout_seconds": 600 } }
  },
  "governance": {
    "hard": ["Never dispatch unqualified technician to regulated equipment", "Always meet SLA window"],
    "soft": ["Prefer local technicians over cross-region dispatch"],
    "escalate_when": { "confidence_below": 0.7, "cost_exceeds_usd": 500 },
    "autonomy": {
      "level": "advise",
      "budget": { "max_cost_usd_per_task": 500, "max_tokens_per_period": 500000 }
    }
  }
}
```

---

## 2. Healthcare Operations

**Hospital operations where temporal prediction + spatial logistics + governance compliance compose.**

Hospital operations — patient flow, equipment tracking, staff scheduling, bed management — require all six primitives. A sepsis early warning system must detect temporal patterns in vitals (time), locate the nearest available care team (space), retrieve the patient's history (memory), reason about treatment protocols (reason), and comply with clinical governance (govern).

### The six-primitive pipeline

```
patient_vitals_stream
  |> &time.anomaly.detect()           # Detect deterioration in vitals
  |> &time.pattern.recognize()         # Identify sepsis signature pattern
  |> &memory.graph.enrich()            # Patient history, allergies, prior treatments
  |> &space.fleet.locate()             # Locate nearest available care team by unit
  |> &reason.argument.evaluate()       # Evaluate treatment options against protocols
  |> &govern.escalation.escalate()     # Mandatory escalation for critical interventions
  |> &govern.telemetry.emit()          # HIPAA-compliant audit trail
  |> &govern.identity.verify()         # Verify ordering physician identity
```

### Key governance requirements

- `&govern.telemetry`: HIPAA-compliant audit trail for every clinical decision
- `&govern.escalation`: Mandatory human review for high-acuity interventions
- `&govern.identity`: Physician identity verification for order signing
- Delegatic policy: `allowed_model_tiers: ["local_small"]` (patient data never leaves local infrastructure)

---

## 3. Supply Chain & Logistics

**Global supply chains where temporal forecasting + spatial routing + multi-org governance compose.**

Supply chain management — demand forecasting, inventory optimization, carrier routing, customs compliance — spans organizations and geographies. A supply chain agent must forecast demand (time), optimize routes across carriers and warehouses (space), remember historical disruption patterns (memory), reason about supplier alternatives when disruptions occur (reason), and enforce compliance across org boundaries (govern).

### The six-primitive pipeline

```
demand_signals
  |> &time.forecast.predict()          # Forecast demand by SKU and region
  |> &space.fleet.capacity()           # Check warehouse capacity by region
  |> &memory.graph.enrich()            # Historical disruption patterns for this lane
  |> &space.route.optimize()           # Multi-modal routing (truck, rail, ocean)
  |> &govern.telemetry.budget_check()  # Check freight budget against allocation
  |> &reason.argument.evaluate()       # Evaluate sourcing alternatives
  |> &govern.escalation.escalate()     # Escalate if lead time exceeds SLA
```

### Multi-org governance

Supply chains cross organizational boundaries. Delegatic's monotonic policy inheritance handles this:

```
Root org: GlobalCo
├── Subsidiary: GlobalCo-NA (inherits + tightens: max_cost_usd_per_period: $100K)
│   ├── Carrier: FreightCo (inherits + tightens: allowed_runtimes: ["edge_only"])
│   └── Warehouse: WarehouseCo (inherits + tightens: denied_tools: ["external_api"])
└── Subsidiary: GlobalCo-EU (inherits + tightens: allowed_model_tiers: ["local_small"])
```

Each subsidiary can only **tighten** parent restrictions — never loosen them. Budget limits flow down via MIN. This is structural, not a runtime check.

---

## 4. Energy & Utilities

**Grid management where temporal anomaly detection + spatial topology + governance compliance are safety-critical.**

Energy grid operations — load balancing, outage prediction, renewable integration, demand response — require all six primitives under safety-critical governance. A grid agent must detect anomalous load patterns (time), understand grid topology and affected regions (space), recall historical outage patterns (memory), reason about load-shedding strategies (reason), and comply with NERC CIP regulatory requirements (govern).

### The six-primitive pipeline

```
grid_telemetry
  |> &time.anomaly.detect()           # Detect load imbalance or equipment anomaly
  |> &time.forecast.predict()          # Forecast demand spike (next 4 hours)
  |> &space.fleet.enrich()             # Map to grid topology: which substations affected
  |> &space.geofence.check()           # Check if affected area crosses regulatory zones
  |> &memory.graph.enrich()            # Prior outage patterns for this grid segment
  |> &reason.deliberate()              # Multi-stakeholder deliberation on load-shedding
  |> &govern.escalation.escalate()     # Mandatory human approval for load-shedding
  |> &govern.telemetry.emit()          # NERC CIP compliance audit trail
```

### Why governance is non-negotiable

Energy is a regulated industry. Every decision that affects grid stability must:
- Be auditable (`&govern.telemetry` with NERC CIP event types)
- Have human approval for critical actions (`&govern.escalation`)
- Stay within budget (`&govern.telemetry.budget_check()`)
- Verify operator identity (`&govern.identity`)

This is not optional governance — it's legally mandated.

---

## 5. Manufacturing & Industry 4.0

**Smart factories where predictive maintenance + spatial digital twins + quality governance compose.**

Manufacturing operations — predictive maintenance, quality control, production scheduling, supply chain coordination — are increasingly agent-driven. A factory agent must predict equipment failures (time), track assets and production lines spatially (space), recall maintenance history and quality patterns (memory), reason about production schedule adjustments (reason), and enforce ISO 9001 quality governance (govern).

### The six-primitive pipeline

```
machine_sensors
  |> &time.anomaly.detect()           # Detect bearing wear from vibration signature
  |> &time.pattern.recognize()         # Identify degradation trend (remaining useful life)
  |> &space.fleet.locate()             # Which production line, which cell, which machine
  |> &memory.graph.enrich()            # Maintenance history, spare parts inventory
  |> &reason.plan.evaluate()           # Schedule maintenance window vs. production impact
  |> &govern.telemetry.budget_check()  # Check against maintenance budget allocation
  |> &govern.escalation.escalate()     # Escalate if production line shutdown required
```

### Digital twin composition

GeoFleetic's spatial digital twins map naturally to factory floor assets:
- Each machine is a twin (GenServer with Delta-CRDT sync)
- Production lines are spatial regions
- Quality checkpoints are geofences
- Material flow is route optimization

---

## 6. Financial Services

**Trading, compliance, and risk management where temporal pattern detection + governance audit trails are regulatory requirements.**

Financial services — algorithmic trading, fraud detection, compliance monitoring, risk assessment — require all six primitives under strict regulatory governance. A compliance agent must detect suspicious transaction patterns (time), identify geographic risk factors (space), recall regulatory history (memory), reason about compliance actions (reason), and maintain a complete audit trail (govern).

### The six-primitive pipeline

```
transaction_stream
  |> &time.anomaly.detect()           # Detect unusual transaction patterns
  |> &time.pattern.recognize()         # Identify known fraud signatures
  |> &space.geofence.check()           # Check transaction origin against sanctioned regions
  |> &memory.graph.enrich()            # Customer history, prior investigations, KYC status
  |> &reason.argument.evaluate()       # Evaluate risk level with evidence-based reasoning
  |> &govern.identity.verify()         # Verify reporting agent's authorization
  |> &govern.escalation.escalate()     # Mandatory escalation for suspicious activity
  |> &govern.telemetry.emit()          # SOX/MiFID II compliant audit trail
```

### Regulatory governance requirements

- SOX compliance: Every decision that affects financial reporting must have a complete provenance chain
- MiFID II: Best execution obligations require auditable reasoning for trade decisions
- AML/KYC: Suspicious activity must be escalated within regulatory timeframes
- Delegatic: `allowed_model_tiers: ["local_small"]` (customer financial data never leaves secure infrastructure)

---

## 7. Telecommunications

**Network operations where temporal anomaly detection + spatial topology + SLA governance compose at scale.**

Telecom network operations — cell tower monitoring, network capacity planning, SLA management, field crew dispatch — mirror field service but at massive scale with strict SLA governance.

### The six-primitive pipeline

```
network_kpis
  |> &time.anomaly.detect()           # Detect degraded cell site performance
  |> &time.forecast.predict()          # Predict capacity breach (next 6 hours)
  |> &space.fleet.enrich()             # Map to network topology: affected cells, sectors
  |> &space.route.optimize()           # Route field crew to site with traffic awareness
  |> &memory.graph.enrich()            # Prior incidents, resolution patterns, vendor RMA history
  |> &reason.plan.evaluate()           # Evaluate: remote fix vs. truck roll vs. escalate to vendor
  |> &govern.telemetry.budget_check()  # Check SLA penalty cost vs. repair cost
  |> &govern.escalation.escalate()     # Escalate if SLA breach imminent
```

---

## Cross-vertical patterns

### Pattern 1: Predict → Locate → Dispatch → Govern

Every industry that dispatches field resources (field service, energy, telecom, manufacturing) follows this pattern:

```
&time.anomaly → &space.fleet → &space.route → &govern.escalation
```

This is the most common five-primitive composition in commercial applications.

### Pattern 2: Detect → Enrich → Reason → Audit

Every industry with compliance requirements (healthcare, financial, energy) follows this pattern:

```
&time.anomaly → &memory.graph → &reason.argument → &govern.telemetry
```

Anomaly detection triggers knowledge retrieval, which feeds evidence-based reasoning, which produces an auditable decision.

### Pattern 3: Forecast → Capacity → Plan → Budget

Every industry with resource planning (supply chain, manufacturing, telecom) follows this pattern:

```
&time.forecast → &space.fleet.capacity → &reason.plan → &govern.telemetry.budget_check
```

Demand forecasting feeds capacity analysis, which feeds planning, which is budget-constrained.

---

## Market sizing by vertical

| Vertical | TAM (2025) | Growth | [&] Relevance |
|----------|-----------|--------|---------------|
| **Field Service Management** | $5.2B | 11% CAGR | All 6 primitives are table stakes |
| **Healthcare Operations** | $8.1B (clinical AI) | 38% CAGR | Governance-first; temporal + spatial critical |
| **Supply Chain AI** | $3.8B | 25% CAGR | Multi-org governance; temporal forecasting |
| **Energy Grid AI** | $2.1B | 22% CAGR | Safety-critical; all primitives mandatory |
| **Manufacturing AI** | $4.5B | 28% CAGR | Digital twins; predictive maintenance |
| **Financial Compliance AI** | $6.3B | 20% CAGR | Governance-dominant; audit trail mandatory |
| **Telecom Operations AI** | $3.2B | 19% CAGR | Scale + SLA governance; field dispatch |
| **Total addressable** | **$33.2B** | | |

These are the verticals where single-primitive solutions (memory-only, reasoning-only, observability-only) demonstrably fail because the business problem requires composed cognition under governance.

---

## Summary

The [&] Protocol was designed for agents that need to **remember, reason, predict, localize, and comply** — simultaneously. Seven commercial verticals exercise all six primitives:

1. **Field Service** — predict failure, locate technician, dispatch, comply with SLA
2. **Healthcare** — detect deterioration, locate care team, reason about treatment, comply with HIPAA
3. **Supply Chain** — forecast demand, optimize routes, reason about alternatives, comply across orgs
4. **Energy** — detect grid anomalies, map topology, reason about load-shedding, comply with NERC
5. **Manufacturing** — predict equipment failure, locate on factory floor, plan maintenance, comply with ISO
6. **Financial Services** — detect fraud patterns, check sanctions geography, reason about risk, comply with SOX
7. **Telecom** — detect network degradation, map cell topology, plan repair, comply with SLAs

In every case, the business value is in the **composition**, not any single primitive. That composition — typed, validated, governed, and auditable — is what the [&] Protocol provides.
