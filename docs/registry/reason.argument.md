# `&reason.argument` — Evidence-Weighted Deliberation for the [&] Protocol

`&reason.argument` is the capability page for the `&reason.argument` subtype in the [&] Protocol.

It represents a reasoning surface built for:

- evidence-weighted evaluation
- auditable decision selection
- policy-aware deliberation
- explicit justification
- safe escalation when confidence is low

In short:

> `&reason.argument` is the protocol capability for agents that should not merely answer, but **argue from evidence and constraints**.

---

## 1. Definition

`&reason.argument` is a subtype of the `&reason` primitive.

It describes a reasoning capability that takes structured or enriched context and produces:

- a decision
- a ranked set of options
- a justification
- a governance-aware recommendation

Unlike a generic “LLM thinks here” step, `&reason.argument` is modeled as a distinct protocol capability with explicit contracts and composition rules.

---

## 2. Why this capability exists

Many agent systems need more than retrieval and tool use.

They need a way to:

- compare competing actions
- weigh evidence from multiple sources
- operate under hard and soft constraints
- explain why an action was selected
- escalate instead of acting when confidence is too low

That is the role of `&reason.argument`.

This capability is especially important for systems where decisions must be:

- reviewed
- justified
- governed
- audited
- replayed through provenance

Examples include:

- infrastructure incident response
- customer support with policy boundaries
- compliance-sensitive workflows
- research synthesis
- operations planning with explicit tradeoffs

---

## 3. Where it fits in the protocol

The [&] Protocol organizes cognition into four core domains:

- `&memory` — what the agent knows
- `&reason` — how the agent decides
- `&time` — when things happen
- `&space` — where things are

`&reason.argument` lives under `&reason` and is the subtype most directly associated with:

- deliberation
- comparison
- justification
- constrained evaluation

It composes naturally with:

- `&memory.*` for evidence retrieval
- `&time.*` for anomaly or forecast input
- `&space.*` for localized decision context

---

## 4. What makes `reason.argument` different from other reasoning subtypes

### Compared with `reason.vote`

- `reason.argument` emphasizes structured evaluation and justification
- `reason.vote` emphasizes aggregation and consensus across candidates or agents

### Compared with `reason.plan`

- `reason.argument` emphasizes selecting or defending a decision
- `reason.plan` emphasizes producing a sequence of steps

### Compared with implicit model reasoning

- `reason.argument` is explicit, typed, inspectable, and composable
- implicit reasoning is often hidden inside prompts or application code

---

## 5. Capability contract

A representative contract for `&reason.argument` looks like this:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/capability-contract.schema.json",
  "capability": "&reason.argument",
  "provider": "deliberatic",
  "version": "0.1.0",
  "description": "Argumentative reasoning contract for evidence-weighted evaluation, policy-aware deliberation, and auditable decision selection.",
  "operations": {
    "evaluate": {
      "in": "enriched_context",
      "out": "decision",
      "description": "Evaluate enriched evidence and return a decision artifact."
    },
    "deliberate": {
      "in": "candidate_set",
      "out": "ranked_options",
      "description": "Compare candidate actions or explanations and rank them by support and policy fit."
    },
    "justify": {
      "in": "decision",
      "out": "justification",
      "description": "Produce an auditable justification for a selected decision."
    },
    "learn": {
      "in": "observation",
      "out": "ack",
      "description": "Accept post-decision observations for future policy or argument refinement."
    }
  },
  "accepts_from": [
    "&memory.*",
    "&time.*",
    "&space.*",
    "context",
    "candidate_set"
  ],
  "feeds_into": [
    "&memory.*",
    "output"
  ],
  "a2a_skills": [
    "decision-evaluation",
    "evidence-based-deliberation",
    "decision-justification"
  ]
}
```

### Contract meaning

This contract says:

- `evaluate` consumes `enriched_context` and outputs `decision`
- `deliberate` consumes `candidate_set` and outputs `ranked_options`
- `justify` consumes `decision` and outputs `justification`

It also says:

- upstream inputs can come from memory, time, space, or generic context
- outputs can feed memory or final output surfaces
- this capability may advertise A2A-facing skills such as `decision-evaluation`

---

## 6. Architecture diagram

A typical `&reason.argument` pipeline looks like this:

```text
raw_data
  -> &time.anomaly.detect()
  -> &memory.graph.enrich()
  -> &space.fleet.enrich()
  -> &reason.argument.evaluate()
  -> decision
