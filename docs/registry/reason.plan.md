# `&reason.plan` -- Planning-Oriented Reasoning for the [&] Protocol

`&reason.plan` is the capability page for the `&reason.plan` subtype in the [&] Protocol.

It represents a reasoning surface built for:

- goal decomposition into actionable steps
- constrained plan generation
- plan revision under feedback
- outcome simulation and failure mode analysis
- explicit commitment before execution

In short:

> `&reason.plan` is the protocol capability for agents that must **produce, refine, and commit action sequences under constraints**.

---

## 1. Definition

`&reason.plan` is a subtype of the `&reason` primitive.

It describes a reasoning capability that takes goals, constraints, and optional feedback and produces:

- a candidate plan or set of candidate plans
- a revised plan incorporating new information
- a simulation of expected outcomes and failure modes
- a committed plan ready for execution

Unlike a generic "LLM generates steps" approach, `&reason.plan` is modeled as a distinct protocol capability with explicit contracts and composition rules.

---

## 2. Why this capability exists

Many agent systems need more than evaluation and judgment.

They need a way to:

- decompose goals into ordered steps
- generate multiple candidate plans for comparison
- revise plans when constraints change or feedback arrives
- simulate outcomes before committing resources
- commit a selected plan with clear provenance

That is the role of `&reason.plan`.

This capability is especially important for systems where plans must be:

- inspectable
- revisable
- governed
- simulated before execution
- traceable from goal to action

Examples include:

- workflow orchestration across tools and services
- task decomposition for multi-step agent work
- route and sequence planning under resource constraints
- tool-using agents that must decide what to call and in what order
- capacity and demand planning with explicit tradeoffs

---

## 3. Where it fits in the protocol

The [&] Protocol organizes cognition, embodiment, and governance into six primitive families:

- `&memory` -- what the agent knows
- `&reason` -- how the agent decides
- `&time` -- when things happen
- `&space` -- where things are
- `&body` -- how the agent is instantiated in an environment (perception, action, affordance)
- `&govern` -- who is acting, under what rules, at what cost

`&reason.plan` lives under `&reason` and is the subtype most directly associated with:

- goal decomposition
- step sequencing
- plan generation and revision
- pre-execution simulation

It composes naturally with:

- `&memory.*` for context and prior plan recall
- `&time.*` for forecast and scheduling input
- `&space.*` for spatial and resource constraints
- `&reason.vote` for selecting among candidate plans
- `&reason.argument` for evaluating plan tradeoffs

---

## 4. What makes `reason.plan` different from other reasoning subtypes

### Compared with `reason.argument`

- `reason.plan` emphasizes producing and refining action sequences
- `reason.argument` emphasizes evaluating evidence and defending a decision

### Compared with `reason.vote`

- `reason.plan` generates candidate plans -- it creates the alternatives
- `reason.vote` selects among alternatives -- it aggregates preferences across candidates or agents

### Compared with implicit model reasoning

- `reason.plan` is explicit, typed, inspectable, and composable
- implicit reasoning is often hidden inside prompts or application code

---

## 5. Capability contract

