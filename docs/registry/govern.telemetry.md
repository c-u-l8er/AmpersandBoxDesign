# `&govern.telemetry` — Observability, Cost Tracking, and Budget Enforcement

`&govern.telemetry` is the [&] Protocol capability for **unified agent telemetry and budget enforcement**.

It describes an agent's ability to:

- emit structured telemetry events for every capability operation
- query historical telemetry by agent, capability, time range, or trace ID
- check current usage against Delegatic budget policies before executing actions
- provide the observability backbone for auditing, debugging, and anomaly detection
- feed cost and usage signals into escalation triggers

In the protocol's five-primitive model:

- `&memory` answers **what** the agent knows
- `&reason` answers **how** the agent decides
- `&time` answers **when** things change
- `&space` answers **where** things are
- `&govern` answers **who approves, what limits apply, and how decisions are audited**

`&govern.telemetry` is the subtype that answers: **what happened, how much did it cost, and are we within budget?**

---

## 1. Definition

`&govern.telemetry` is the capability interface for **structured observability, cost accounting, and budget enforcement**.

It is used when a system must:

- record structured events for every capability invocation
- track token consumption, cost, and compute time across agents and operations
- enforce budget limits defined by Delegatic org-level and agent-level policies
- provide queryable telemetry for audit, debugging, and operational analysis
- trigger escalation when usage approaches or exceeds defined thresholds

Telemetry is the observability backbone of the [&] Protocol. Without it, you cannot:

- enforce budgets
- audit decisions
- detect anomalous agent behavior
- attribute costs to specific agents, goals, or organizations
- debug multi-step capability pipelines

The protocol treats telemetry as a first-class governance capability, not an afterthought logging layer.

---

## 2. Why this capability exists

Many agent systems treat observability as optional or implementation-specific.

That works for single-agent prototypes, but it fails in production multi-agent deployments:

- An agent consumes expensive cloud frontier tokens, but no one tracks the cumulative cost until the monthly bill arrives.
- A multi-agent workflow produces an unexpected output, but there is no trace linking the sequence of capability operations that led to it.
- An organization sets budget limits for its agents, but the enforcement mechanism is disconnected from the agents' runtime.
- A governance audit requires evidence of what an agent did and why, but telemetry is scattered across provider-specific log formats.

In all of these cases, the missing layer is **structured, protocol-native telemetry with budget enforcement**.

`&govern.telemetry` gives the protocol a standard way to declare that capability.

---

## 3. What problems `&govern.telemetry` solves

`&govern.telemetry` is useful when a system needs to answer questions like:

- How many tokens has this agent consumed in the current period?
- What is the estimated cost of this agent's operations so far?
- Is this agent approaching its per-task or per-period budget limit?
- Which capability operations are the most expensive across the organization?
- What was the full trace of operations that led to this output?
- Are there anomalous patterns in agent behavior (unexpected cost spikes, unusual operation sequences)?
- Which goal or task is consuming the most resources?

Without this capability, telemetry tends to get buried inside:

- provider-specific logging systems with no cross-provider interoperability
- custom cost-tracking spreadsheets updated manually
- implicit budget assumptions with no enforcement mechanism
- unstructured log files that are difficult to query or audit

The protocol makes it explicit instead.

---

## 4. Capability role in the `&govern` namespace

The `&govern` primitive supports multiple subtypes, including:

- `&govern.escalation`
- `&govern.identity`
- `&govern.telemetry`

A helpful distinction is:

- `&govern.escalation` = decision handoff when thresholds are crossed
- `&govern.identity` = agent authentication and trust verification
- `&govern.telemetry` = observability, cost tracking, and budget enforcement

`&govern.telemetry` is the right subtype when the main problem is **knowing what agents are doing, how much it costs, and whether they are within budget**.

---

## 5. Typical use cases

### Operation-level telemetry
Every capability invocation emits a structured event recording the agent, capability, operation, duration, token consumption, and estimated cost.

### Budget pre-check
Before executing a potentially expensive operation, the agent calls `budget_check` to verify that the action will not exceed Delegatic policy limits.

