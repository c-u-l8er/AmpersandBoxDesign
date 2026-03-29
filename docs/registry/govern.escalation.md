# `&govern.escalation` — Human-in-the-Loop Escalation and Governance Handoff

`&govern.escalation` is the [&] Protocol capability for **governance-mandated escalation**.

It describes an agent's ability to:

- detect when a decision exceeds its authorized autonomy
- surface that decision to a human operator or governance layer
- pause execution until a response is received or timeout expires
- resume with an approved, rejected, or modified action
- maintain a queryable history of all escalation events

In the protocol's five-primitive model:

- `&memory` answers **what** the agent knows
- `&reason` answers **how** the agent decides
- `&time` answers **when** things change
- `&space` answers **where** things are
- `&govern` answers **who approves, what limits apply, and how decisions are audited**

`&govern.escalation` is the subtype that handles the critical handoff between autonomous agent action and human oversight.

---

## 1. Definition

`&govern.escalation` is the capability interface for **human-in-the-loop decision escalation**.

It is used when an agent must:

- pause before executing an action that crosses a governance threshold
- present a proposed action with rationale to a human reviewer
- wait for approval, rejection, or modification
- handle timeout behavior according to autonomy level
- record the full escalation lifecycle for audit

Escalation is NOT failure. It is a governance-mandated handoff when agent confidence or cost crosses thresholds defined by policy.

This distinction matters because agents that treat escalation as error will:

- suppress legitimate governance signals
- avoid surfacing uncertainty
- degrade trust over time

The protocol treats escalation as a first-class capability, not an exception path.

---

## 2. Why this capability exists

Many agent systems either operate fully autonomously or halt completely when uncertainty arises.

Neither extreme is acceptable in production governance:

- A logistics agent proposes a high-cost reallocation but has no mechanism to ask a human before committing.
- An infrastructure agent detects a hard boundary violation but silently logs it instead of requesting approval.
- A support agent encounters a policy-sensitive case but lacks a structured way to surface it to a supervisor.
- A planning agent operates below its confidence threshold but proceeds anyway because no escalation path exists.

In all of these cases, the missing layer is **structured escalation with defined trigger conditions, timeout behavior, and response semantics**.

`&govern.escalation` gives the protocol a standard way to declare that capability.

---

## 3. What problems `&govern.escalation` solves

`&govern.escalation` is useful when an agent needs to answer questions like:

- Should I proceed with this action given my current confidence level?
- Does this action exceed the cost threshold defined by Delegatic policy?
- Am I approaching a hard boundary that requires human sign-off?
- Does the current autonomy level (observe, advise, act) permit this operation?
- What should happen if no human responds within the timeout window?
- How do I resume execution after receiving approval or modification?

Without this capability, escalation logic tends to get buried inside:

- ad-hoc if/else blocks in application code
- implicit confidence thresholds with no auditability
- custom notification systems with no structured response path
- provider-specific approval workflows with no interoperability

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

`&govern.escalation` is the right subtype when the main problem is **controlling what happens at the boundary between autonomous action and human oversight**.

---

## 5. Typical use cases

### Confidence-based escalation
Agent confidence drops below the configured threshold during reasoning. The proposed action is surfaced for human review before execution.

### Cost-based escalation
A planned action would exceed the per-task or per-period cost budget defined in Delegatic policy. The agent requests approval before committing resources.

### Hard boundary escalation
The agent approaches a governance hard constraint (e.g., "never deploy to production without approval"). The boundary rule triggers mandatory human review.

### Policy-required approval
The autonomy level or org policy requires human sign-off for certain capability operations regardless of confidence or cost.

### Cross-agent escalation
In multi-agent workflows, one agent escalates to another agent's human operator when a collaborative decision crosses governance boundaries.

### Audit-driven escalation
Retrospective analysis of telemetry reveals that an action should have been escalated. The system flags it for review and updates escalation policy.

---

## 6. Example capability contract

The authoritative contract is at `contracts/v0.1.0/govern.escalation.contract.json`.

