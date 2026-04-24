# `&reason.deliberate` — κ-Aware Deliberation for the [&] Protocol

`&reason.deliberate` is the capability page for the `&reason.deliberate` subtype in the [&] Protocol.

It represents a reasoning surface optimized for **cyclic knowledge regions** where simple one-shot evaluation is often insufficient.

In short:

> `&reason.deliberate` is the protocol capability for agents that must reason through feedback loops using topology-aware decomposition and reconciliation.

---

## 1. Definition

`&reason.deliberate` is a subtype of `&reason`.

It describes a focused reasoning capability that consumes graph-structural context (for example SCCs, κ values, and fault lines) and produces:

- reconciled conclusions
- confidence-scored outputs
- optional crystallized knowledge suitable for write-back into memory

Unlike generic reasoning steps, `&reason.deliberate` is explicitly designed to operate on **non-acyclic** knowledge structures.

---

## 2. Why this capability exists

Many decision problems are not DAG-shaped. They contain circular dependencies such as:

- demand ↔ pricing feedback
- quality ↔ retention feedback
- risk ↔ intervention feedback

In these cases, a direct “retrieve then decide” step can underperform because the model must juggle mutually dependent assumptions.

`&reason.deliberate` exists to make this structure explicit and routable:

1. detect cyclic structure from memory topology
2. decompose along weak links (fault lines)
3. run focused passes on scoped partitions
4. reconcile intermediate conclusions

This improves controllability, auditability, and consistency in high-friction reasoning regions.

---

## 3. Where it fits in the protocol

The [&] Protocol organizes cognition, embodiment, and governance into six primitive families:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are
- `&body` — how the agent is instantiated in an environment (perception, action, affordance)
- `&govern` — who is acting, under what rules, at what cost

`&reason.deliberate` sits under `&reason` and composes most naturally with:

- `&memory.graph` (topology and retrieval grounding)
- `&reason.attend` (attention routing into deliberate work)
- `&memory.*` write-back flows for crystallized conclusions

---

## 4. Capability contract (representative)

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&reason.deliberate",
  "provider": "graphonomous",
  "version": "0.1.0",
  "description": "κ-driven deliberation contract for topology-aware focused reasoning over cyclic knowledge regions.",
  "operations": {
    "deliberate": {
      "in": "topology_result",
      "out": "deliberation_result"
    },
    "decompose": {
      "in": "topology_result",
      "out": "partitions"
    },
    "reconcile": {
      "in": "intermediate_conclusions",
      "out": "deliberation_result"
    }
  },
  "accepts_from": ["&memory.graph", "&memory.*", "topology_result", "context"],
  "feeds_into": ["&memory.graph", "&reason.*", "deliberation_result", "output"],
  "a2a_skills": ["topology-aware-deliberation", "fault-line-reconciliation"]
}
```

---

## 5. Operations

### `deliberate`
Runs focused reasoning over selected SCC regions and returns reconciled conclusions with confidence metadata.

### `decompose`
Splits cyclic regions into scoped partitions (typically by fault lines) for manageable passes.

### `reconcile`
Combines partition-level intermediates into a coherent result suitable for downstream action or memory write-back.

---

## 6. Composition patterns

### Pattern A — Topology-aware reactive reasoning

```text
query
  -> &memory.graph.recall()
  -> &memory.graph.topology()
  -> &reason.deliberate.deliberate()
  -> &memory.graph.learn()
```

Use when a query touches cyclic regions and requires deeper reasoning before action.

### Pattern B — Attention-triggered deliberation

```text
heartbeat_or_demand
  -> &reason.attend.survey()
  -> &reason.attend.triage()
  -> &reason.deliberate.deliberate()
  -> output
```

Use when an attention engine routes high-friction regions into explicit deliberation.

### Pattern C — Deliberate then justify

```text
topology_result
  -> &reason.deliberate.deliberate()
  -> &reason.argument.justify()
  -> output
```

Use when downstream stakeholders require structured justification artifacts.

---

## 7. Tier-aware behavior

Implementations may adapt `&reason.deliberate` by declared `model_tier`:

- `local_small`  
  Often uses single-pass strategy for higher κ only; may skip low-κ cycles below a floor.
- `local_large`  
  Typically supports multi-pass decomposition/reconciliation on κ > 0.
- `cloud_frontier`  
  Supports deeper multi-pass budgets and larger partition scopes.

This keeps routing semantics stable while adapting execution depth to available inference capacity.

---

## 8. Governance implications

`&reason.deliberate` should honor governance boundaries in both routing and output handling:

- respect escalation thresholds (`confidence_below`, cost limits, boundary flags)
- enforce hard constraints before downstream action dispatch
- avoid auto-execution when autonomy level is limited to `observe` or `advise`

A deliberation result should be treated as **decision support**, not unconditional permission to act.

---

## 9. Provenance implications

A deliberation step should preserve strong traceability, including:

- topology basis (SCC IDs, κ values, fault-line edges)
- operation name and provider
- input and output hashes
- parent trace linkage
- timestamps and any transport trace IDs

This is essential for replay, audit, and post-outcome learning loops.

---

## 10. Compatible providers

Current ecosystem-aligned provider:

- `graphonomous`

Protocol note: providers are implementations; `&reason.deliberate` remains the capability interface.

---

## 11. Anti-patterns

- Treating cyclic reasoning as plain one-shot ranking without topology context.
- Collapsing `decompose` and `reconcile` semantics into undocumented prompt hacks.
- Emitting deliberation outputs with no confidence or provenance linkage.
- Skipping governance checks and directly dispatching real-world actions.

---

## 12. Summary

`&reason.deliberate` formalizes a critical reasoning mode for cyclic, feedback-heavy domains.

It gives agent systems:

- explicit topology-aware routing
- scoped decomposition for hard reasoning regions
- reconciled, confidence-bearing conclusions
- clean composition with memory, governance, and provenance layers

This makes deliberation a portable protocol capability rather than ad hoc prompt behavior.