### Cost attribution
Telemetry events include `org_id` and `goal_id` fields, enabling cost attribution by organization, project, or individual goal.

### Anomaly detection
Querying telemetry for unusual patterns (cost spikes, excessive operation counts, unexpected error rates) enables proactive governance intervention.

### Audit trail
Governance auditors query telemetry by trace ID to reconstruct the full sequence of capability operations that led to a specific outcome.

### Escalation triggering
When `budget_check` reveals that usage is approaching limits, the result can be fed into `&govern.escalation` to request human approval before proceeding.

---

## 6. Example capability contract

The authoritative contract is at `contracts/v0.1.0/govern.telemetry.contract.json`.

A representative summary:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&govern.telemetry",
  "provider": "opensentience",
  "version": "0.1.0",
  "description": "Unified telemetry contract for observability, cost tracking, and budget enforcement.",
  "operations": {
    "emit": {
      "in": "telemetry_event",
      "out": "ack",
      "description": "Emit a structured telemetry event to the collector."
    },
    "query": {
      "in": "telemetry_query",
      "out": "telemetry_results",
      "description": "Query telemetry events by agent, capability, time range, or trace ID."
    },
    "budget_check": {
      "in": "budget_query",
      "out": "budget_status",
      "description": "Check current usage against Delegatic policy limits."
    }
  },
  "accepts_from": [
    "&memory.*",
    "&reason.*",
    "&time.*",
    "&space.*",
    "&govern.*",
    "telemetry_event"
  ],
  "feeds_into": [
    "&govern.escalation",
    "output"
  ],
  "a2a_skills": [
    "telemetry-emission",
    "budget-enforcement",
    "cost-tracking"
  ]
}
```

### What this contract means

This contract says that `&govern.telemetry` can:

- accept telemetry events from every capability primitive (memory, reason, time, space, govern)
- provide structured query access to historical telemetry
- check usage against budget policies before operations proceed

It also says that this capability composes well with:

- all `&*` capabilities upstream, since every capability should emit telemetry
- `&govern.escalation` downstream, since budget violations trigger escalation

The `accepts_from` list is intentionally broad: `&govern.telemetry` is the universal collector for the entire capability stack.

---

## 7. Core operations

### `emit`

Purpose:
- record a structured telemetry event for a capability operation

Typical input:
- `telemetry_event`

Typical output:
- `ack`

Use when:
- any capability operation completes (successfully or with error)
- the system needs to record token consumption, cost, or duration
- provenance requires a telemetry record for the operation

### `query`

Purpose:
- retrieve historical telemetry events matching specified criteria

Typical input:
- `telemetry_query`

Typical output:
- `telemetry_results`

Use when:
- auditing a specific trace to reconstruct the operation sequence
- analyzing cost or usage patterns across agents, capabilities, or time ranges
- debugging unexpected behavior in multi-step pipelines

### `budget_check`

Purpose:
- verify that a planned operation will not exceed Delegatic budget limits

Typical input:
- `budget_query`

Typical output:
- `budget_status`

Use when:
- an agent is about to execute a potentially expensive operation
- the system needs to determine whether escalation is required before proceeding
- periodic budget monitoring checks are scheduled

---

## 8. OpenTelemetry-compatible event schema

Telemetry events conform to an OpenTelemetry-compatible schema:

- `trace_id` — UUIDv7 or W3C trace ID, linking related operations
- `span_id` — unique span identifier within the trace
- `agent_id` — the agent that performed the operation
- `capability` — the `&`-prefixed capability key (e.g., `&reason.plan`)
- `operation` — the specific operation (e.g., `plan`, `evaluate`)
- `provider` — the provider that executed the operation
- `timestamp_ms` — epoch milliseconds when the operation occurred
- `duration_ms` — wall-clock duration of the operation
- `tokens_consumed` — token count (if applicable)
- `cost_usd_estimated` — estimated cost in USD (if applicable)
- `compute_ms` — compute time in milliseconds (if applicable)
- `status` — `ok` or `error`
- `error_class` — error classification (if status is error)
- `org_id` — Delegatic org reference for cost attribution
- `goal_id` — Graphonomous goal reference for goal-level tracking
- `metadata` — provider-specific additional fields

This schema is designed to be compatible with existing OpenTelemetry infrastructure while carrying [&] Protocol-specific attribution fields.

---

## 9. Budget fields from Delegatic

Budget enforcement uses limits defined in Delegatic org-level and agent-level policies:

### Per-task limits
- `max_tokens_per_task` — maximum tokens an agent may consume for a single task
- `max_cost_usd_per_task` — maximum estimated cost in USD for a single task
- `max_compute_ms_per_task` — maximum compute time for a single task

### Per-period limits
- `max_tokens_per_period` — maximum tokens across all tasks within the budget period
- `max_cost_usd_per_period` — maximum estimated cost across all tasks within the budget period

### Budget status response

A `budget_check` response includes:

- current usage against each applicable limit
- percentage consumed
- whether any limit is exceeded or approaching threshold
- recommended action (proceed, warn, or escalate)

When a budget limit is approached or exceeded, the recommended action feeds directly into `&govern.escalation` for human review.

---

## 10. Architecture patterns

### Pattern A: emit on every operation

```text
capability_result
|> &govern.telemetry.emit()
|> continue_pipeline()
```

Use this when:
- every capability operation should be recorded for audit and cost tracking
- this is the default pattern and should be present in all production agents

### Pattern B: budget pre-check before expensive operations

```text
planned_action
|> &govern.telemetry.budget_check()
|> &govern.escalation.escalate_if_over_budget()
|> execute_if_approved()
```

Use this when:
- the planned operation is expected to consume significant tokens or cost
- Delegatic policy defines budget limits that must be enforced

### Pattern C: telemetry-driven anomaly detection

```text
periodic_check
|> &govern.telemetry.query(recent_window)
|> detect_anomalies()
|> &govern.escalation.escalate_if_anomalous()
```

Use this when:
- the system monitors for unusual agent behavior patterns
- cost spikes or unexpected error rates should trigger governance intervention

### Pattern D: full audit trace reconstruction

```text
audit_request
|> &govern.telemetry.query(trace_id)
|> reconstruct_operation_sequence()
|> generate_audit_report()
```

Use this when:
- a governance audit requires the complete operation history for a specific decision or outcome

---

## 11. Example declaration

A concrete `ampersand.json` fragment:

```json
{
  "&govern.telemetry": {
    "provider": "opensentience",
    "config": {
      "emit_all_operations": true,
      "budget_enforcement": "delegatic"
    }
  }
}
```

A fuller declaration:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "ResearchAnalyst",
  "version": "0.1.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "graphonomous",
      "config": {
        "mode": "continual-learning"
      }
    },
    "&reason.plan": {
      "provider": "auto",
      "need": "research analysis with cost-aware tool selection"
    },
    "&govern.telemetry": {
      "provider": "opensentience",
      "config": {
        "emit_all_operations": true,
        "budget_enforcement": "delegatic"
      }
    },
    "&govern.escalation": {
      "provider": "opensentience",
      "config": {
        "timeout_seconds": 1800
      }
    },
    "&govern.identity": {
      "provider": "opensentience",
      "config": {
        "registry": "fleetprompt",
        "verify_on_a2a": true
      }
    }
  },
  "governance": {
    "hard": [
      "Never exceed per-task budget without escalation",
      "Always emit telemetry for every capability operation"
    ],
    "soft": [
      "Prefer local_small model tier when task complexity permits",
      "Prefer cached results over fresh computation when staleness is acceptable"
    ],
    "escalate_when": {
      "confidence_below": 0.7,
      "cost_exceeds_usd": 100,
      "budget_remaining_below_percent": 20
    }
  },
  "provenance": true
}
```