A representative summary:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&govern.escalation",
  "provider": "opensentience",
  "version": "0.1.0",
  "description": "Human-in-the-loop escalation contract for governance-mandated decision handoff.",
  "operations": {
    "escalate": {
      "in": "escalation_request",
      "out": "escalation_ack",
      "description": "Submit an action for human review. Agent pauses until response or timeout."
    },
    "respond": {
      "in": "escalation_response",
      "out": "resolution",
      "description": "Human operator approves, rejects, or modifies the escalated action."
    },
    "query": {
      "in": "escalation_query",
      "out": "escalation_history",
      "description": "Query pending, resolved, or expired escalations by agent, org, goal, or time range."
    }
  },
  "accepts_from": [
    "&reason.*",
    "&govern.telemetry",
    "escalation_request",
    "escalation_response"
  ],
  "feeds_into": [
    "&reason.*",
    "&govern.telemetry",
    "output"
  ],
  "a2a_skills": [
    "human-escalation-bridge",
    "approval-workflow"
  ]
}
```

### What this contract means

This contract says that `&govern.escalation` can:

- accept escalation requests from reasoning capabilities or telemetry triggers
- present them to a human operator via the escalation bridge
- return structured resolutions (approve, reject, modify)
- feed resolution outcomes back into reasoning and telemetry

It also says that this capability composes well with:

- `&reason.*` upstream, where reasoning produces actions that may require approval
- `&govern.telemetry` upstream, where cost or usage signals trigger escalation
- `&reason.*` downstream, where approved or modified actions resume execution

---

## 7. Core operations

### `escalate`

Purpose:
- submit a proposed action for human review

Typical input:
- `escalation_request`

Typical output:
- `escalation_ack`

Use when:
- the agent's confidence is below the configured threshold
- the estimated cost exceeds Delegatic policy limits
- a hard boundary constraint is approaching
- the autonomy level requires approval for this operation type

### `respond`

Purpose:
- deliver a human operator's decision back to the requesting agent

Typical input:
- `escalation_response`

Typical output:
- `resolution`

Use when:
- a human has reviewed the escalated action and chosen to approve, reject, or modify it

### `query`

Purpose:
- inspect the history and status of escalation events

Typical input:
- `escalation_query`

Typical output:
- `escalation_history`

Use when:
- auditing past escalation decisions
- checking for pending escalations that need attention
- analyzing escalation patterns across agents or time ranges

---

## 8. Trigger types

`&govern.escalation` defines four trigger types that cause an escalation event:

### `confidence_below`
The agent's confidence in the proposed action falls below the threshold configured in the governance block of its `ampersand.json` declaration.

### `cost_exceeds`
The estimated cost of the proposed action exceeds Delegatic budget limits (per-task or per-period).

### `hard_boundary`
A governance hard constraint is about to be violated. Hard boundaries are never overridable by the agent — they always require human review.

### `policy_requires_approval`
The agent's autonomy level or org-level policy mandates human sign-off for this category of action, regardless of confidence or cost.

---

## 9. Timeout behavior

When an escalation times out without a human response, behavior depends on the agent's autonomy level:

### `observe` autonomy level
Timeout action: **auto-reject**. The agent logs the escalation as expired and does not execute the proposed action. Rationale: observe-mode agents should never act autonomously.

### `advise` autonomy level
Timeout action: **auto-escalate**. The escalation is re-routed to a higher-priority channel or fallback operator. The agent does not act. Rationale: advise-mode agents should surface decisions but not resolve them unilaterally.

### `act` autonomy level
Timeout action: **auto-approve with audit**. If the agent's confidence exceeds a fallback threshold, it proceeds with execution and logs a full audit trail. If confidence is below the fallback threshold, the action is rejected. Rationale: act-mode agents are authorized to proceed under defined conditions, but every timeout-triggered action must be auditable.

---

## 10. Response decisions

Human operators can respond to an escalation with one of three decisions:

### `approve`
The proposed action is authorized. The agent resumes execution with the original input.

### `reject`
The proposed action is denied. The agent must not execute it and should log the rejection reason.

### `modify`
The proposed action is partially authorized with changes. The human provides a modified input, and the agent resumes with the modified version.

---

## 11. Architecture patterns

### Pattern A: reasoning -> escalation -> execution

```text
context
|> &reason.plan.plan()
|> &govern.escalation.escalate()
|> execute_if_approved()
```

Use this when:
- the reasoning step produces a plan that may exceed governance thresholds

### Pattern B: telemetry -> escalation -> reasoning

```text
telemetry_event
|> &govern.telemetry.budget_check()
|> &govern.escalation.escalate()
|> &reason.plan.replan()
```

Use this when:
- a budget threshold is crossed and the agent needs human input before adjusting its plan

### Pattern C: multi-agent escalation bridge

```text
agent_a_action
|> &govern.identity.verify()
|> &govern.escalation.escalate()
|> agent_b_respond()
```

Use this when:
- one agent's proposed action requires approval from another agent's governance context

### Pattern D: escalation with audit trail

```text
proposed_action
|> &govern.escalation.escalate()
|> &govern.telemetry.emit()
|> execute_or_skip()
```

Use this when:
- every escalation event, including its outcome, must be recorded in the telemetry stream

---

## 12. Example declaration

A concrete `ampersand.json` fragment:

```json
{
  "&govern.escalation": {
    "provider": "opensentience",
    "config": {
      "timeout_seconds": 3600,
      "fallback_threshold": 0.85
    }
  }
}
```

A fuller declaration:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "InfraRemediation",
  "version": "0.1.0",
  "capabilities": {
    "&reason.plan": {
      "provider": "auto",
      "need": "infrastructure remediation planning with policy-aware tradeoffs"
    },
    "&govern.escalation": {
      "provider": "opensentience",
      "config": {
        "timeout_seconds": 3600,
        "fallback_threshold": 0.85
      }
    },
    "&govern.telemetry": {
      "provider": "opensentience",
      "config": {
        "emit_all_operations": true
      }
    }
  },
  "governance": {
    "hard": [
      "Never deploy to production without human approval",
      "Never modify security groups without escalation"
    ],
    "soft": [
      "Prefer least-disruption remediation paths"
    ],
    "escalate_when": {
      "confidence_below": 0.75,
      "cost_exceeds_usd": 500,
      "hard_boundary_approached": true,
      "policy_requires_approval": ["deploy", "security_modify"]
    }
  },
  "provenance": true
}
```

