# `&memory.graph` — Graph-Structured Memory Capability

`&memory.graph` is a concrete capability page for the [&] Protocol's `&memory` primitive.

It describes the capability interface for **graph-structured memory**: a memory system that stores entities, events, concepts, and relationships in a connected form and can use that structure to enrich retrieval, support reasoning, and preserve durable context over time.

This page is part of the capability registry and documentation hub. It is intended to be useful both to humans and to downstream generation systems.

---

## 1. Definition

`&memory.graph` is the capability for:

- relationship-aware recall
- graph-linked context enrichment
- durable structured memory
- consolidation of repeated observations into connected knowledge
- retrieval over entities, events, dependencies, and incident structure

Unlike flat text retrieval alone, graph memory preserves **how things relate**.

That makes it especially useful when an agent must answer questions like:

- What other incidents are connected to this one?
- Which dependency chain links this failure to a prior outage?
- Which entities, regions, or customers are affected through known relationships?
- What prior action led to this current state?

In protocol terms, the canonical capability identifier is:

- `&memory.graph`

---

## 2. Why this capability exists

A large share of important agent workloads are not just about finding similar text. They are about traversing structure.

Examples:

- infrastructure incidents linked through services, hosts, and dependencies
- research concepts linked through claims, citations, and prior conclusions
- customer support cases linked through account history, policies, and prior escalations
- fraud investigations linked through entities, accounts, devices, and event chains

A graph memory capability is useful whenever:

1. relationship structure matters
2. recall should be explainable
3. enrichment should include linked context rather than only nearest-neighbor similarity
4. memory should consolidate into durable connected knowledge over time

This is why `&memory.graph` is a distinct capability rather than just a provider detail.

---

## 3. Capability family position

`&memory.graph` sits inside the `&memory` namespace.

Related memory capabilities include:

- `&memory.vector` — semantic retrieval over embedded content
- `&memory.episodic` — replayable prior experiences or sessions

A useful shorthand:

- `memory.graph` = connected durable knowledge
- `memory.vector` = semantic similarity retrieval
- `memory.episodic` = prior experience replay

In many real systems, these capabilities compose rather than compete.

---

## 4. Capability contract summary

Below is a representative contract for `&memory.graph`.

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&memory.graph",
  "provider": "graphonomous",
  "version": "0.1.0",
  "description": "Graph-structured memory contract for relationship-aware recall, enrichment, and consolidation across incident, research, and operational contexts.",
  "operations": {
    "recall": {
      "in": "query_context",
      "out": "memory_hits",
      "description": "Retrieve graph-linked facts, incidents, entities, and relationships relevant to the current query.",
      "deterministic": false,
      "side_effects": false
    },
    "learn": {
      "in": "observation",
      "out": "ack",
      "description": "Persist a new observation or derived relationship into graph memory.",
      "deterministic": true,
      "side_effects": true
    },
    "consolidate": {
      "in": "memory_batch",
      "out": "graph_update",
      "description": "Merge repeated observations into more durable graph structure.",
      "deterministic": false,
      "side_effects": true
    },
    "enrich": {
      "in": "anomaly_set",
      "out": "enriched_context",
      "description": "Add linked historical incidents, dependencies, or related entities to a current anomaly set.",
      "deterministic": false,
      "side_effects": false
    }
  },
  "accepts_from": [
    "&time.*",
    "&reason.*",
    "query_context",
    "observation",
    "memory_batch"
  ],
  "feeds_into": [
    "&reason.*",
    "&space.*",
    "output"
  ],
  "a2a_skills": [
    "graph-memory-recall",
    "context-enrichment",
    "memory-consolidation"
  ]
}
~~~

### Interpretation

This contract says that `&memory.graph` can:

- recall graph-linked knowledge from a query context
- learn new observations
- consolidate batches into stronger graph structure
- enrich anomaly-oriented or operational context for downstream reasoning

It also says that it composes especially naturally with:

- temporal capabilities upstream
- reasoning capabilities downstream
- spatial capabilities downstream

---

## 5. Operations

### `recall`

Purpose:
- retrieve relevant nodes, edges, and linked context

Typical input:
- `query_context`

Typical output:
- `memory_hits`

Use when:
- the agent needs graph-aware recall instead of plain document search

### `learn`

Purpose:
- store new observations or relationship updates

Typical input:
- `observation`

Typical output:
- `ack`

Use when:
- the agent should update durable memory after a task or decision

### `consolidate`