A representative contract for `&reason.plan` looks like this:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&reason.plan",
  "provider": "deliberatic",
  "version": "0.1.0",
  "description": "Planning-oriented reasoning contract for goal decomposition, constrained plan revision, outcome simulation, and plan commitment.",
  "operations": {
    "plan": {
      "in": "goals_and_constraints",
      "out": "candidate_plans",
      "description": "Generate candidate plans from goals and constraints."
    },
    "revise": {
      "in": "plan_and_feedback",
      "out": "revised_plan",
      "description": "Revise an existing plan based on feedback, new constraints, or changed conditions."
    },
    "simulate": {
      "in": "candidate_plan",
      "out": "simulation_result",
      "description": "Simulate outcomes and failure modes for a candidate plan."
    },
    "commit": {
      "in": "selected_plan",
      "out": "committed_plan",
      "description": "Commit a selected plan for execution, producing an immutable execution artifact."
    }
  },
  "accepts_from": [
    "&memory.*",
    "&time.*",
    "&space.*",
    "goals",
    "constraints",
    "feedback"
  ],
  "feeds_into": [
    "&memory.*",
    "&reason.vote",
    "&reason.argument",
    "execution",
    "output"
  ],
  "a2a_skills": [
    "goal-plan-generation",
    "plan-revision"
  ]
}
```

### Contract meaning

This contract says:

- `plan` consumes `goals_and_constraints` and outputs `candidate_plans`
- `revise` consumes `plan_and_feedback` and outputs `revised_plan`
- `simulate` consumes `candidate_plan` and outputs `simulation_result`
- `commit` consumes `selected_plan` and outputs `committed_plan`

It also says:

- upstream inputs can come from memory, time, space, goals, constraints, or feedback
- outputs can feed memory, voting, argument evaluation, execution layers, or final output
- this capability may advertise A2A-facing skills such as `goal-plan-generation`

---

## 6. Architecture diagram

A typical `&reason.plan` pipeline looks like this:

```text
goal
  -> &memory.graph.enrich()
  -> &reason.plan.plan()
  -> candidate_plans
  -> &reason.plan.simulate()
  -> &reason.vote.select()
  -> &reason.plan.commit()
  -> committed_plan
```

Or, in a demand-capacity workflow:

```text
demand_signal
  -> &time.forecast.predict()
  -> &space.fleet.enrich()
  -> &reason.plan.plan()
  -> candidate_plans
  -> &reason.plan.revise()
  -> revised_plan
  -> &reason.plan.commit()
  -> committed_plan
```

### Interpretation

- upstream capabilities gather context, forecasts, and constraints
- `&reason.plan` generates, simulates, and refines candidate plans
- selection among candidates can be delegated to `&reason.vote`
- the committed plan can be stored, executed, or escalated
- provenance can preserve the chain from goal to committed action sequence

---

## 7. Example `ampersand.json` usage

### Explicit provider binding

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "WorkflowOrchestrator",
  "version": "1.0.0",
  "capabilities": {
    "&reason.plan": {
      "provider": "deliberatic",
      "config": {
        "governance": "goal-directed",
        "mode": "constrained-planning"
      }
    }
  },
  "provenance": true
}
```

