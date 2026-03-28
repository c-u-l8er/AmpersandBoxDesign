# Skill 07 — Integration Patterns

> Real-world capability composition recipes. Each recipe shows a problem,
> the declaration, the composition, and what generation produces.

---

## Why This Matters

Abstract composition is useful for understanding the protocol. Concrete
recipes are useful for building agents. This file provides five tested
patterns that combine the four primitives in production-relevant ways.

---

## Recipe 1: Temporal Anomaly Enrichment

**Problem:** Detect anomalies in time-series data and enrich them with
historical context from memory before routing to reasoning.

**Pipeline:** `time -> memory -> reason`

### Declaration

```json
{
  "agent": "AnomalyTriager",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph":    { "provider": "graphonomous", "config": { "instance": "ops" } },
    "&time.anomaly":    { "provider": "ticktickclock", "config": { "streams": ["cpu", "latency"] } },
    "&reason.argument": { "provider": "deliberatic", "config": { "governance": "evidence-first" } }
  },
  "pipelines": {
    "triage": {
      "source_type": "stream_data",
      "source_ref": "raw_data",
      "steps": [
        { "capability": "&time.anomaly", "operation": "detect" },
        { "capability": "&memory.graph", "operation": "enrich" },
        { "capability": "&reason.argument", "operation": "evaluate" }
      ]
    }
  }
}
```

### Type flow

```
stream_data -> anomaly_set -> enriched_context -> evaluation_result
               &time.anomaly  &memory.graph      &reason.argument
```

### What it produces

- MCP config with three servers (graphonomous, ticktickclock, deliberatic)
- A2A card with skills: temporal-anomaly-detection, topology-aware-deliberation

---

## Recipe 2: Evidence-Grounded Reasoning

**Problem:** Answer questions by first recalling relevant knowledge, then
reasoning over retrieved evidence with provenance.

**Pipeline:** `memory -> reason -> output`

### Declaration

```json
{
  "agent": "EvidenceReasoner",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph":      { "provider": "graphonomous", "config": {} },
    "&reason.deliberate": { "provider": "graphonomous", "config": { "budget": "kappa" } }
  },
  "pipelines": {
    "answer": {
      "source_type": "query",
      "source_ref": "user_query",
      "steps": [
        { "capability": "&memory.graph", "operation": "recall" },
        { "capability": "&memory.graph", "operation": "topology" },
        { "capability": "&reason.deliberate", "operation": "deliberate" }
      ]
    }
  },
  "provenance": true
}
```

### Type flow

```
query -> retrieval_result -> topology_result -> deliberation_result
         &memory.graph       &memory.graph      &reason.deliberate
```

This is the **reactive pipeline** from the protocol spec. The topology step
detects cycles (kappa > 0) in the retrieved knowledge, and deliberation
resolves them through focused reasoning.

---

## Recipe 3: Fleet Intelligence

**Problem:** Combine spatial fleet tracking with temporal pattern detection
and deliberative reasoning for fleet-wide decision making.

**Pipeline:** `space + time -> reason`

### Declaration

```json
{
  "agent": "FleetIntel",
  "version": "1.0.0",
  "capabilities": {
    "&space.fleet":       { "provider": "geofleetic", "config": { "regions": ["us-east", "eu-west"] } },
    "&time.pattern":      { "provider": "ticktickclock", "config": { "granularity": "hourly" } },
    "&memory.graph":      { "provider": "graphonomous", "config": {} },
    "&reason.argument":   { "provider": "deliberatic", "config": {} }
  },
  "pipelines": {
    "fleet_analysis": {
      "source_type": "stream_data",
      "source_ref": "fleet_telemetry",
      "steps": [
        { "capability": "&space.fleet", "operation": "locate" },
        { "capability": "&time.pattern", "operation": "detect" },
        { "capability": "&memory.graph", "operation": "enrich" },
        { "capability": "&reason.argument", "operation": "evaluate" }
      ]
    }
  }
}
```

### Composition expression

```
&space.fleet & &time.pattern & &memory.graph & &reason.argument
```

All four primitives are represented. The pipeline flows spatial data through
temporal analysis, enriches with historical context, and routes to reasoning.

---

## Recipe 4: Governance-Aware Decision

**Problem:** Make high-stakes decisions with hard constraints, escalation
triggers, and full provenance for audit trails.

### Declaration

```json
{
  "agent": "GovernedDecider",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph":      { "provider": "graphonomous", "config": {} },
    "&reason.argument":   { "provider": "deliberatic", "config": { "governance": "constitutional" } },
    "&reason.attend":     { "provider": "graphonomous", "config": {} }
  },
  "governance": {
    "hard": [
      "Never authorize expenditures above $10,000",
      "Never modify production systems without approval"
    ],
    "soft": [
      "Prefer reversible actions over irreversible ones",
      "Prefer consensus when multiple options score equally"
    ],
    "escalate_when": {
      "confidence_below": 0.6,
      "cost_exceeds_usd": 5000,
      "hard_boundary_approached": true
    },
    "autonomy": {
      "level": "advise",
      "model_tier": "local_large",
      "budget": {
        "max_actions_per_hour": 10,
        "require_approval_for": ["act"]
      }
    }
  },
  "provenance": true
}
```

The governance block ensures the agent operates within declared boundaries.
The `advise` autonomy level means it proposes actions but waits for approval.
Provenance creates an audit trail of every capability invocation.

---

## Recipe 5: Full Cognitive Stack

**Problem:** Build an agent that uses all four primitives — memory, reasoning,
temporal awareness, and spatial awareness — in a cohesive architecture.

### Declaration

```json
{
  "agent": "CognitiveAgent",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph":      { "provider": "graphonomous", "config": { "instance": "cognitive" } },
    "&memory.episodic":   { "provider": "graphonomous", "config": {} },
    "&reason.deliberate": { "provider": "graphonomous", "config": { "budget": "kappa" } },
    "&reason.attend":     { "provider": "graphonomous", "config": {} },
    "&time.anomaly":      { "provider": "ticktickclock", "config": { "streams": ["all"] } },
    "&time.forecast":     { "provider": "ticktickclock", "config": {} },
    "&space.fleet":       { "provider": "geofleetic", "config": { "regions": ["global"] } },
    "&space.geofence":    { "provider": "geofleetic", "config": {} }
  },
  "governance": {
    "hard": ["Never act without evidence from at least two capability domains"],
    "soft": ["Prefer multi-signal corroboration"],
    "escalate_when": { "confidence_below": 0.5 },
    "autonomy": { "level": "act", "model_tier": "cloud_frontier" }
  },
  "provenance": true
}
```

### Composition expression

```
&memory.graph & &memory.episodic & &reason.deliberate & &reason.attend
& &time.anomaly & &time.forecast & &space.fleet & &space.geofence
```

Eight capabilities across all four primitives. This is a high-trust agent
(`autonomy: "act"`, `model_tier: "cloud_frontier"`) with a governance
constraint requiring multi-domain evidence before acting.

---

## Pattern Selection Guide

| Situation | Recommended Recipe |
|-----------|-------------------|
| Stream monitoring with alerting | Recipe 1: Temporal Anomaly Enrichment |
| Knowledge-intensive Q&A | Recipe 2: Evidence-Grounded Reasoning |
| Multi-region fleet operations | Recipe 3: Fleet Intelligence |
| Regulated or audited environments | Recipe 4: Governance-Aware Decision |
| General-purpose autonomous agent | Recipe 5: Full Cognitive Stack |

Start with the simplest recipe that covers your needs. Add capabilities
incrementally as requirements emerge.
