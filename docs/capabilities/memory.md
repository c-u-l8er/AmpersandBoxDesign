# `&memory`: Capability Deep Dive

The `&memory` namespace describes what an agent can **store, retrieve, enrich, consolidate, and replay** across time.

In the [&] Protocol, memory is not treated as a single binary feature. An agent does not simply “have memory” or “not have memory.” Instead, memory is modeled as a **family of capability interfaces** with distinct semantics, retrieval patterns, and downstream composition behavior.

This page explains:

- why memory is a first-class protocol primitive
- how `&memory` maps to cognitive and systems research
- the major memory subtypes in the protocol
- common architecture patterns
- schema and contract shapes for memory capabilities
- example providers
- example pipelines that use memory capabilities

---

## 1. Why `&memory` exists as a primitive

Memory is one of the clearest places where agent architecture becomes more than prompt engineering.

Real agent systems often need to:

- recall prior incidents
- retrieve documents or prior conversations
- maintain durable state across sessions
- preserve audit-relevant facts
- enrich current context with historical relationships
- replay prior episodes or workflows
- consolidate repeated observations into a more durable representation

These are not all the same task.

A graph-based incident memory behaves differently from a vector retrieval layer. An episodic replay system behaves differently from a semantic knowledge store. The protocol therefore treats memory as a **namespace of capabilities**, not a single implementation detail.

In protocol terms, `&memory` answers the question:

> What can this agent remember, and in what form?

---

## 2. Research grounding

The `&memory` primitive is informed by long-standing distinctions in cognitive science and practical distinctions in modern AI systems.

### 2.1 Classic memory distinctions

Several research threads motivate treating memory as plural rather than singular:

- **Atkinson & Shiffrin** introduced a staged view of memory with distinct storage roles.
- **Tulving** distinguished **episodic** and **semantic** memory.
- **Baddeley** developed the concept of **working memory** as an active, limited-capacity system.
- **Squire** and later memory-systems work reinforced the idea that memory is composed of different functional systems rather than one undifferentiated store.

The [&] Protocol does not attempt to reproduce neuroscience literally, but these distinctions are useful because they map well to engineering concerns:

- semantic retrieval
- durable structured knowledge
- experience replay
- short-lived context scaffolding
- consolidation and long-term retention

### 2.2 Modern agent systems

Modern agent architectures already separate memory into operational categories such as:

- vector retrieval memory
- graph knowledge memory
- episodic conversation history
- scratchpads or working context
- durable event logs
- long-term knowledge consolidation

That convergence suggests memory is ready to be treated as a protocol concern.

### 2.3 Why this matters for a protocol

If memory remains implicit, then every framework invents its own hidden model of:

- what memory means
- how memory is queried
- how memory interacts with reasoning
- what guarantees memory provides
- how memory participates in provenance

By modeling memory as a protocol namespace, the [&] Protocol makes those choices explicit and composable.

---

## 3. The `&memory` namespace

The primitive root is:

- `&memory`

Common subtypes include:

- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`

Future subtypes may include patterns such as:

- `&memory.working`
- `&memory.semantic`
- `&memory.cache`
- `&memory.eventlog`

The protocol keeps the primitive set small but allows subtype growth through namespacing.

---

## 4. Memory subtypes

## 4.1 `&memory.graph`

`&memory.graph` represents graph-structured memory.

Use it when the agent needs:

- entity and relationship recall
- cross-event linkage
- incident or causal graph navigation
- enrichment from connected prior knowledge
- durable structure over time

Typical operations:

- `recall`
- `learn`
- `consolidate`
- `enrich`

Typical strengths:

- relationship-aware retrieval
- explainable linked context
- incident and dependency modeling
- durable, structured long-term memory

Good fit for:

- infrastructure operations
- research knowledge graphs
- policy and dependency modeling
- multi-step causal analysis

---

## 4.2 `&memory.vector`

`&memory.vector` represents vector or embedding-based semantic retrieval.

Use it when the agent needs:

- semantic nearest-neighbor search
- retrieval over documents or chunks
- knowledge base lookup
- dense similarity matching
- lightweight enrichment from unstructured text

Typical operations:

- `search`
- `upsert`
- `enrich`

Typical strengths:

- efficient semantic retrieval
- broad compatibility with document corpora
- simple integration with retrieval-augmented systems
- strong performance for textual memory use cases

Good fit for:

- knowledge assistants
- customer support search
- research retrieval
- FAQ and documentation assistants

---

## 4.3 `&memory.episodic`

`&memory.episodic` represents remembered experiences, prior sessions, or replayable sequences.

Use it when the agent needs:

- prior interaction history
- experience replay
- route or workflow history
- conversation continuity
- case-by-case recall rather than abstracted knowledge only

Typical operations:

- `recall`
- `store`
- `replay`
- `enrich`

Typical strengths:

- preserves sequence and narrative structure
- useful for case memory and interaction continuity
- supports “what happened before?” workflows
- natural fit for session-based systems

Good fit for:

- customer support agents
- route history systems
- workflow assistants
- longitudinal research assistants

---

## 5. How memory differs from related primitives

Memory often gets confused with neighboring capabilities. The protocol keeps these boundaries explicit.

### `&memory` vs `&reason`

- `&memory` stores or retrieves what is known
- `&reason` evaluates, argues, plans, or decides

Memory may enrich reasoning, but it should not be conflated with reasoning.

### `&memory` vs `&time`

- `&memory` is about retained knowledge
- `&time` is about temporal patterns, forecasts, anomalies, and sequence-aware temporal behavior

A time capability may produce signals that memory stores or enriches, but the two are distinct.

### `&memory` vs `&space`

- `&memory` stores knowledge
- `&space` models where things are, how they are distributed, or how routes/regions constrain behavior

Memory can preserve spatial context, but space is still its own primitive.

---

## 6. Architecture patterns for memory

Different systems use different memory architectures. The protocol is designed to describe them without forcing one implementation.

## 6.1 Retrieval-first memory

Pattern:

- store documents or summaries in vector form
- retrieve semantically relevant material
- pass results into reasoning

Typical capability:

- `&memory.vector`

Best for:

- document-heavy systems
- support and research workflows
- broad semantic recall

---

## 6.2 Relationship-first memory

Pattern:

- represent facts, events, or incidents as nodes and edges
- enrich current tasks by traversing links and related cases

Typical capability:

- `&memory.graph`

Best for:

- operations systems
- causal tracing
- dependency-rich environments
- long-term structured knowledge

---

## 6.3 Experience-first memory

Pattern:

- store replayable episodes or sequences
- enrich the current task with similar prior experiences

Typical capability:

- `&memory.episodic`

Best for:

- customer interactions
- route or workflow history
- case-handling systems
- “similar past situation” analysis

---

## 6.4 Hybrid memory

Pattern:

- combine graph, vector, and episodic memory
- use each memory form for different retrieval needs

Example composition:

- `&memory.graph` for durable relationships
- `&memory.vector` for document retrieval
- `&memory.episodic` for session history

This is often the most realistic production architecture.

---

## 6.5 Consolidation architecture

Pattern:

- ingest raw observations
- store short-term or episodic traces
- consolidate repeated or related observations into more durable memory

Typical flow:

1. capture observations
2. store near-term experience
3. consolidate patterns into graph or semantic memory
4. enrich future reasoning from consolidated memory

This pattern is especially useful for long-running systems.

---

## 7. Protocol schema shape for `&memory`

At the declaration level, memory capabilities are represented inside `ampersand.json`.

Example:

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "ResearchAgent",
  "version": "0.1.0",
  "capabilities": {
    "&memory.vector": {
      "provider": "pgvector",
      "config": {
        "index": "papers",
        "namespace": "research-corpus"
      }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "evidence-first"
      }
    }
  },
  "provenance": true
}
~~~

Memory capability keys follow the same capability identifier rule as the rest of the protocol:

- `&memory`
- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`

With explicit binding:

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

With auto resolution:

~~~json
{
  "&memory.episodic": {
    "provider": "auto",
    "need": "customer interaction history with replayable escalation context"
  }
}
~~~

---

## 8. Capability contract shape for `&memory`

Memory becomes operationally important when paired with contracts.

A memory contract describes:

- supported operations
- input and output types
- adjacency rules
- optional A2A skill mappings