---

## 13. Governance and provenance implications

Escalation events are themselves governance artifacts and must participate in the provenance chain.

### Cross-references

- **OpenSentience OS-006**: defines autonomy levels (observe, advise, act) that determine escalation behavior and timeout semantics
- **OpenSentience OS-007**: addresses threat model for agent impersonation — escalation requests must be attributable to verified agent identities via `&govern.identity`
- **Delegatic budget policies**: cost-based escalation triggers are derived from Delegatic org-level and agent-level budget limits

### Representative provenance record

```json
{
  "source": "&govern.escalation",
  "provider": "opensentience",
  "operation": "escalate",
  "timestamp": "2026-03-15T12:00:00Z",
  "escalation_id": "esc-01JQ7...",
  "trigger": "confidence_below",
  "trigger_detail": {
    "confidence": 0.62,
    "threshold": 0.75
  },
  "decision": "approve",
  "responder": "ops-lead-42",
  "mcp_trace_id": "os-esc-301"
}
```

This matters because escalation decisions can fundamentally alter the execution path.

Provenance should help answer questions like:

- Why was this action escalated instead of executed directly?
- Which trigger condition fired?
- Who approved or rejected it, and when?
- Did the action execute under timeout-based auto-approval?
- Which Delegatic budget policy caused the cost-based trigger?

---

## 14. Compatible providers

Representative compatible providers include:

- `opensentience` (primary runtime provider for escalation bridge)
- `delegatic` (policy source for cost and approval thresholds)
- custom human-review UX systems exposed behind MCP-compatible surfaces
- enterprise approval workflow engines with structured response semantics

### Default ecosystem fit

The most natural default ecosystem pairing is:

- `opensentience` for the escalation runtime
- `delegatic` for the policy definitions that trigger escalation

Why they fit together:
- OpenSentience defines autonomy levels and timeout semantics
- Delegatic defines org-level budget and approval policies
- Together they form the complete escalation governance stack

The protocol stance remains:

> `&govern.escalation` is the capability.
> `opensentience` is one provider that may satisfy it.

---

## 15. A2A-facing skills

A `&govern.escalation` capability may advertise skills such as:

- `human-escalation-bridge`
- `approval-workflow`

These are useful when generating A2A-style agent cards, because they let an external coordination surface say more than "has escalation support."

Instead, it can say the agent can:

- bridge decisions to human operators when governance thresholds are crossed
- participate in structured approval workflows with approve/reject/modify semantics

---

## 16. Anti-patterns

### Anti-pattern 1: treat escalation as error handling
Escalation is a governance mechanism, not an exception path. Agents that only escalate on errors miss the core purpose: structured human oversight of normal decisions that cross thresholds.

### Anti-pattern 2: escalate everything
If every action is escalated, the human operator becomes a bottleneck and trust in the agent degrades. Escalation thresholds should be calibrated to surface only meaningful decisions.

### Anti-pattern 3: ignore timeout semantics
Timeout behavior varies by autonomy level for good reasons. Implementing a single timeout policy across all levels defeats the purpose of differentiated autonomy.

### Anti-pattern 4: escalate without context
An escalation request without rationale, confidence scores, or trigger details forces the human to reconstruct the decision context. Always include the agent's reasoning and the specific trigger condition.

### Anti-pattern 5: skip provenance on auto-approved timeouts
When an act-mode agent auto-approves on timeout, the audit trail is especially important. Skipping provenance on these events creates governance blind spots.

---

## 17. Summary

`&govern.escalation` is the [&] Protocol capability for **governance-mandated decision handoff**.

It is the right capability when an agent needs to:

- pause before executing actions that cross confidence, cost, or policy thresholds
- present proposed actions to human operators with full context
- handle timeout behavior differently based on autonomy level
- maintain auditable records of every escalation lifecycle
- compose escalation with reasoning, telemetry, and identity capabilities

In one sentence:

> `&govern.escalation` gives an agent a protocol-native way to hand off decisions to humans when governance thresholds require it.

---