Purpose:
- merge repeated or fragmented knowledge into more stable graph structure

Typical input:
- `memory_batch`

Typical output:
- `graph_update`

Use when:
- the system accumulates many observations and needs durable structure

### `enrich`

Purpose:
- attach graph-linked historical or dependency context to an existing payload

Typical input:
- `anomaly_set` or compatible context object

Typical output:
- `enriched_context`

Use when:
- another capability has already produced a signal and graph memory should make it more useful

---

## 6. Architecture patterns

### Pattern A: anomaly enrichment

~~~text
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &reason.argument.evaluate()
~~~

What happens:

1. a temporal capability detects anomalies
2. graph memory adds linked incident and dependency context
3. reasoning evaluates the best action

This is one of the strongest `&memory.graph` patterns.

### Pattern B: research knowledge graph

~~~text
research_query
|> &memory.graph.recall()
|> &reason.argument.deliberate()
~~~

What happens:

1. graph memory retrieves claims, relationships, and prior linked knowledge
2. reasoning compares or synthesizes evidence

### Pattern C: learning from outcomes

~~~text
decision_outcome
|> &memory.graph.learn()
|> &memory.graph.consolidate()
~~~

What happens:

1. outcome evidence is added to graph memory
2. repeated or related observations are consolidated

This supports continual learning without discarding structure.

---

## 7. Architecture diagram

A simple mental model for `&memory.graph`:

~~~text
                    ┌─────────────────────┐
                    │   incoming signal   │
                    │  query / anomaly /  │
                    │     observation     │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │   &memory.graph     │
                    │                     │
                    │  - recall           │
                    │  - enrich           │
                    │  - learn            │
                    │  - consolidate      │
                    └─────────┬───────────┘
                              │
               ┌──────────────┼──────────────┐
               │              │              │
               ▼              ▼              ▼
     ┌────────────────┐ ┌──────────────┐ ┌───────────────┐
     │ enriched       │ │ graph update │ │ memory hits   │
     │ context        │ │ / ack        │ │ / linked facts│
     └──────┬─────────┘ └──────────────┘ └───────────────┘
            │
            ▼
   ┌─────────────────────┐
   │ downstream reason / │
   │ space / output flow │
   └─────────────────────┘
~~~

---

## 8. Example declaration

A concrete `ampersand.json` fragment:

~~~json
{
  "&memory.graph": {
    "provider": "graphonomous",
    "config": {
      "instance": "infra-ops"
    }
  }
}
~~~

A fuller declaration:

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "InfraOperator",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "graphonomous",
      "config": {
        "instance": "infra-ops"
      }
    },
    "&time.anomaly": {
      "provider": "ticktickclock",
      "config": {
        "streams": ["cpu", "mem"]
      }
    },
    "&space.fleet": {
      "provider": "geofleetic",
      "config": {
        "regions": ["us-east"]
      }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "constitutional"
      }
    }
  },
  "provenance": true
}
~~~

---

## 9. Example API shape

A provider-specific API may vary, but the protocol-level shape can look like this.

### Recall request

~~~json
{
  "capability": "&memory.graph",
  "operation": "recall",
  "input": {
    "query_context": {
      "incident_type": "cpu_spike",
      "region": "us-east",
      "service": "api-gateway"
    }
  }
}
~~~

### Recall response

~~~json
{
  "capability": "&memory.graph",
  "operation": "recall",
  "output": {
    "memory_hits": [
      {
        "entity": "incident-4821",
        "summary": "CPU saturation on api-gateway during regional traffic spike",
        "links": ["service:api-gateway", "region:us-east", "runbook:scale-gateway"]
      },
      {
        "entity": "incident-4792",
        "summary": "Dependency saturation caused by cache failure",
        "links": ["service:cache", "service:api-gateway"]
      }
    ]
  }
}
~~~

### Enrich request

~~~json
{
  "capability": "&memory.graph",
  "operation": "enrich",
  "input": {
    "anomaly_set": {
      "service": "api-gateway",
      "region": "us-east",
      "anomalies": ["cpu_spike", "latency_jump"]
    }
  }
}
~~~

### Enrich response

~~~json
{
  "capability": "&memory.graph",
  "operation": "enrich",
  "output": {
    "enriched_context": {
      "related_incidents": ["incident-4821", "incident-4792"],
      "related_entities": ["service:cache", "service:api-gateway", "region:us-east"],
      "suggested_runbooks": ["scale-gateway", "check-cache-health"]
    }
  }
}
~~~

---