Example contract for `&memory.graph`:

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/capability-contract.schema.json",
  "capability": "&memory.graph",
  "provider": "graphonomous",
  "version": "0.1.0",
  "description": "Graph-structured memory for relationship-aware recall and enrichment.",
  "operations": {
    "recall": {
      "in": "query_context",
      "out": "memory_hits"
    },
    "learn": {
      "in": "observation",
      "out": "ack"
    },
    "consolidate": {
      "in": "memory_batch",
      "out": "graph_update"
    },
    "enrich": {
      "in": "anomaly_set",
      "out": "enriched_context"
    }
  },
  "accepts_from": [
    "&time.*",
    "&reason.*",
    "query_context",
    "observation"
  ],
  "feeds_into": [
    "&reason.*",
    "&space.*",
    "output"
  ],
  "a2a_skills": [
    "graph-memory-recall",
    "context-enrichment"
  ]
}
~~~

Example contract for `&memory.vector`:

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/capability-contract.schema.json",
  "capability": "&memory.vector",
  "provider": "pgvector",
  "version": "0.1.0",
  "description": "Semantic retrieval memory over embedded documents.",
  "operations": {
    "search": {
      "in": "query_context",
      "out": "retrieval_hits"
    },
    "upsert": {
      "in": "document_batch",
      "out": "ack"
    },
    "enrich": {
      "in": "query_context",
      "out": "enriched_context"
    }
  },
  "accepts_from": [
    "&reason.*",
    "query_context",
    "document_batch"
  ],
  "feeds_into": [
    "&reason.*",
    "output"
  ],
  "a2a_skills": [
    "semantic-retrieval",
    "knowledge-base-enrichment"
  ]
}
~~~

---

## 9. Example providers

The protocol is provider-agnostic, but current example providers include:

### Graph memory providers

- `graphonomous`
- `neo4j-memory`

### Vector memory providers

- `pgvector`
- `weaviate`
- `pinecone`

### Episodic memory providers

- `graphonomous`
- custom or application-specific implementations

The protocol position is:

- the capability is the interface
- the provider is an implementation that satisfies it

That is why `&memory.graph` is more important than any one vendor name.

---

## 10. Memory and governance

Memory capabilities often interact directly with governance.

Examples of governance constraints that frequently apply to memory:

- never store private customer data without policy justification
- never reveal one user’s memory context to another user
- always preserve audit trail for learned incident context
- prefer retrieving policy-grounded evidence over unsupported recollection

Memory is therefore not only a retrieval concern. It is also a **policy-sensitive capability**.

Example:

~~~json
{
  "governance": {
    "hard": [
      "Never reveal private customer data to another customer",
      "Always preserve an audit trail for memory-backed account changes"
    ],
    "soft": [
      "Prefer policy-grounded retrieval over speculative recollection"
    ],
    "escalate_when": {
      "confidence_below": 0.75,
      "hard_boundary_approached": true
    }
  }
}
~~~

---

## 11. Memory and provenance

Memory is one of the most provenance-sensitive capabilities in the protocol.

Why?

Because downstream decisions often depend on:

- which memory source was queried
- which provider answered
- what was retrieved
- how retrieved context was transformed
- whether recall was based on semantic similarity, graph structure, or episodic replay

A provenance-aware memory operation should preserve at least:

- source capability, such as `&memory.graph`
- provider, such as `graphonomous`
- operation, such as `recall` or `enrich`
- timestamp
- input hash
- output hash
- parent hash

Example provenance record:

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

This is critical for:

- debugging
- audits
- trust
- post-incident analysis
- policy review

---

## 12. Example memory-heavy agent declarations

## 12.1 Graph-backed operations agent

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
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

Why memory matters here:

- prior incidents can enrich anomaly interpretation
- related infrastructure dependencies can be recalled
- new outcomes can be learned into the graph

---

## 12.2 Vector-backed research agent

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "ResearchAgent",
  "version": "0.1.0",
  "capabilities": {
    "&memory.vector": {
      "provider": "pgvector",
      "config": {
        "index": "papers",
        "namespace": "research-corpus"
      }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "evidence-first"
      }
    }
  },
  "governance": {
    "hard": [
      "Always preserve citation traceability"
    ]
  },
  "provenance": true
}
~~~

Why memory matters here:

- retrieval quality directly affects reasoning quality
- provenance matters for evidence traceability
- semantic memory is more important than graph structure in many literature workflows

---

