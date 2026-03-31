# `&govern`: Cross-Cutting Governance for Agents

The `&govern` capability family represents an agent's ability to **enforce policy, verify identity, emit telemetry, manage cost budgets, and escalate to humans** — the cross-cutting governance concerns that apply to every other primitive.

In the [&] Protocol, `&govern` is the fifth cognitive primitive:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are
- `&govern` — who is acting, under what rules, at what cost

Unlike the first four primitives, which map to cognitive domains, `&govern` is **cross-cutting**. It does not exist in isolation — it wraps, constrains, and observes the other four. Every `&memory` operation can emit telemetry. Every `&reason` decision can trigger escalation. Every `&space` action can be identity-verified. Every `&time` forecast can be budget-checked.

---

## Why `&govern` exists as a first-class primitive

Agent governance is the most underfunded and underspecified area of AI infrastructure. As of 2025, only $414M has been invested across all dedicated AI safety/governance startups — less than 5% of total AI security investment.

Yet Gartner predicts 40% of agentic AI projects will be scrapped by 2027, primarily due to governance failures:

- agents that exceed cost budgets with no enforcement mechanism
- agents that impersonate other agents with no identity verification
- agents that make high-stakes decisions with no human escalation path
- agents that operate opaquely with no telemetry or audit trail
- multi-agent systems where no one knows which agent did what

These are not feature requests. They are **enterprise-blocking gaps**.

Treating governance as a first-class capability — rather than an afterthought bolted onto application code — allows the protocol to express:

- that an agent has governance constraints at all
- what kind of governance it has (telemetry, escalation, identity)
- which provider implements each governance concern
- how governance composes with memory, reasoning, time, and space
- what events, budgets, and escalation rules are enforced

Without `&govern`, governance tends to be hidden inside ad hoc middleware, provider-specific plugins, or manual compliance processes. The result is architecture that works in demos but fails in production.

---

## What `&govern` means in the protocol

At the protocol level, `&govern` is not a vendor, dashboard, or compliance tool.

It is a **capability interface family**.

That means:

- `&govern.telemetry` is a protocol capability
- `opensentience` is one provider that may satisfy it
- another provider could also satisfy `&govern.telemetry` if it implements the same contract

This separation is important.

If governance were modeled only as provider-specific configuration, then changing your observability stack would require rewriting your agent declarations. By modeling `&govern` as an interface family, the protocol stays portable.

---

## Common `&govern` subtypes

### `&govern.telemetry`

Represents the observability backbone: structured event emission, metric queries, and budget enforcement.

Typical concerns:

- emitting structured telemetry events (OpenTelemetry-compatible)
- tracking token consumption and cost per task and per period
- enforcing budget limits from Delegatic policy trees
- querying historical telemetry for audit and analysis
- detecting anomalous agent behavior via cost or usage patterns

This is the subtype most relevant to cost management, observability, and compliance.

### `&govern.escalation`

Represents the human-in-the-loop bridge: structured handoff from autonomous operation to human review.

Typical concerns:

- escalating when confidence falls below a threshold
- escalating when cost exceeds a budget
- escalating when a hard governance boundary is approached
- escalating when policy explicitly requires human approval
- tracking escalation history and response patterns

This subtype matters whenever autonomous operation must have a safety valve.

### `&govern.identity`

Represents cross-runtime agent identity: verification, registration, and trust.

Typical concerns:

- verifying that an agent is who it claims to be (manifest hash, spec hash)
- registering agent identity on publish or deployment
- resolving agent identity from an ID or manifest reference
- preventing agent impersonation in multi-agent systems
- associating governance policies with verified identities

This subtype is essential for multi-agent systems where trust between agents is not assumed.

### Future subtype candidates

As the protocol evolves, additional governance subtypes may emerge:

- `&govern.audit` — dedicated audit trail management
- `&govern.consent` — user consent and data governance
- `&govern.compliance` — regulatory compliance checks
- `&govern.rate_limit` — fine-grained rate limiting per capability

The protocol should stay conservative at the primitive level and extensible at the subtype level.

---

## What problems `&govern` solves

`&govern` gives the protocol a standard place to express capabilities like:

- tracking what every agent does and what it costs
- enforcing budget limits across an org hierarchy
- verifying agent identity before allowing collaboration
- escalating to humans when confidence or cost thresholds are crossed
- auditing the full provenance chain of a decision
- detecting and preventing adversarial behavior (OS-007)

These are especially important when agents operate autonomously, at scale, across organizational boundaries.

Example:

A fleet management agent optimizes delivery routes. Without `&govern`:

- No one knows how many tokens it consumed this month
- No one can verify it's the same agent that was tested and approved
- If it encounters an edge case it can't handle, it either hallucinates or fails silently
- If it exceeds the cost budget, there's no enforcement mechanism

With `&govern.telemetry + &govern.identity + &govern.escalation`:

- Every route optimization emits a telemetry event with token count and cost
- The agent's identity is verified against its FleetPrompt manifest on deployment
- When confidence drops below 0.6, it escalates to a human dispatcher
- When cost exceeds `max_cost_usd_per_task`, the operation is rejected with a clear budget error

---

