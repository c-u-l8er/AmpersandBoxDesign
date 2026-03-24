# `&memory.vector` -- Semantic Vector Retrieval Capability

`&memory.vector` is a concrete capability page for the [&] Protocol's `&memory` primitive.

It describes the capability interface for **semantic vector retrieval**: a memory system that embeds documents and knowledge corpora into vector space and retrieves them by similarity. This is the canonical approach for corpus-level semantic search, knowledge-base lookup, and context enrichment over large unstructured or semi-structured document sets.

This page is part of the capability registry and documentation hub. It is intended to be useful both to humans and to downstream generation systems.

---

## 1. Definition

`&memory.vector` is the capability for:

- semantic similarity retrieval over embedded documents
- corpus-level knowledge-base lookup
- context enrichment with semantically relevant material
- inserting and updating embedded documents for future retrieval

Unlike graph memory, vector memory operates over a **flat embedding space**. There is no explicit relationship structure. Retrieval is based on proximity in vector space: what is semantically similar to the query, not what is structurally connected.

That makes it especially useful when an agent must answer questions like:

- What documents in this corpus are most relevant to this query?
- Which support articles best match this customer question?
- What prior research material is semantically closest to this claim?
- What context should be injected to ground this response?

In protocol terms, the canonical capability identifier is:

- `&memory.vector`

---

## 2. Why this capability exists

A large share of important agent workloads involve retrieval over document corpora that do not have explicit relational structure. The documents exist as text, and the retrieval problem is: find what is semantically relevant.

Examples:

- support knowledge bases where articles must be matched to customer questions
- research corpora where papers, notes, and claims must be surfaced by meaning
- policy and compliance libraries where the right section must be found for a given situation
- product documentation where the answer to a technical question lives somewhere in a large set of pages

A vector retrieval capability is useful whenever:

1. the corpus is large enough that keyword search alone is insufficient
2. retrieval should be based on meaning, not just exact terms
3. the agent needs grounded context from a knowledge base before reasoning
4. documents should be retrievable without requiring manual tagging or graph construction

This is why `&memory.vector` is a distinct capability rather than just a provider detail.

---

## 3. Capability family position

`&memory.vector` sits inside the `&memory` namespace.

Related memory capabilities include:

- `&memory.graph` -- graph-structured relationship memory
- `&memory.episodic` -- replayable prior experiences or sessions

A useful shorthand:

- `memory.vector` = semantic similarity retrieval
- `memory.graph` = connected durable knowledge
- `memory.episodic` = prior experience replay

How these differ in practice:

- `&memory.vector` finds what is **similar**. It operates over embeddings in a flat space. There is no topology, no edges, no relationship structure. Results are ranked by distance.
- `&memory.graph` finds what is **connected**. It operates over nodes and edges. It can traverse dependency chains, identify feedback loops, and use kappa-aware routing to decide whether cyclic structure requires deliberation.
- `&memory.episodic` finds what **happened before**. It stores session-level history and replayable experience. It is scoped to temporal sequences, not corpus-level knowledge.

In many real systems, these capabilities compose rather than compete.

---

## 4. Capability contract summary

Below is a representative contract for `&memory.vector`.

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&memory.vector",
  "provider": "pgvector",
  "version": "0.1.0",
  "description": "Semantic vector retrieval contract for similarity search, document upsert, and context enrichment over embedded knowledge corpora.",
  "operations": {
    "search": {
      "in": "query_context",
      "out": "retrieval_hits",
      "description": "Retrieve semantically similar documents from the vector store given a query context.",
      "deterministic": false,
      "side_effects": false
    },
    "upsert": {
      "in": "document_payload",
      "out": "ack",
      "description": "Insert or update an embedded document in the vector store.",
      "deterministic": true,
      "side_effects": true
    },
    "enrich": {
      "in": "query_context",
      "out": "enriched_context",
      "description": "Augment an existing context object with semantically relevant material from the corpus.",
      "deterministic": false,
      "side_effects": false
    }
  },
  "accepts_from": [
    "&reason.*",
    "&memory.episodic",
    "query_context",
    "document_payload"
  ],
  "feeds_into": [
    "&reason.*",
    "&memory.graph",
    "output"
  ],
  "a2a_skills": [
    "semantic-retrieval",
    "knowledge-base-enrichment"
  ]
}
~~~

