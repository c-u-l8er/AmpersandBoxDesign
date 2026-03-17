# `&memory.episodic` — Experience, Session History, and Replayable Context

`&memory.episodic` is the [&] Protocol capability for **experience-based memory**.

If `&memory.graph` is best for structured relationships and `&memory.vector` is best for semantic retrieval, `&memory.episodic` is best for remembering **what happened before** in a way that preserves sequence, case context, and replayable experience.

It is the memory surface you use when an agent should not only know facts, but also remember prior episodes, sessions, interactions, incidents, routes, or workflows as lived sequences.

---

## 1. Why `&memory.episodic` exists

Many real agents need more than abstract knowledge retrieval.

They need to answer questions like:

- What happened in the last interaction with this customer?
- Which prior escalation path was used for a similar case?
- What was the sequence of steps during the last incident response?
- Which route adjustments were made during the previous disruption?
- What actions were attempted before the system escalated?
- What did the agent observe, in order, across a prior session?

These are **episodic** questions.

A document retriever may retrieve policy.
A graph memory may retrieve linked entities or incidents.
But neither alone is the same as preserving a **replayable experience**.

That is why `&memory.episodic` exists as its own capability.

---

## 2. What `&memory.episodic` means in the protocol

At the protocol level, `&memory.episodic` is a capability interface for memory that stores and recalls **ordered prior experiences**.

It is meant for artifacts such as:

- prior sessions
- customer interactions
- incident timelines
- workflow executions
- route histories
- action traces
- case-specific context sequences

An episodic memory system should make it possible to:

- store new experiences
- recall relevant prior episodes
- replay or reconstruct prior sequences
- enrich current work with experience-derived context

That makes `&memory.episodic` especially useful for continuity, postmortem analysis, escalation support, and case-based reasoning.

---

## 3. Cognitive intuition

The four protocol primitives can be read like this:

- `&memory` — what the agent can retain
- `&reason` — how the agent decides
- `&time` — how it understands change over time
- `&space` — how it understands where things are

Within `&memory`, the episodic subtype specifically answers:

> What has this agent, user, case, or system experienced before?

This is different from:

- semantic memory: generalized knowledge
- graph memory: linked structured knowledge
- working memory: short-lived active context

`&memory.episodic` is about **remembered experience**.

---

## 4. When to use `&memory.episodic`

Use `&memory.episodic` when your agent needs one or more of these:

### Session continuity
Remembering prior steps in an ongoing or repeated interaction.

### Case history
Preserving what happened in a specific support case, incident, claim, ticket, or workflow.

### Replayability
Reconstructing prior sequences in order, rather than only retrieving isolated facts.

### Experience-based enrichment
Using similar prior episodes to enrich a current task.

### Escalation context
Passing forward a concise but faithful representation of what has already been tried.

### Outcome-aware learning
Recording what actions were taken and what happened afterward.

---

## 5. Typical use cases

### Customer support
A support agent should remember prior user interactions, previously attempted fixes, and earlier escalations.

### Incident response
An operations agent should recall the sequence of steps taken in similar incidents.

### Logistics and routing
A fleet system should remember prior route changes, delays, handoffs, and corrective actions.

### Research workflows
A research assistant may preserve prior investigation episodes, not just the final notes.

### Agent orchestration
A workflow agent may need to remember which tools were called, in what order, and what the outcomes were.

### Compliance and audit trails
An agent should preserve a replayable case history where sequence matters for review.

---

## 6. How `&memory.episodic` differs from other memory subtypes

### `&memory.episodic` vs `&memory.vector`

- `&memory.vector` is strong for semantic retrieval across a document corpus.
- `&memory.episodic` is strong for recalling prior experiences as episodes.

Vector memory answers:
- What content is semantically similar?

Episodic memory answers:
- What happened in a similar prior case?

### `&memory.episodic` vs `&memory.graph`

- `&memory.graph` is strong for relationships and durable structured knowledge.
- `&memory.episodic` is strong for sequences and lived case history.