## 12.3 Episodic customer support agent

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "CustomerSupport",
  "version": "0.1.0",
  "capabilities": {
    "&memory.episodic": {
      "provider": "graphonomous",
      "config": {
        "instance": "customer-support-history",
        "retention_days": 90
      }
    },
    "&memory.vector": {
      "provider": "pgvector",
      "config": {
        "index": "support-kb",
        "namespace": "help-center"
      }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "customer-safe"
      }
    }
  },
  "provenance": true
}
~~~

Why memory matters here:

- episodic memory preserves prior customer context
- vector memory supports policy and knowledge retrieval
- the combination supports both continuity and grounding

---

## 13. Example memory pipelines

## 13.1 Anomaly enrichment pipeline

This is a classic infrastructure pattern:

~~~text
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &reason.argument.evaluate()
|> &memory.graph.learn()
~~~

What happens:

1. temporal capability detects anomalies
2. graph memory enriches the anomaly set with similar incidents or related dependencies
3. reasoning evaluates action options
4. resulting decision or outcome is learned back into memory

This is a good example of memory as both:
- enrichment layer
- long-term learning surface

---

## 13.2 Retrieval-grounded reasoning pipeline

A research or policy workflow:

~~~text
query_context
|> &memory.vector.search()
|> &memory.vector.enrich()
|> &reason.argument.evaluate()
~~~

What happens:

1. vector memory searches relevant materials
2. retrieved context is enriched
3. reasoning operates on grounded evidence rather than unsupported recall

---

## 13.3 Episodic support replay pipeline

A continuity-focused workflow:

~~~text
customer_case
|> &memory.episodic.recall()
|> &memory.vector.search()
|> &reason.argument.evaluate()
|> &memory.episodic.store()
~~~

What happens:

1. prior interaction history is recalled
2. policy and knowledge base context is retrieved
3. reasoning generates a response or decision
4. the new case state is stored as a new episode

---

## 14. When to choose each memory subtype

### Choose `&memory.graph` when you need:

- relationships
- causality
- incident linkage
- explainable structure
- durable knowledge graphs

### Choose `&memory.vector` when you need:

- semantic document retrieval
- dense search
- broad textual recall
- quick retrieval over corpora
- knowledge base enrichment

### Choose `&memory.episodic` when you need:

- interaction continuity
- replayable prior experiences
- session or case history
- sequence-aware recall

### Choose multiple memory capabilities when you need:

- hybrid retrieval
- both structure and semantic search
- both historical episodes and durable knowledge
- different memory surfaces for different downstream tasks

---

## 15. Design principles for `&memory`

### 15.1 Keep capability and provider separate

Use:

- `&memory.graph`
- not “Graphonomous memory” as the protocol-level concept

### 15.2 Treat memory as plural

Do not collapse all memory use cases into one abstraction.

### 15.3 Make contracts explicit

A memory capability should describe:
- what it accepts
- what it outputs
- what it can enrich
- what can follow it in a pipeline

### 15.4 Preserve provenance

Memory-backed decisions should be auditable.

### 15.5 Let governance travel with memory

Sensitive retrieval and storage behavior should be constrained declaratively.

---

## 16. Open questions for future protocol work

Useful future extensions for the `&memory` namespace may include:

- working-memory or scratchpad-oriented subtypes
- stronger retention and expiration metadata
- cross-memory consolidation semantics
- richer privacy and access-control traits
- more formal distinction between semantic and episodic retrieval contracts
- standardized memory quality metrics

These are appropriate areas for protocol growth, but the current namespace is already useful without overfitting too early.

---

## 17. Summary

`&memory` is one of the most important primitives in the [&] Protocol because it turns “agent memory” from a vague feature into a composable capability family.

It provides a vocabulary for:

- graph-structured memory
- vector retrieval memory
- episodic memory
- future subtype expansion

It also provides a place to standardize:

- typed memory operations
- compatibility with downstream reasoning
- governance-sensitive storage and recall
- provenance-aware context enrichment

In short:

> `&memory` defines what the agent can remember, how it remembers it, and how that remembered context composes with the rest of the system.

---

## Suggested next reading

- `docs/capabilities/reason.md`
- `docs/capabilities/time.md`
- `docs/capabilities/space.md`
- `docs/architecture.md`
- `protocol/schema/v0.1.0/ampersand.schema.json`
- `protocol/schema/v0.1.0/capability-contract.schema.json`