### Interpretation

This contract says that `&memory.vector` can:

- search for semantically similar documents from a query context
- upsert new or updated documents into the vector store
- enrich an existing context with relevant semantic material for downstream use

It also says that it composes especially naturally with:

- reasoning capabilities downstream
- graph memory downstream (for hybrid retrieval)
- episodic memory upstream (to ground retrieval in session context)

---

## 5. Operations

### `search`

Purpose:
- retrieve documents or passages that are semantically similar to the query

Typical input:
- `query_context`

Typical output:
- `retrieval_hits`

Use when:
- the agent needs to find relevant material from a corpus based on meaning

### `upsert`

Purpose:
- insert a new document or update an existing one in the vector store

Typical input:
- `document_payload`

Typical output:
- `ack`

Use when:
- the agent should add or refresh knowledge in the corpus

### `enrich`

Purpose:
- augment an existing context object with semantically relevant material from the corpus

Typical input:
- `query_context` or compatible context object

Typical output:
- `enriched_context`

Use when:
- another capability has already produced a signal and semantic context should make it more useful

---

## 6. Architecture patterns

### Pattern A: policy-grounded support

~~~text
customer_query
|> &memory.vector.search()
|> &memory.episodic.recall()
|> &reason.argument.evaluate()
~~~

What happens:

1. vector memory retrieves relevant support articles and policy documents
2. episodic memory adds prior session context for this customer
3. reasoning evaluates the best response grounded in policy

This is one of the strongest `&memory.vector` patterns for customer-facing agents.

### Pattern B: hybrid retrieval

~~~text
research_query
|> &memory.vector.search()
|> &memory.graph.enrich()
|> &reason.argument.deliberate()
~~~

What happens:

1. vector memory retrieves semantically relevant documents
2. graph memory adds relationship and dependency context
3. reasoning synthesizes evidence from both retrieval modes

This combines breadth (vector) with structure (graph).

### Pattern C: corpus ingestion

~~~text
new_document
|> &memory.vector.upsert()
~~~

What happens:

1. the document is embedded and stored for future retrieval

This is the write path. It keeps the corpus current.

---

## 7. Architecture diagram

A simple mental model for `&memory.vector`:

~~~text
                    +---------------------+
                    |   incoming signal   |
                    |  query / document / |
                    |     context         |
                    +---------+-----------+
                              |
                              v
                    +---------------------+
                    |   &memory.vector    |
                    |                     |
                    |  - search           |
                    |  - upsert           |
                    |  - enrich           |
                    +---------+-----------+
                              |
               +--------------+--------------+
               |              |              |
               v              v              v
     +----------------+ +------------+ +---------------+
     | enriched       | | ack        | | retrieval     |
     | context        | |            | | hits          |
     +------+---------+ +------------+ +---------------+
            |
            v
   +---------------------+
   | downstream reason / |
   | graph / output flow |
   +---------------------+
~~~

---

## 8. Example declaration

A concrete `ampersand.json` fragment:

~~~json
{
  "&memory.vector": {
    "provider": "pgvector",
    "config": {
      "instance": "support-kb"
    }
  }
}
~~~

A fuller declaration (`customer-support.ampersand.json`):

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "SupportAgent",
  "version": "1.0.0",
  "capabilities": {
    "&memory.vector": {
      "provider": "pgvector",
      "config": {
        "instance": "support-kb"
      }
    },
    "&memory.episodic": {
      "provider": "default",
      "config": {
        "session_scope": "customer"
      }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "standard"
      }
    }
  },
  "provenance": true
}
~~~