```

Or, in a support workflow:

```text
support_case
  -> &memory.vector.enrich()
  -> &memory.episodic.enrich()
  -> &reason.argument.deliberate()
  -> ranked_options
  -> &reason.argument.justify()
  -> justification
```

### Interpretation

- upstream capabilities gather and enrich evidence
- `&reason.argument` evaluates candidate actions or conclusions
- the result can be stored, surfaced, or escalated
- provenance can preserve the chain from evidence to judgment

---

## 7. Example `ampersand.json` usage

### Explicit provider binding

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "InfraOperator",
  "version": "1.0.0",
  "capabilities": {
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "constitutional",
        "mode": "evidence-first"
      }
    }
  },
  "provenance": true
}
```

### Auto provider binding

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/schema.json",
  "agent": "PolicyAnalyst",
  "version": "0.1.0",
  "capabilities": {
    "&reason.argument": {
      "provider": "auto",
      "need": "evidence-weighted policy deliberation with auditable justification"
    }
  },
  "governance": {
    "infer_from_goal": true
  },
  "provenance": true
}
```

---

## 8. Example API surface

A provider implementing `&reason.argument` might expose operations like:

### `evaluate`

Input:

```json
{
  "incident_id": "inc-2048",
  "context": {
    "anomalies": 3,
    "affected_regions": ["us-east"],
    "similar_incidents": 2
  },
  "governance": {
    "hard": ["Never scale beyond 3x in a single action"],
    "soft": ["Prefer gradual scaling over spikes"]
  }
}
```

Output:

```json
{
  "decision": "scale_up_gradually",
  "confidence": 0.91,
  "rationale": [
    "Temporal anomalies detected in CPU load",
    "Recent graph memory shows two similar incidents",
    "Regional capacity is approaching threshold"
  ]
}
```

### `justify`

Input:

```json
{
  "decision": "scale_up_gradually",
  "evidence_refs": [
    "sha256:a3f8...",
    "sha256:7b2c...",
    "sha256:e1d0..."
  ]
}
```

Output:

```json
{
  "justification": "Gradual scaling is preferred because evidence indicates real load pressure, but governance disfavors sudden spikes without stronger confidence.",
  "citations": [
    "sha256:a3f8...",
    "sha256:7b2c...",
    "sha256:e1d0..."
  ]
}
```

---

## 9. Composition patterns

### Pattern A: Time -> Memory -> Argument

Use when the system should turn operational signals into evidence-backed action.

```text
&time.anomaly -> &memory.graph -> &reason.argument
```

Good for:

- incident response
- reliability operations
- fraud review
- demand spikes

### Pattern B: Memory -> Argument

Use when the primary need is evaluating retrieved facts or prior cases.

```text
&memory.vector -> &reason.argument
```

Good for:

- customer support
- policy review
- research synthesis
- knowledge assistants

### Pattern C: Time + Space -> Argument

Use when the system must evaluate a decision in both temporal and spatial context.

```text
&time.forecast -> &space.fleet -> &reason.argument
```

Good for:

- fleet planning
- regional capacity decisions
- logistics routing constraints
- regional remediation strategy

### Pattern D: Argument -> Memory

Use when the system should preserve outcomes for later recall or postmortem analysis.

```text
&reason.argument -> &memory.graph.learn
```

Good for:

- audit logs
- incident learning
- support replay
- policy refinement

---

## 10. Governance role

`&reason.argument` is one of the strongest governance-sensitive capabilities in the protocol.

It is often the capability where:

- hard constraints are enforced
- soft preferences are weighed
- escalation decisions are triggered
- justifications are created for later review

### Example governance block

```json
{
  "governance": {
    "hard": [
      "Never reveal private customer data",
      "Never fabricate refunds or policy exceptions"
    ],
    "soft": [
      "Prefer conservative action when evidence is mixed",
      "Prefer policy-grounded responses"
    ],
    "escalate_when": {
      "confidence_below": 0.7,
      "hard_boundary_approached": true
    }
  }
}
```

### Why this matters

A reasoning provider without explicit governance tends to drift toward hidden policy logic.

A reasoning provider with governance as data can:

- operate consistently across runtimes
- surface escalation cleanly
- preserve reviewable policy context
- generate safer downstream artifacts

---

## 11. Provenance role

`&reason.argument` should be provenance-visible.

A representative provenance record for an argumentative reasoning step might look like:

```json
{
  "source": "&reason.argument",
  "provider": "deliberatic",
  "operation": "evaluate",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:7b2c...",
  "output_hash": "sha256:e1d0...",
  "parent_hash": "sha256:a3f8...",
  "mcp_trace_id": "delib-inv-1f02..."
}
```

This is important because `&reason.argument` often produces the exact artifact humans care most about:

- the decision
- the ranking
- the explanation
- the escalation

If you want to answer “Why did the agent do this?”, this is usually the most important step in the chain.

---

## 12. Compatible providers

The protocol is provider-agnostic, but representative providers for `&reason.argument` include:

- `deliberatic`
- custom enterprise policy engines
- constitutional reasoning services
- evidence-ranking and argumentation systems
- domain-specific adjudication engines

The key protocol rule is:

> a provider may satisfy `&reason.argument` if it honors the declared contract

The capability should not collapse into a single vendor identity.

---

## 13. Typical compatible upstream capabilities

`&reason.argument` often accepts input from:

- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`
- `&time.anomaly`
- `&time.forecast`
- `&space.fleet`
- `&space.route`