Graph memory answers:
- What entities, dependencies, and relationships connect here?

Episodic memory answers:
- What was the prior sequence of events?

### `&memory.episodic` vs `&time.*`

Temporal capabilities detect anomalies, patterns, or forecasts.
Episodic memory preserves what was experienced.

Time answers:
- What is changing?
- What pattern is emerging?

Episodic memory answers:
- What happened previously in comparable situations?

---

## 7. Common operations

A representative `&memory.episodic` contract often includes operations like:

- `recall`
- `store`
- `replay`
- `enrich`

### `recall`
Retrieve prior episodes relevant to the current context.

### `store`
Persist a new episode, event, or session artifact.

### `replay`
Reconstruct a prior sequence into a usable replayed context.

### `enrich`
Attach relevant prior episode information to a current task or context payload.

These are protocol-level operations. A provider may have more internal complexity, but these operations are the kinds of surfaces the protocol should standardize.

---

## 8. Example contract

A representative standalone contract artifact for `&memory.episodic` may look like this:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&memory.episodic",
  "provider": "graphonomous",
  "version": "0.1.0",
  "description": "Episodic memory contract for storing, replaying, and enriching agents with prior experiences and session history.",
  "operations": {
    "recall": {
      "in": "query_context",
      "out": "episode_set",
      "description": "Retrieve prior episodes relevant to the current context."
    },
    "store": {
      "in": "episode_event",
      "out": "ack",
      "description": "Persist a new episode or session event."
    },
    "replay": {
      "in": "episode_set",
      "out": "replayed_context",
      "description": "Reconstruct ordered prior context from stored episodes."
    },
    "enrich": {
      "in": "context",
      "out": "enriched_context",
      "description": "Augment the current context with relevant prior experiences."
    }
  },
  "accepts_from": [
    "&reason.*",
    "&time.*",
    "context",
    "episode_event",
    "query_context"
  ],
  "feeds_into": [
    "&reason.*",
    "&memory.*",
    "output"
  ],
  "a2a_skills": [
    "episodic-memory-recall",
    "experience-replay",
    "session-history-enrichment"
  ]
}
```

This is useful because it makes episodic memory composable and machine-checkable rather than hand-wavy.

---

## 9. Declaration examples

### Explicit provider binding

```json
{
  "&memory.episodic": {
    "provider": "graphonomous",
    "config": {
      "instance": "customer-support-history",
      "retention_days": 90
    }
  }
}
```

### Auto provider binding

```json
{
  "&memory.episodic": {
    "provider": "auto",
    "need": "replayable support case history with escalation continuity"
  }
}
```

Use explicit binding when you know the provider.
Use `provider: "auto"` when you want the registry/runtime to resolve the provider from the declared need.

---

## 10. Example providers

The protocol is provider-agnostic, but representative providers for episodic memory include:

### `graphonomous`
A natural example provider where episodic memory can be layered alongside graph-backed learning and recall.

### Custom application memory service
A case-history or session-history service may satisfy `&memory.episodic` if it exposes the right contract.

### Workflow event store
A workflow execution service may satisfy parts of episodic memory if it supports replayable sequence retrieval and enrichment.

The important distinction remains:

- `&memory.episodic` = capability
- `graphonomous` or another service = provider

---

## 11. Architecture patterns

### Pattern 1: support continuity

Composition:

- `&memory.episodic`
- `&memory.vector`
- `&reason.argument`

Use this when the system should combine prior customer history with policy retrieval and then decide how to respond.

Typical flow:

```text
support_case
|> &memory.episodic.recall()
|> &memory.vector.search()
|> &reason.argument.evaluate()
|> &memory.episodic.store()
```

What this does:

1. recalls prior case history
2. retrieves relevant documentation or policy
3. evaluates the best response
4. stores the new interaction as another episode

### Pattern 2: incident replay

Composition:

- `&time.anomaly`
- `&memory.episodic`
- `&reason.argument`

Use this when prior incident sequences matter as much as current anomaly signals.

Typical flow:

```text
stream_data
|> &time.anomaly.detect()
|> &memory.episodic.enrich()
|> &reason.argument.evaluate()
|> &memory.episodic.store()
```

What this does:

1. detects an anomaly
2. enriches the current incident with similar prior incident sequences
3. evaluates what to do
4. stores the current case outcome for future replay

### Pattern 3: workflow replay and audit

Composition:

- `&memory.episodic`
- `&reason.plan`

Use this when the system needs to reconstruct prior workflow steps before building the next plan.

Typical flow:

```text
workflow_context
|> &memory.episodic.recall()
|> &memory.episodic.replay()
|> &reason.plan.plan()
```

What this does:

1. recalls related prior workflow episodes
2. reconstructs the useful execution trace
3. builds a new plan using that history

---

## 12. Example APIs and payload shapes

Episodic providers will vary, but the interface usually implies payloads like these.

### Example `recall` input

```json
{
  "case_id": "SUP-10492",
  "customer_id": "cust_8821",
  "topic": "refund dispute",
  "max_results": 5
}
```

### Example `recall` output

```json
{
  "episodes": [
    {
      "episode_id": "ep_001",
      "summary": "Customer contacted support about duplicate billing and requested refund review.",
      "timestamp": "2026-03-01T13:11:00Z",
      "tags": ["billing", "refund", "escalation"],
      "outcome": "manual review"
    },
    {
      "episode_id": "ep_002",
      "summary": "Customer returned after review with follow-up documentation.",
      "timestamp": "2026-03-02T09:43:00Z",
      "tags": ["billing", "documents"],
      "outcome": "policy exception denied"
    }
  ]
}
```

### Example `store` input

```json
{
  "case_id": "SUP-10492",
  "episode_event": {
    "summary": "Agent escalated case after confidence dropped below threshold.",
    "timestamp": "2026-03-03T16:28:00Z",
    "actor": "CustomerSupport",
    "outcome": "escalated"
  }
}
```

### Example `replay` output

```json
{
  "replayed_context": {
    "timeline": [
      "Initial customer complaint received",
      "Knowledge base consulted",
      "Refund policy checked",
      "Confidence dropped below threshold",
      "Case escalated to human reviewer"
    ],
    "summary": "Prior workflow attempted standard refund validation before escalation."
  }
}
```

These are not canonical protocol payloads, but they show the shape of experience-oriented memory surfaces.

---

## 13. Governance considerations

Episodic memory is often highly sensitive because it may contain user, operational, or case history.

That means governance matters.

### Common hard constraints

Examples:

- Never expose one customer’s prior episodes to another customer.
- Never replay private history outside an authorized workflow.
- Always preserve audit trail for escalations and account-affecting actions.
- Never store sensitive episode data without retention and access policy.

### Common soft constraints

Examples:

- Prefer concise summaries over full replay when the full episode is not required.
- Prefer policy-grounded replay over speculative reconstruction.
- Prefer recent relevant episodes over stale ones.

### Common escalation rules

Examples:

- escalate when confidence in case interpretation is below threshold
- escalate when a hard privacy boundary is approached
- escalate when episodic replay indicates repeated unresolved attempts

A representative governance block might look like this:

```json
{
  "governance": {
    "hard": [
      "Never reveal private customer case history outside authorized support workflows",
      "Always preserve an audit trail for escalations and account changes"
    ],
    "soft": [
      "Prefer concise replay summaries unless a full timeline is required"
    ],
    "escalate_when": {
      "confidence_below": 0.75,
      "hard_boundary_approached": true
    }
  }
}
```

---

## 14. Provenance implications

`&memory.episodic` should be provenance-aware because replayed history can influence a live decision.

A provenance record for an episodic memory step may include:

- source capability
- provider
- operation
- timestamp
- input hash
- output hash
- parent hash

Representative example:

```json
{
  "source": "&memory.episodic",
  "provider": "graphonomous",
  "operation": "recall",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:aa91...",
  "output_hash": "sha256:cc42...",
  "parent_hash": "sha256:0000..."
}
```

This matters for questions like:

- Which prior case history was used?
- Why did the agent decide to escalate?
- Which episode influenced the current response?
- Was the replayed context policy-appropriate?

Episodic memory without provenance quickly becomes hard to audit.

---

## 15. Research grounding

`&memory.episodic` is strongly aligned with classic distinctions between episodic and semantic memory.

The engineering interpretation is straightforward:

- episodic memory preserves experience traces
- semantic memory preserves generalized knowledge

That distinction remains useful in agent systems because prior sessions, incidents, and cases often matter even when they are not generalized into durable semantic knowledge.

Modern agent workflows reinforce this need:

- support systems need continuity
- incident systems need prior case replay
- planning systems need prior execution traces
- audit-sensitive systems need sequence-preserving history

The protocol turns that engineering need into a declarative capability surface.

---

## 16. Compatible providers

Representative compatible provider types include:

- graph-backed memory systems that support episode storage and replay
- event-store-backed case history systems
- workflow execution stores with replay support
- session-history services for conversational or support systems

Example provider IDs you might see in protocol artifacts:

- `graphonomous`
- custom internal episodic memory providers
- case-history services wrapped behind MCP-compatible interfaces

The capability page should always emphasize that provider compatibility is determined by contract satisfaction, not brand labeling.

---

## 17. Example pipeline diagram

A simple conceptual pipeline for episodic support handling:

```text
incoming_case
   |
   v