---

## 12. Governance and provenance implications

Telemetry is inherently a governance and provenance tool. Every telemetry event is both an observability record and a governance artifact.

### Cross-references

- **OpenSentience OS-006**: defines autonomy levels that determine which operations require telemetry and at what granularity
- **OpenSentience OS-007**: addresses the threat of unaccounted agent operations — telemetry provides the detection layer for unauthorized or anomalous activity
- **Delegatic budget policies**: budget limits (per-task, per-period) are the enforcement targets that `budget_check` validates against
- **FleetPrompt trust scores**: telemetry history contributes to FleetPrompt's trust score computation — agents with consistent, auditable telemetry earn higher trust

### Representative provenance record

```json
{
  "source": "&govern.telemetry",
  "provider": "opensentience",
  "operation": "emit",
  "timestamp": "2026-03-15T12:00:00Z",
  "trace_id": "tr-01JQ7...",
  "agent_id": "agt-01JQ7...",
  "capability": "&reason.plan",
  "tokens_consumed": 4200,
  "cost_usd_estimated": 0.042,
  "duration_ms": 1850,
  "org_id": "org-acme",
  "goal_id": "goal-research-q1",
  "mcp_trace_id": "os-tel-155"
}
```

Provenance should help answer questions like:

- How much did this specific operation cost?
- What is the total cost attributed to this goal or organization?
- Which agent consumed the most tokens in this period?
- Was the budget check performed before this expensive operation?
- Which operations contributed to the budget threshold being crossed?