### Auto provider binding

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "TaskDecomposer",
  "version": "0.1.0",
  "capabilities": {
    "&reason.plan": {
      "provider": "auto",
      "need": "goal decomposition with constrained plan revision and outcome simulation"
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

A provider implementing `&reason.plan` might expose operations like:

### `plan`

Input:

```json
{
  "goal": "deploy-v2.3-to-production",
  "constraints": {
    "hard": ["Zero downtime", "Must pass staging validation before cutover"],
    "soft": ["Prefer blue-green over rolling if capacity allows"],
    "resources": {
      "max_parallel_deploys": 3,
      "available_regions": ["us-east", "eu-west"]
    }
  },
  "context": {
    "current_version": "v2.2.1",
    "active_incidents": 0,
    "capacity_headroom": 0.35
  }
}
```

Output:

```json
{
  "candidates": [
    {
      "plan_id": "plan-bg-01",
      "strategy": "blue-green",
      "steps": [
        "provision green environment in us-east",
        "deploy v2.3 to green",
        "run staging validation suite",
        "switch traffic to green",
        "provision green environment in eu-west",
        "deploy v2.3 to green",
        "run staging validation suite",
        "switch traffic to green",
        "decommission blue environments"
      ],
      "estimated_duration_minutes": 45,
      "risk_score": 0.12
    },
    {
      "plan_id": "plan-roll-01",
      "strategy": "rolling",
      "steps": [
        "deploy v2.3 to us-east canary (10%)",
        "validate canary health for 5 minutes",
        "roll to us-east (100%)",
        "deploy v2.3 to eu-west canary (10%)",
        "validate canary health for 5 minutes",
        "roll to eu-west (100%)"
      ],
      "estimated_duration_minutes": 30,
      "risk_score": 0.18
    }
  ]
}
```

### `simulate`

Input:

```json
{
  "plan_id": "plan-bg-01",
  "failure_scenarios": ["staging_validation_fails", "capacity_spike_during_cutover"]
}
```

Output:

```json
{
  "plan_id": "plan-bg-01",
  "simulations": [
    {
      "scenario": "staging_validation_fails",
      "outcome": "rollback to blue; no traffic impact",
      "severity": "low",
      "recovery_time_minutes": 5
    },
    {
      "scenario": "capacity_spike_during_cutover",
      "outcome": "both blue and green absorb load during transition; brief latency increase",
      "severity": "medium",
      "recovery_time_minutes": 2
    }
  ],
  "overall_resilience": 0.88
}
```

---

## 9. Composition patterns

### Pattern A: Time + Space + Plan (demand-capacity planning)

Use when the system must generate plans informed by temporal forecasts and spatial resource constraints.

```text
&time.forecast -> &space.fleet -> &reason.plan
```

Good for:

- demand-capacity planning
- fleet scheduling
- regional provisioning
- supply chain sequencing

### Pattern B: Plan -> Vote (generate then select)

Use when the system should generate multiple candidate plans, then select the best one through structured comparison.

```text
&reason.plan.plan() -> &reason.vote.select()
```

Good for:

- multi-strategy evaluation
- team or stakeholder consensus on approach
- A/B deployment strategy selection
- resource allocation tradeoffs

### Pattern C: Memory -> Plan

Use when planning depends on prior context, past plans, or historical outcomes.

```text
&memory.graph -> &reason.plan
```

Good for:

- incremental workflow refinement
- learning from past execution failures
- building on prior task decompositions
- context-aware re-planning

### Pattern D: Plan -> Argument -> Plan (evaluate then revise)

Use when a generated plan should be stress-tested through evidence-weighted evaluation before revision.

```text
&reason.plan.plan() -> &reason.argument.evaluate() -> &reason.plan.revise()
```

Good for:

- safety-critical planning
- compliance-sensitive workflows
- plans with governance review gates
- iterative plan hardening

### Pattern E: Plan -> Memory

Use when committed plans should be preserved for later recall, postmortem, or learning.

```text
&reason.plan.commit() -> &memory.graph.learn
```

Good for:

- execution audit trails
- plan replay and comparison
- operational learning loops
- postmortem analysis

---

## 10. Governance role

`&reason.plan` is a governance-sensitive capability in the protocol.

It is often the capability where:

- hard constraints bound what plans may contain
- soft preferences shape plan selection
- simulation gates prevent commitment of high-risk plans
- escalation decisions are triggered when no plan satisfies all constraints

### Example governance block

```json
{
  "governance": {
    "hard": [
      "Never deploy to production without passing staging validation",
      "Never exceed resource budget in a single plan step"
    ],
    "soft": [
      "Prefer reversible actions over irreversible ones",
      "Prefer shorter plans when risk profiles are equivalent"
    ],
    "escalate_when": {
      "no_plan_satisfies_hard_constraints": true,
      "all_candidates_exceed_risk_threshold": 0.5
    }
  }
}
```

### Why this matters

A planning provider without explicit governance tends to generate plans that satisfy goals but violate unstated boundaries.

A planning provider with governance as data can:

- generate only constraint-satisfying candidates
- surface when no feasible plan exists
- preserve reviewable constraint context
- produce safer execution artifacts

---

## 11. Provenance role

`&reason.plan` should be provenance-visible.

A representative provenance record for a planning step might look like:

```json
{
  "source": "&reason.plan",
  "provider": "deliberatic",
  "operation": "commit",
  "timestamp": "2026-03-14T14:23:07Z",
  "input_hash": "sha256:7b2c...",
  "output_hash": "sha256:e1d0...",
  "parent_hash": "sha256:a3f8...",
  "mcp_trace_id": "plan-inv-1f02..."
}
```

This is important because `&reason.plan` produces artifacts that directly drive execution:

- the committed plan
- the step sequence
- the constraint satisfaction record
- the simulation results

If you want to answer "What was the agent going to do, and why did it choose that approach?", this is usually the most important step in the chain.

---

## 12. Compatible providers

The protocol is provider-agnostic, but representative providers for `&reason.plan` include:

- `deliberatic`
- custom workflow orchestration engines
- hierarchical task network planners
- constraint satisfaction planning services
- domain-specific scheduling and sequencing engines

The key protocol rule is:

> a provider may satisfy `&reason.plan` if it honors the declared contract

The capability should not collapse into a single vendor identity.

---

## 13. Typical compatible upstream capabilities

`&reason.plan` often accepts input from:

- `&memory.graph`
- `&memory.vector`
- `&memory.episodic`
- `&time.forecast`
- `&time.anomaly`
- `&space.fleet`
- `&space.route`

Typical upstream type tokens include:

- `goals`
- `constraints`
- `feedback`
- `context`

---

## 14. Typical downstream uses

Outputs from `&reason.plan` often feed into:

- execution layers
- `&reason.vote` for plan selection
- `&reason.argument` for plan evaluation
- learning memory surfaces
- audit logs
- A2A skill publication
- dashboards and review workflows

Typical downstream type tokens include:

- `candidate_plans`
- `revised_plan`
- `simulation_result`
- `committed_plan`
- `output`

---

## 15. A2A skill mapping

A capability contract for `&reason.plan` may advertise skills like:

- `goal-plan-generation`
- `plan-revision`

This makes it possible to generate an A2A-style agent card that exposes not just "planning," but a more meaningful external skill surface.

Example interpretation:

- an agent with `&reason.plan` can advertise that it can decompose goals into executable plans under constraints
- another agent can delegate planning-heavy tasks to it
- the published skill can still be derived from one canonical capability declaration

---

## 16. Example use cases

### Workflow orchestrator

Use `&reason.plan` when deciding:

- how to decompose a multi-step workflow into ordered tasks
- which tools to invoke and in what sequence
- how to revise a workflow when a step fails or conditions change

### Deployment operator

Use `&reason.plan` when deciding:

- which deployment strategy to use across regions
- how to sequence rollout steps under zero-downtime constraints
- what the rollback path looks like if validation fails

### Tool-using agent

Use `&reason.plan` when deciding:

- which APIs to call and in what order to satisfy a user goal
- how to decompose a complex request into tool invocations
- when to revise the plan based on intermediate results

### Supply chain planner

Use `&reason.plan` when deciding:

- how to sequence procurement and fulfillment steps
- which routes and schedules minimize cost under delivery constraints
- how to re-plan when a supplier or route becomes unavailable

---

## 17. Anti-patterns

### Anti-pattern 1: treating planning as a single prompt call

This removes:

- type clarity
- provenance structure
- governance visibility
- contract validation
- simulation and revision as distinct steps

### Anti-pattern 2: using `&reason.plan` for pure evaluation

If the primary output is a judgment or ranking rather than an action sequence, `reason.argument` is usually the better subtype.

### Anti-pattern 3: skipping simulation before commitment

`&reason.plan` is strongest when candidates are tested against failure modes before commitment. Committing the first candidate without simulation loses a key safety benefit.

### Anti-pattern 4: generating plans without constraint input

Plans generated without explicit constraints tend to be optimistic and fragile. Governance and resource constraints should be first-class inputs, not afterthoughts.

---

## 18. Research connections

`&reason.plan` is aligned with several useful research and systems traditions:

- hierarchical task network planning
- constraint satisfaction and optimization
- goal-oriented planning and decomposition
- simulation-based plan evaluation
- iterative plan repair and replanning
- safe planning for autonomous systems

The protocol does not attempt to standardize one academic theory of planning.

Instead, it provides a practical interface for planning systems that must be:

- composable
- inspectable
- governable
- publishable
- interoperable

---

## 19. Summary

`&reason.plan` is the protocol capability for **goal decomposition, constrained plan generation, and pre-execution simulation**.

It exists so that a system can say more than:

- "this agent plans"

It can say:

- what kind of planning it performs
- what inputs it accepts
- what outputs it produces
- what it can compose with
- how it supports governance
- how it preserves provenance
- what A2A skills it can publish

That makes `&reason.plan` one of the most important planning surfaces in the [&] Protocol.

---

## 20. Related pages

- `capabilities/memory.graph.md`
- `capabilities/memory.episodic.md`
- `capabilities/time.forecast.md`
- `capabilities/space.fleet.md`
- `docs/capabilities/reason.md`
- `docs/registry/reason.argument.md`
- `docs/architecture.md`
- `SPEC.md`
