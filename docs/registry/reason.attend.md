# `&reason.attend` — Proactive Attention and Bounded Autonomy for the [&] Protocol

`&reason.attend` is the capability page for the `&reason.attend` subtype in the [&] Protocol.

It represents a meta-reasoning surface for deciding **what should receive attention next**, under governance and budget constraints.

In short:

> `&reason.attend` is the protocol capability for agents that should not only reason about a task, but also reason about **which tasks to prioritize, defer, escalate, or propose**.

---

## 1. Definition

`&reason.attend` is a subtype of the `&reason` primitive.

It describes a capability that continuously or on-demand:

- surveys active context and goals
- triages attention candidates
- dispatches bounded actions according to autonomy policy

Typical outputs include:

- ranked attention maps
- dispatch decisions (`explore`, `focus`, `act`, `escalate`, `propose`, `idle`)
- cycle results suitable for storage, audit, and later learning

Unlike generic scheduling logic hidden in runtime code, `&reason.attend` makes this behavior explicit and composable.

---

## 2. Why this capability exists

Many agent systems fail not because they cannot reason, but because they cannot **allocate reasoning effort** well.

Real deployments need to answer:

- Which goal is most urgent now?
- Is coverage sufficient to act, or should we learn first?
- Is this region cyclic/uncertain and requiring deeper deliberation?
- Should we defer for approval, escalate, or proceed?
- Are we within autonomy and budget constraints?

`&reason.attend` exists so that these decisions are part of the protocol surface, not ad hoc internal glue.

This is especially important for:

- long-running agents
- multi-goal systems
- cost-constrained deployments
- safety-sensitive domains requiring escalation policy

---

## 3. Where it fits in the protocol

The [&] Protocol organizes cognition into four core primitives:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

`&reason.attend` sits under `&reason` and complements local decision subtypes by adding **meta-level control**:

- `&reason.argument` helps decide *between options*
- `&reason.plan` helps decide *sequences of actions*
- `&reason.deliberate` helps reason through *cyclic dependencies*
- `&reason.attend` helps decide *what to reason or act on next*

---

## 4. Capability contract

A representative contract for `&reason.attend`:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&reason.attend",
  "provider": "graphonomous",
  "version": "0.1.0",
  "description": "Proactive attention contract for surveying active goals, triaging epistemic gaps, and dispatching bounded autonomy actions.",
  "operations": {
    "survey": {
      "in": "context",
      "out": "attention_map",
      "description": "Build a ranked attention map from active goals, coverage assessments, and topology signals."
    },
    "triage": {
      "in": "attention_map",
      "out": "attention_map",
      "description": "Assign urgency, gap scores, and dispatch modes to attention items under governance and budget constraints."
    },
    "dispatch": {
      "in": "attention_map",
      "out": "attention_cycle",
      "description": "Execute or defer bounded explore/focus/act/escalate/propose dispatches according to autonomy level."
    }
  }
}
```

---

## 5. Operations

### `survey(context) -> attention_map`

Builds a ranked set of attention candidates from available context, for example:

- active goals
- retrieval signals
- coverage assessments
- topology/κ signals
- recent outcomes

### `triage(attention_map) -> attention_map`

Annotates and reorders attention items with fields such as:

- urgency
- epistemic gap
- confidence/risk notes
- selected dispatch mode
- bounded rationale

### `dispatch(attention_map) -> attention_cycle`

Executes or defers actions under policy and budget:

- `explore` — enrich memory/coverage
- `focus` — invoke deeper deliberation
- `act` — execute bounded action
- `escalate` — defer to higher-trust/human path
- `propose` — suggest new goal (if allowed)
- `idle` — no action

---

## 6. Architecture pattern

A common proactive loop:

```text
heartbeat
  |> &reason.attend.survey()
  |> &reason.attend.triage()
  |> &reason.attend.dispatch()
  |> &memory.graph.store()
```

A common demand-triggered loop (constrained tier):

```text
query
  |> &memory.graph.recall()
  |> &memory.graph.topology()
  |> &reason.attend.survey()
  |> &reason.attend.dispatch()
```

Interpretation:

- survey/triage gives explicit prioritization
- dispatch is budgeted and governed
- cycle artifacts can be persisted for provenance and learning feedback

---

## 7. Example declaration snippet (`ampersand.json`)

```json
{
  "capabilities": {
    "&reason.attend": {
      "provider": "graphonomous",
      "config": {}
    }
  },
  "governance": {
    "autonomy": {
      "level": "advise",
      "model_tier": "local_small",
      "heartbeat_seconds": 300,
      "budget": {
        "max_actions_per_hour": 5,
        "max_deliberation_calls_per_query": 1,
        "require_approval_for": ["act", "propose"]
      }
    }
  }
}
```

---

## 8. Governance implications

`&reason.attend` is where autonomy policy becomes operational.

Relevant governance fields:

- `hard` / `soft`
- `escalate_when`
- `autonomy.level` (`observe`, `advise`, `act`)
- `autonomy.model_tier` (`local_small`, `local_large`, `cloud_frontier`)
- `autonomy.heartbeat_seconds`
- `autonomy.budget` controls

Typical effect:

- `observe` → survey/triage only, no execution
- `advise` → propose actions, wait for approval
- `act` → execute bounded actions inside policy limits

---

## 9. Provenance implications

Attention decisions should be auditable.

A useful provenance chain should preserve:

- source context used for survey/triage
- selected mode and rationale
- governance/autonomy state at dispatch time
- output cycle summary and timestamps
- links to any resulting memory writes or action outcomes

This makes it possible to answer:

- Why was this goal prioritized?
- Why was action deferred/escalated?
- Which policy or budget boundary affected dispatch?

---

## 10. MCP and A2A implications

### MCP

A provider may expose tool surfaces such as:

- `attention_survey`
- `attention_run_cycle`

These allow external runtimes or operators to inspect and trigger attention behavior without custom APIs.

### A2A

`&reason.attend` commonly maps to skill identifiers like:

- `proactive-attention`
- `autonomous-planning`

This allows agent-to-agent systems to discover and delegate attention orchestration capabilities explicitly.

---

## 11. Anti-patterns

Common mistakes when modeling `&reason.attend`:

1. Treating attention as hidden scheduler logic with no contract.
2. Executing actions in autonomous mode without declared budget bounds.
3. Collapsing `survey`, `triage`, and `dispatch` into an opaque single step with no provenance.
4. Allowing `propose` in constrained environments without governance gates.
5. Confusing topology-derived routing (`&memory.graph` structural outputs) with a separate primitive.

---

## 12. Summary

`&reason.attend` turns “what should the agent focus on next?” into a first-class protocol capability.

It gives agent systems:

- explicit attention maps
- bounded dispatch behavior
- autonomy-aware governance integration
- auditable cycle artifacts
- clean composition with `&memory.graph` and `&reason.deliberate`

This is essential for robust, long-running agents that need disciplined prioritization, not only pointwise reasoning.