A research-oriented declaration (`research-agent.ampersand.json`):

~~~json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "ResearchAgent",
  "version": "1.0.0",
  "capabilities": {
    "&memory.vector": {
      "provider": "weaviate",
      "config": {
        "instance": "research-corpus"
      }
    },
    "&memory.graph": {
      "provider": "graphonomous",
      "config": {
        "instance": "research-kg"
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

### Search request

~~~json
{
  "capability": "&memory.vector",
  "operation": "search",
  "input": {
    "query_context": {
      "query": "how to reset account password after lockout",
      "top_k": 5
    }
  }
}
~~~

### Search response

~~~json
{
  "capability": "&memory.vector",
  "operation": "search",
  "output": {
    "retrieval_hits": [
      {
        "document_id": "kb-article-2041",
        "title": "Account lockout recovery procedure",
        "score": 0.94,
        "snippet": "When an account is locked after repeated failed login attempts..."
      },
      {
        "document_id": "kb-article-1893",
        "title": "Password reset flow for enterprise accounts",
        "score": 0.87,
        "snippet": "Enterprise accounts use a separate reset pathway..."
      }
    ]
  }
}
~~~

### Enrich request

~~~json
{
  "capability": "&memory.vector",
  "operation": "enrich",
  "input": {
    "query_context": {
      "query": "customer reports inability to access dashboard after migration",
      "top_k": 3
    }
  }
}
~~~

### Enrich response

~~~json
{
  "capability": "&memory.vector",
  "operation": "enrich",
  "output": {
    "enriched_context": {
      "relevant_articles": [
        "kb-article-3102",
        "kb-article-2891"
      ],
      "relevant_policies": [
        "migration-access-policy-v2"
      ],
      "semantic_summary": "Two knowledge base articles and one migration policy document are relevant to post-migration dashboard access issues."
    }
  }
}
~~~

---

## 10. Compatible providers

`&memory.vector` is a capability interface. Compatible providers are implementations that can satisfy the contract.

Representative providers:

- `pgvector` (default)
- `weaviate`
- custom embedding-backed retrieval services wrapped behind a protocol-compatible surface
- managed vector database services with a compatible API shape

### Current default ecosystem fit

- `pgvector` is the default provider in this repository

Why it fits:

- widely deployed and operationally simple
- embeds directly into PostgreSQL infrastructure many teams already run
- suitable for search, upsert, and enrichment workflows
- no separate cluster required for moderate-scale corpora

### Alternative provider: Weaviate

Why it fits:

- purpose-built for vector search at scale
- supports hybrid search (vector + keyword)
- suitable for larger corpora or workloads requiring dedicated vector infrastructure

---

## 11. A2A-facing skills

A `&memory.vector` capability may advertise skills such as:

- `semantic-retrieval`
- `knowledge-base-enrichment`

These skills are useful when generating A2A agent cards from a declaration, because they let an externally visible agent surface say more than just "has memory." A downstream agent or orchestrator can discover that this agent offers semantic retrieval as a specific skill.

---

## 12. Governance implications

Vector retrieval often serves as the grounding layer for agent responses, so governance matters.

Examples of governance constraints that commonly pair with `&memory.vector`:

### Hard constraints

- never return restricted or access-controlled documents outside authorized workflows
- never surface confidential knowledge-base content to unauthorized callers
- always preserve audit trail for retrieval-grounded decision support

### Soft constraints

- prefer higher-confidence retrieval hits when multiple results are available
- prefer recent documents when relevance scores are similar
- prefer policy-tagged documents over untagged material in compliance-sensitive domains

### Escalation triggers

- escalate when no retrieval hits meet the minimum relevance threshold
- escalate when retrieved material conflicts with known policy

Standard retrieval governance applies: the governance mode for `&memory.vector` is straightforward compared to graph or reasoning capabilities, because the operation is read-heavy and the primary risk is surfacing wrong or restricted content rather than taking irreversible action.

---

## 13. Provenance implications

`&memory.vector` should participate in the provenance chain.

Representative provenance record:

~~~json
{
  "source": "&memory.vector",
  "provider": "pgvector",
  "operation": "search",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:3e4f...",
  "output_hash": "sha256:9a1b...",
  "parent_hash": "sha256:0000..."
}
~~~

This matters because vector retrieval results often directly ground downstream reasoning. If an agent responds to a customer based on a retrieved article, or if a research agent cites a retrieved paper, the retrieval step should be auditable. Provenance makes it possible to trace which documents were surfaced and when.

---

## 14. Typical use cases

`&memory.vector` is especially strong in the following domains.

### Customer support

- knowledge-base article retrieval for customer questions
- policy document lookup for escalation decisions
- grounding agent responses in approved content

### Research systems

- corpus-level semantic search over papers, notes, and claims
- literature retrieval for evidence synthesis
- semantic matching of new findings against prior work

### Compliance and policy

- regulatory document retrieval
- policy section lookup for audit or review workflows
- grounding decisions in authoritative source material

### General agent grounding

- semantic context enrichment before reasoning
- document retrieval for RAG (retrieval-augmented generation) pipelines
- knowledge-base maintenance through upsert workflows

---

## 15. Anti-patterns

Avoid these mistakes when modeling `&memory.vector`.

### Anti-pattern 1: treating vector retrieval as relationship-aware

Vector memory finds what is similar in embedding space. It does not know how things connect. If relationship structure matters, use `&memory.graph` instead or alongside.

### Anti-pattern 2: collapsing provider and capability

`pgvector` is not the protocol capability.
`&memory.vector` is.

### Anti-pattern 3: using vector retrieval without provenance

If retrieved content influences action, the retrieval step should be preserved in the provenance chain.

### Anti-pattern 4: using vector memory as the only memory capability

Vector retrieval is strong for corpus search but does not replace session history (`&memory.episodic`) or structured relationship memory (`&memory.graph`). In many systems, `&memory.vector` works best as one layer in a multi-memory architecture.

### Anti-pattern 5: assuming embedding quality is uniform

Different embedding models produce different quality results for different domains. The capability abstraction is stable, but provider configuration (embedding model, chunking strategy, distance metric) affects retrieval quality significantly.

---

## 16. Related capabilities

Closest related protocol capabilities:

- `&memory.graph`
- `&memory.episodic`
- `&reason.argument`

Common high-value compositions:

- `&memory.vector` + `&memory.episodic` + `&reason.argument` (policy-grounded support)
- `&memory.vector` + `&memory.graph` (hybrid retrieval)
- `&memory.vector` + `&reason.argument` (grounded reasoning over retrieved evidence)

---

## 17. Research references

This capability is informed by both information retrieval research and modern retrieval-augmented generation architecture.

Useful reference directions:

- dense passage retrieval and bi-encoder models
- approximate nearest neighbor search (HNSW, IVF, product quantization)
- retrieval-augmented generation (RAG) systems
- hybrid search combining vector and keyword retrieval
- embedding model evaluation and domain adaptation
- vector database architecture and scaling patterns
- chunking and document segmentation strategies for retrieval quality

The protocol does not prescribe a specific embedding model or retrieval algorithm. The value of this capability is in the stable interface, not the implementation details.

---

## 18. Summary

`&memory.vector` is the [&] Protocol capability for semantic vector retrieval.

It is the right capability when an agent needs:

- corpus-level semantic search
- knowledge-base grounding for responses
- document retrieval by meaning rather than exact terms
- context enrichment from embedded corpora
- a write path for keeping the knowledge base current

In one sentence:

> `&memory.vector` lets an agent find what is semantically relevant across a knowledge corpus.

---
