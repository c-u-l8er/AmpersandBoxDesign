# Skill 09 — Governance and Provenance

> Declaring governance constraints, escalation rules, autonomy levels, and
> hash-linked provenance chains in agent declarations.

---

## Why This Matters

Capabilities without governance are unconstrained. Provenance without
governance has no enforcement. Governance without provenance has no audit
trail. Together, they make agents trustworthy and accountable.

---

## Hard Constraints

Hard constraints are **inviolable**. Implementations MUST prevent violation.
They are strings declaring absolute boundaries:

```json
"hard": [
  "Never scale beyond 3x in a single action",
  "Never authorize expenditures above $10,000",
  "Never modify production systems without approval"
]
```

### Rules for hard constraints

- They are enforced at the runtime level, not just advisory
- Violation of a hard constraint is a system failure, not a judgment call
- They apply to all capability operations regardless of pipeline
- Multiple hard constraints are conjunctive (all must hold)

---

## Soft Constraints

Soft constraints are **preferences**. They are passed to reasoning
capabilities and MAY be overridden with evidence:

```json
"soft": [
  "Prefer gradual scaling over spikes",
  "Prefer reversible actions over irreversible ones",
  "Prefer consensus when multiple options score equally"
]
```

### Rules for soft constraints

- They inform reasoning but do not block action
- A reasoning capability may override a soft constraint if it provides
  evidence justifying the override
- Overrides should be recorded in the provenance chain
- They are advisory for non-reasoning capabilities

---

## Escalation Triggers

Escalation rules define when an agent MUST defer to a human:

```json
"escalate_when": {
  "confidence_below": 0.7,
  "cost_exceeds_usd": 1000,
  "hard_boundary_approached": true
}
```

| Trigger | Semantics |
|---------|-----------|
| `confidence_below` | Escalate if reasoning confidence drops below threshold |
| `cost_exceeds_usd` | Escalate if action cost exceeds dollar amount |
| `hard_boundary_approached` | Escalate if action is near a hard constraint boundary |

Triggers are disjunctive — any single trigger firing causes escalation.

### Custom escalation triggers

The `escalate_when` object supports arbitrary key-value pairs. Providers
interpret the triggers they understand and ignore the rest:

```json
"escalate_when": {
  "confidence_below": 0.6,
  "latency_exceeds_ms": 5000,
  "affected_users_above": 1000
}
```

---

## Autonomy Levels

The `autonomy` block controls proactive behavior:

```json
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
```

### Autonomy levels

| Level | Behavior |
|-------|----------|
| `observe` | Survey and log only. Take no action. Safe default for new deployments. |
| `advise` | Propose actions, wait for approval. Typical production mode. |
| `act` | Execute within budget constraints. Full autonomy for high-trust agents. |

### Model tiers

| Tier | Target Hardware | Typical Budget |
|------|----------------|---------------|
| `local_small` | 8B parameter models | Shallow deliberation, fast attention |
| `local_large` | 70B+ parameter models | Deeper deliberation, broader attention |
| `cloud_frontier` | Cloud-hosted frontier models | Full deliberation depth |

### Governance hierarchy

Autonomy levels compose hierarchically. An organization-level policy of
`advise` will downgrade any agent declaring `act`:

```
Org policy: advise  +  Agent declaration: act  →  Effective: advise
Org policy: act     +  Agent declaration: advise  →  Effective: advise
```

The effective level is always the minimum of the org policy and the
agent declaration. This is enforced by Delegatic governance policies.

---

## Provenance Records

When `"provenance": true`, every capability operation appends a hash-linked
record to the provenance chain:

```json
{
  "source": "&time.anomaly",
  "provider": "ticktickclock",
  "operation": "detect",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:a3f8...",
  "output_hash": "sha256:7b2c...",
  "parent_hash": "sha256:0000...",
  "mcp_trace_id": "ttc-inv-9f3a..."
}
```

| Field | Description |
|-------|-------------|
| `source` | Capability that performed the operation |
| `provider` | Provider that executed it |
| `operation` | Operation name from the contract |
| `timestamp` | ISO 8601 timestamp |
| `input_hash` | SHA-256 hash of the input payload |
| `output_hash` | SHA-256 hash of the output payload |
| `parent_hash` | Hash of the previous record in the chain |
| `mcp_trace_id` | MCP invocation trace ID |

### Hash linking

Records form a chain via `parent_hash`. The first record in a pipeline
references `sha256:0000...` (genesis). Each subsequent record references
the previous record's hash. This creates an immutable, verifiable audit trail.

### Querying provenance

The provenance chain is queryable after pipeline execution. Use it for:

- **Audit**: Trace which capabilities contributed to a decision
- **Debugging**: Identify where a pipeline produced unexpected results
- **Compliance**: Prove that governance constraints were respected
- **Reproducibility**: Replay a pipeline with the same inputs

---

## Governance Composition

When capabilities compose, their governance constraints merge:

### Hard constraint merging

All hard constraints from all composed capabilities are collected into a
single conjunctive set. None may be violated.

### Soft constraint merging

Soft constraints are collected and passed to reasoning capabilities. When
soft constraints conflict, the reasoning capability decides based on
evidence. The resolution is recorded in provenance.

### Escalation trigger merging

Escalation triggers are merged disjunctively. If any trigger fires,
escalation occurs. The most conservative trigger wins.

### Autonomy level merging

The effective autonomy level is the minimum across all governance sources
(agent declaration, org policy, runtime override).

---

## Integration with Delegatic

Delegatic is the governance provider in the [&] Protocol ecosystem. It
manages:

- Organization-level autonomy caps
- Cross-agent governance policies
- Escalation routing (who gets notified)
- Approval workflows
- Policy versioning and audit

When an agent declares `&reason.argument` with `provider: "deliberatic"`,
the governance block is passed to Deliberatic for enforcement. Delegatic
policies can override agent-level governance when org-level constraints
are stricter.

---

## Common Governance Patterns

| Pattern | Description | Key Fields |
|---------|-------------|------------|
| **Read-only observer** | Agent monitors but never acts | `level: "observe"`, no soft/hard needed |
| **Advisor with guardrails** | Agent proposes within bounds | `level: "advise"`, hard constraints, escalation |
| **Autonomous with budget** | Agent acts within strict limits | `level: "act"`, budget caps, hard constraints |
| **Compliance-first** | Full audit trail, conservative escalation | `provenance: true`, low confidence threshold |
| **Multi-domain corroboration** | Requires evidence from multiple capabilities | Hard constraint requiring multi-domain evidence |