## How `&govern` differs from the governance block

The `ampersand.json` `governance` block declares **what rules apply** (hard constraints, soft preferences, escalation thresholds).

The `&govern` capability declares **which systems enforce those rules**.

They are complementary:

```json
{
  "capabilities": {
    "&govern.telemetry": {
      "provider": "opensentience",
      "config": { "org_id": "org_acme" }
    },
    "&govern.escalation": {
      "provider": "opensentience",
      "config": { "timeout_seconds": 300 }
    }
  },
  "governance": {
    "hard": ["Never exceed $50 per task"],
    "escalate_when": {
      "confidence_below": 0.7,
      "cost_exceeds_usd": 50
    },
    "autonomy": {
      "level": "advise",
      "budget": {
        "max_cost_usd_per_task": 50,
        "max_tokens_per_period": 1000000
      }
    }
  }
}
```

The `governance` block is the **policy declaration**. The `&govern` capabilities are the **enforcement mechanisms**.

---

## How `&govern` composes with the other primitives

### `&govern` + `&memory`

Every memory operation can emit telemetry. Memory consolidation cycles can be budget-checked. Knowledge graph mutations can trigger identity verification for the writing agent.

Together they support:

- tracking which agent wrote which knowledge
- enforcing storage budgets
- auditing knowledge provenance

### `&govern` + `&reason`

Every deliberation can be cost-tracked. High-stakes decisions can trigger escalation. Voting agents can be identity-verified before participating.

Together they support:

- budget-bounded deliberation
- human review of critical decisions
- preventing impersonation in multi-agent voting

### `&govern` + `&time`

Temporal forecasts and anomaly detections can emit telemetry. Expensive SSM inference can be budget-checked. Anomaly thresholds can trigger escalation when they exceed governance bounds.

Together they support:

- cost tracking for temporal intelligence operations
- degraded-mode fallback when compute budget is exhausted
- human review of high-impact temporal predictions

### `&govern` + `&space`

Route optimizations can emit telemetry with compute cost. Geofence boundary crossings can trigger escalation. Fleet operations agents can be identity-verified before accessing sensitive location data.

Together they support:

- spatial operation cost tracking
- compliance escalation on boundary violations
- identity-gated access to fleet data

### Full composition: all five primitives

```
stream_data
  |> &time.anomaly.detect()
  |> &govern.telemetry.emit()
  |> &space.fleet.enrich()
  |> &govern.telemetry.budget_check()
  |> &memory.graph.enrich()
  |> &reason.argument.evaluate()
  |> &govern.escalation.escalate()   # if confidence < threshold
```

This pipeline shows how `&govern` weaves through the other four primitives — not as a separate stage, but as an observability and enforcement layer that accompanies every operation.

---

## Typical providers

### `opensentience`

The primary runtime enforcement provider. Implements:

- OS-006: Agent Governance Shim (permission engine, lifecycle, autonomy levels)
- OS-007: Adversarial Robustness (identity verification, budget enforcement, circuit breakers)
- OS-008: Agent Harness (pipeline enforcement, quality gates, sprint contracts, context management)

### `delegatic`

The policy source provider. Provides:

- Monotonic policy inheritance (budget limits flow from root to leaf orgs)
- Budget fields: `max_tokens_per_task`, `max_cost_usd_per_period`, etc.
- Policy merge semantics: AND for booleans, MIN for numerics, INTERSECTION for allow-lists

### `fleetprompt`

The identity registry provider. Provides:

- Agent manifest registration on publish
- Identity verification for marketplace agents
- Trust score computation from test coverage + spec compliance + usage history

---

## Anti-patterns

### Anti-pattern 1: Treating governance as optional

If an agent operates autonomously, governance is not optional. Skipping `&govern` declarations doesn't remove governance concerns — it just makes them invisible.

### Anti-pattern 2: Hardcoding budget limits in application code

Budget limits should flow from Delegatic policy trees, not be hardcoded per agent. Use `&govern.telemetry.budget_check()` against the policy tree.

### Anti-pattern 3: Identity verification only at deploy time

Agent identity should be verified continuously — not just when first deployed. Use `&govern.identity.verify()` before accepting collaboration requests.

### Anti-pattern 4: Escalation as error handling

Escalation is a governance-mandated handoff, not an error. Design escalation paths as first-class workflows, not exception handlers.

### Anti-pattern 5: Telemetry without structured schemas

Unstructured log messages are not telemetry. Use the OpenTelemetry-compatible event schema with typed fields (trace_id, agent_id, capability, tokens_consumed, cost_usd_estimated).

---

## Summary

`&govern` is the protocol's answer to the question:

**How does an agent operate safely, transparently, and within bounds?**

It matters because autonomous agents without governance are demos, not products.

`&govern` makes governance:

- explicit in the declaration
- separable from providers
- contract-aware
- composable with memory, time, space, and reason
- enforceable
- auditable
- compilable into downstream agent artifacts

If `&memory` helps the agent remember,
and `&reason` helps it decide,
and `&time` helps it understand change,
and `&space` helps it stay grounded in the world,

then `&govern` ensures it does all of that **safely, transparently, and within the rules**.