## 10. Compatible providers

`&memory.graph` is a capability interface. Compatible providers are implementations that can satisfy the contract.

Representative providers:

- `graphonomous`
- `neo4j-memory`
- custom graph-backed MCP services
- domain-specific knowledge graph systems wrapped behind a protocol-compatible surface

### Current default ecosystem fit

- `graphonomous` is the clearest default example provider in this repository

Why it fits:

- graph-oriented memory model
- MCP-friendly runtime shape
- suitable for recall, enrichment, and learning workflows
- directly useful for infra, research, and agent memory scenarios

---

## 11. A2A-facing skills

A `&memory.graph` capability may advertise skills such as:

- `graph-memory-recall`
- `context-enrichment`
- `memory-consolidation`

These skills are useful when generating A2A agent cards from a declaration, because they let an externally visible agent surface say more than just “has memory.”

---

## 12. Governance implications

Graph memory often sits close to high-value historical context, so governance matters.

Examples of governance constraints that commonly pair with `&memory.graph`:

### Hard constraints

- never reveal private customer-linked graph context outside authorized workflows
- never delete incident lineage without human approval
- always preserve audit trail for graph-backed decision support

### Soft constraints

- prefer policy-grounded linked evidence over unsupported inference
- prefer recent validated graph context when conflicts exist

### Escalation triggers

- escalate when confidence in recalled graph context is below threshold
- escalate when a decision depends on sparse or conflicting graph evidence

---

## 13. Provenance implications

`&memory.graph` should participate in the provenance chain.

Representative provenance record:

~~~json
{
  "source": "&memory.graph",
  "provider": "graphonomous",
  "operation": "enrich",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:1a2b...",
  "output_hash": "sha256:7c8d...",
  "parent_hash": "sha256:0000..."
}
~~~

This matters because graph-backed context often strongly influences downstream reasoning. If a system chooses a remediation path because graph memory linked the current issue to prior incidents, that enrichment step should be auditable.

---

## 14. Typical use cases

`&memory.graph` is especially strong in the following domains.

### Infrastructure operations

- dependency-aware incident recall
- similar outage enrichment
- durable operational knowledge
- continual learning from postmortems

### Research systems

- linked concepts and citations
- claim/evidence relationship structure
- durable research graph building

### Customer support

- account and case relationship modeling
- escalation lineage
- policy and entity linkage across prior interactions

### Fraud and investigation

- entity graph traversal
- linked device/account/session analysis
- relationship-based anomaly support

---

## 15. Anti-patterns

Avoid these mistakes when modeling `&memory.graph`.

### Anti-pattern 1: treating graph memory as just another vector store

Graph memory is valuable because of structure, not just similarity.

### Anti-pattern 2: collapsing provider and capability

`graphonomous` is not the protocol capability.
`&memory.graph` is.

### Anti-pattern 3: using graph memory without provenance

If graph-linked context influences action, lineage should be preserved.

### Anti-pattern 4: using graph memory for everything

Not every retrieval problem is best solved by graph structure alone. In many systems, `&memory.graph` works best alongside `&memory.vector` or `&memory.episodic`.

---

## 16. Related capabilities

Closest related protocol capabilities:

- `&memory.vector`
- `&memory.episodic`
- `&reason.argument`
- `&time.anomaly`
- `&space.fleet`

Common high-value compositions:

- `&time.anomaly` + `&memory.graph` + `&reason.argument`
- `&memory.graph` + `&space.fleet` + `&reason.plan`
- `&memory.graph` + `&memory.vector` + `&reason.argument`

---

## 17. Research references

This capability is informed by both memory-systems research and modern agent memory architecture work.

Useful reference directions:

- Atkinson & Shiffrin — staged memory models
- Endel Tulving — episodic vs semantic memory distinction
- Alan Baddeley — working memory and active memory use
- Larry Squire and related memory-systems research
- modern knowledge graph and graph retrieval systems
- graph-based agent memory architectures
- retrieval-augmented reasoning systems with structured memory

The protocol does not claim to reproduce neuroscience literally. The value of these references is that they support treating memory as a family of functions rather than one monolithic feature.

---

## 18. Summary

`&memory.graph` is the [&] Protocol capability for graph-structured memory.

It is the right capability when an agent needs:

- durable structured recall
- relationship-aware enrichment
- connected incident or research context
- continual learning into linked knowledge
- explainable memory that preserves structure

In one sentence:

> `&memory.graph` lets an agent remember not only facts, but how those facts connect.

---