---

## 13. Compatible providers

Representative compatible providers include:

- `opensentience` (primary runtime telemetry collector)
- `delegatic` (budget policy definition and enforcement rules)
- OpenTelemetry-compatible collectors and backends
- custom observability platforms exposed behind MCP-compatible surfaces
- enterprise cost-management systems with structured event ingestion

### Default ecosystem fit

The most natural default ecosystem pairing is:

- `opensentience` for the telemetry runtime (collection, querying, emission)
- `delegatic` for budget policy definitions that drive enforcement

Why they fit together:
- OpenSentience collects and stores telemetry events from all capability operations
- Delegatic defines the budget policies that `budget_check` enforces
- Together they form the complete observability and cost governance stack

The protocol stance remains:

> `&govern.telemetry` is the capability.
> `opensentience` is one provider that may satisfy it.

---

## 14. A2A-facing skills

A `&govern.telemetry` capability may advertise skills such as:

- `telemetry-emission`
- `budget-enforcement`
- `cost-tracking`

These are useful when generating A2A-style agent cards, because they let an external coordination surface say more than "has telemetry."

Instead, it can say the agent can:

- emit structured telemetry for every capability operation
- enforce budget limits before executing expensive actions
- track and attribute costs by agent, goal, and organization

---

## 15. Anti-patterns

### Anti-pattern 1: treat telemetry as optional
In production multi-agent systems, every capability operation should emit telemetry. Skipping telemetry for "cheap" operations creates blind spots in audit trails and budget tracking.

### Anti-pattern 2: enforce budgets without telemetry
Budget enforcement without real-time telemetry is guesswork. The `budget_check` operation depends on accurate cumulative usage data from `emit`.

### Anti-pattern 3: emit telemetry without budget fields
Telemetry events that omit `tokens_consumed`, `cost_usd_estimated`, or `org_id` cannot be used for budget enforcement or cost attribution. Always include the full schema.

### Anti-pattern 4: query telemetry only for debugging
Telemetry is not just for debugging. It drives budget enforcement, anomaly detection, trust scoring, and governance audits. Treating it as a debug-only tool underutilizes the capability.

### Anti-pattern 5: separate telemetry from escalation
When budget limits are approached, the natural next step is escalation. Disconnecting telemetry from escalation creates a gap where budget violations go unaddressed.

---

## 16. Summary

`&govern.telemetry` is the [&] Protocol capability for **unified observability, cost tracking, and budget enforcement**.

It is the right capability when a system needs to:

- record structured telemetry for every capability operation
- track token consumption, cost, and compute time across agents
- enforce Delegatic budget policies before expensive operations proceed
- provide queryable audit trails for governance review
- feed usage signals into escalation when thresholds are approached

In one sentence:

> `&govern.telemetry` gives agents a protocol-native way to observe, measure, and enforce the cost of everything they do.

---