&memory.episodic.recall
   |
   v
&memory.vector.search
   |
   v
&reason.argument.evaluate
   |
   v
&memory.episodic.store
```

Interpretation:

- recall prior case experience
- retrieve current policy/support knowledge
- decide on the best action
- record the new episode for future continuity

---

## 18. A2A-facing implications

An `&memory.episodic` capability may compile into A2A-advertised skills such as:

- `episodic-memory-recall`
- `experience-replay`
- `session-history-enrichment`

This is useful because an externally coordinated agent may want to advertise not merely that it “has memory,” but that it can:

- recall prior experiences
- replay workflow history
- enrich tasks with case continuity

That makes the coordination layer more faithful to the actual agent architecture.

---

## 19. Anti-patterns

### Anti-pattern 1: using vector retrieval where sequence matters

If the task needs ordered prior experience, pure semantic retrieval may lose the structure that matters.

### Anti-pattern 2: collapsing every memory need into graph memory

Graph memory is powerful, but not every “what happened before?” question is best represented as a graph traversal.

### Anti-pattern 3: storing episode data without governance

Episodic memory often contains exactly the kind of history that privacy and audit policy must constrain.

### Anti-pattern 4: replay without provenance

If replayed history affects a decision, the system should preserve lineage.

---

## 20. Practical guidance

Choose `&memory.episodic` when you need:

- case continuity
- interaction history
- incident replay
- workflow sequence preservation
- experience-based enrichment

Prefer combining it with:

- `&memory.vector` for policy or document grounding
- `&reason.argument` for decision quality
- `&time.*` when prior sequences should be compared to current temporal behavior

A common production pattern is not to use episodic memory alone, but to combine it with another memory form and a reasoning layer.

---

## 21. Summary

`&memory.episodic` is the [&] Protocol capability for **remembered experience**.

It exists so that agents can do more than retrieve facts. They can also remember and replay what happened before in a way that preserves continuity, sequence, and case context.

It is especially useful for:

- customer support
- incident response
- workflow history
- case management
- audit-sensitive systems

At the protocol level, it gives you a way to declare:

- that the agent has episodic memory
- which provider satisfies it
- what operations it supports
- how it composes with reasoning, time, and other memory surfaces
- how governance and provenance apply

In short:

> `&memory.episodic` is how the [&] Protocol represents replayable experience as a first-class memory capability.