Typical upstream type tokens include:

- `context`
- `candidate_set`
- `enriched_context`

---

## 14. Typical downstream uses

Outputs from `&reason.argument` often feed into:

- final responses
- action execution layers
- escalation systems
- audit logs
- learning memory surfaces
- A2A skill publication
- dashboards and review workflows

Typical downstream type tokens include:

- `decision`
- `ranked_options`
- `justification`
- `output`

---

## 15. A2A skill mapping

A capability contract for `&reason.argument` may advertise skills like:

- `decision-evaluation`
- `evidence-based-deliberation`
- `decision-justification`

This makes it possible to generate an A2A-style agent card that exposes not just “reasoning,” but a more meaningful external skill surface.

Example interpretation:

- an agent with `&reason.argument` can advertise that it can evaluate actions under evidence and policy constraints
- another agent can delegate judgment-heavy tasks to it
- the published skill can still be derived from one canonical capability declaration

---

## 16. Example use cases

### Infrastructure operator

Use `&reason.argument` when deciding:

- whether to scale
- whether to escalate
- which remediation path is best justified

### Customer support agent

Use `&reason.argument` when deciding:

- whether a refund or exception is allowed
- whether policy supports a certain action
- whether to answer or escalate

### Research assistant

Use `&reason.argument` when deciding:

- which interpretation is best supported
- whether evidence is sufficient to make a claim
- how to justify a conclusion transparently

### Compliance workflow

Use `&reason.argument` when deciding:

- whether a policy boundary has been crossed
- whether action requires review
- which evidence supports the recommendation

---

## 17. Anti-patterns

### Anti-pattern 1: treating all reasoning as one opaque model call

This removes:

- type clarity
- provenance structure
- governance visibility
- contract validation

### Anti-pattern 2: using `&reason.argument` for plain planning

If the primary output is a sequence of steps, `reason.plan` is usually the better subtype.

### Anti-pattern 3: skipping upstream enrichment

`&reason.argument` is strongest when it evaluates evidence-rich context, not raw unstructured noise.

### Anti-pattern 4: allowing action without justification in governance-heavy systems

If the workflow is safety- or policy-sensitive, justification should be a first-class output.

---

## 18. Research connections

`&reason.argument` is aligned with several useful research and systems traditions:

- formal argumentation
- evidence-based deliberation
- constitutional and policy-aware AI
- explainable decision systems
- multi-criteria evaluation
- safety and escalation design for autonomous systems

The protocol does not attempt to standardize one academic theory of reasoning.

Instead, it provides a practical interface for reasoning systems that must be:

- composable
- inspectable
- governable
- publishable
- interoperable

---

## 19. Summary

`&reason.argument` is the protocol capability for **auditable, evidence-weighted decision making**.

It exists so that a system can say more than:

- “this agent reasons”

It can say:

- what kind of reasoning it performs
- what inputs it accepts
- what outputs it produces
- what it can compose with
- how it supports governance
- how it preserves provenance
- what A2A skills it can publish

That makes `&reason.argument` one of the most important reasoning surfaces in the [&] Protocol.

---

## 20. Related pages

- `capabilities/memory.graph.md`
- `capabilities/memory.episodic.md`
- `capabilities/time.forecast.md`
- `capabilities/space.fleet.md`
- `docs/capabilities/reason.md`
- `docs/architecture.md`
- `SPEC.md`
