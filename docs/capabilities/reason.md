# `&reason` — Deliberation, Evaluation, and Decision-Making

The `&reason` capability family models **how an agent decides**.

If `&memory` is about what an agent can retain and retrieve, `&reason` is about what it does with that context once a decision is required. In the [&] Protocol, reasoning is not treated as a vague "the model thinks here" step. It is a composable, inspectable capability domain with explicit subtypes, contracts, governance hooks, and downstream integration paths.

This page is the deep dive for the `&reason` primitive in the documentation hub.

---

## Why `&reason` exists as a first-class primitive

A lot of agent systems collapse reasoning into one of two extremes:

1. "the base model already reasons"
2. "a chain-of-thought prompt is enough"

That is often too weak for real systems.

Production agents usually need one or more of the following:

- argument-based evaluation
- policy-aware decision review
- multi-option comparison
- constitutional or constraint-aware deliberation
- planning over multiple steps
- voting or consensus between candidate actions
- escalation when confidence is too low
- explicit evidence tracking for audits

These are not all the same thing.

An agent that uses a deliberative argument engine behaves differently from one that uses a simple plan generator. An agent that can justify tradeoffs under governance constraints is different from one that can only rank options heuristically. The protocol models those differences explicitly through namespaced `&reason` subtypes.

---

## What `&reason` means in the protocol

`&reason` captures the part of cognition that answers questions like:

- What action should be taken?
- Which explanation is best supported by evidence?
- Which candidate response is safest under policy?
- Which plan best satisfies the goal with the current constraints?
- Should the system act, ask for clarification, or escalate?

In protocol terms, `&reason` is responsible for:

- evaluating context
- comparing alternatives
- selecting actions
- applying governance-aware decision criteria
- producing a decision artifact suitable for downstream execution or escalation

The key idea is that **reasoning is a capability interface**, not a vendor name and not a hidden runtime detail.

---

## Typical `&reason` subtypes

The subtype system keeps the top-level primitive compact while allowing specialization.

### `&reason.argument`

Use when the agent should evaluate claims, evidence, and tradeoffs explicitly.

Good fit for:

- incident response
- policy-grounded support
- compliance review
- research synthesis
- decision justification

Typical operations:

- `evaluate`
- `deliberate`
- `justify`
- `compare`

### `&reason.vote`

Use when multiple candidate actions, models, or sub-agents should be aggregated into a single choice.

Good fit for:

- ensemble decisions
- committee-style workflows
- multi-agent consensus
- ranking multiple candidate outputs

Typical operations:

- `propose`
- `vote`
- `aggregate`
- `select`

### `&reason.plan`

Use when the agent should produce or refine an action sequence rather than only picking one decision.

Good fit for:

- workflow orchestration
- task decomposition
- route or sequence planning
- tool-using agents with multi-step goals

Typical operations:

- `plan`
- `revise`
- `simulate`
- `commit`

### Other plausible future subtypes

The namespace should stay disciplined, but the model allows future additions such as:

- `&reason.reflect`
- `&reason.verify`
- `&reason.rank`
- `&reason.policy`

The rule of thumb is simple: add a subtype only if it represents a distinct interface and contract, not just a prompt style.

---

## Why reasoning should be modeled separately from memory

It is tempting to say that "memory + a strong model" already gives you reasoning. In practice, separating the two capabilities gives you better architecture.

### `&memory` answers:
- What does the agent know?
- What examples, incidents, facts, or relationships can it retrieve?

### `&reason` answers:
- Given this evidence, what should the agent conclude or do?
- How should tradeoffs be evaluated?
- Is the output safe under governance?
- Is escalation required?

This separation matters because it enables:

- provider-agnostic reasoning interfaces
- explicit pipeline validation
- audit-friendly decision stages
- governance-aware decision points
- distinct A2A skill mapping for reasoning surfaces

---

## Architecture patterns for `&reason`

### 1. Evidence-first reasoning

Pattern:

- retrieve memory
- enrich with current context
- pass enriched context into a reasoning capability
- produce a decision plus supporting explanation

Common flow:

    stream_data
      |> &time.anomaly.detect()
      |> &memory.graph.enrich()
      |> &reason.argument.evaluate()

Use this when the system should justify decisions based on retrievable evidence.

### 2. Policy-grounded support reasoning

Pattern:

- retrieve support policy and customer context
- compare candidate responses
- apply safety and escalation rules
- return a response plan or escalate

Common flow:

    support_case
      |> &memory.vector.enrich()
      |> &memory.episodic.enrich()
      |> &reason.argument.deliberate()

Use this when support quality and governance matter more than raw speed.

### 3. Multi-agent consensus reasoning

Pattern:

- generate multiple candidate actions
- collect votes or rankings
- aggregate into a final decision
- publish a consensus artifact

Common flow:

    candidate_actions
      |> &reason.vote.aggregate()

Use this when one heuristic or one model should not decide alone.

### 4. Planning-oriented reasoning

Pattern:

- infer goal state
- generate possible plans
- evaluate feasibility and constraints
- output an ordered action plan

Common flow:

    task_context
      |> &memory.graph.enrich()
      |> &space.route.enrich()
      |> &reason.plan.plan()

Use this when the output must be a sequence rather than a single judgment.

---

## Governance and `&reason`

`&reason` is where governance becomes operational.

The declaration-level governance object may include:

- `hard`
- `soft`
- `escalate_when`

Reasoning capabilities are often the place where those rules are actually interpreted or enforced in decision selection.

Examples:

- hard: "Never expose private customer data"
- soft: "Prefer conservative remediation over risky automation"
- escalate: "confidence_below = 0.7"

This makes `&reason` the natural capability domain for:

- policy application
- constitutional decision filters
- escalation thresholds
- evidence-weighted override logic

If a system has governance requirements but no explicit reasoning layer, those rules often end up scattered across prompts, middleware, and hidden business logic.

---

## Provenance implications

A `&reason` step should be one of the most visible parts of the provenance chain.

A reasoning operation typically consumes multiple upstream artifacts and emits a high-value output such as:

- `decision`
- `action_recommendation`
- `ranked_options`
- `response_plan`
- `escalation_request`

That means provenance for `&reason` often needs to preserve:

- which upstream capability outputs were used
- which provider produced the reasoning step
- which operation was used
- what governance profile was active
- hashes of the input and output artifacts
- any transport trace IDs if the provider is reached over MCP

A reasoning capability is often the step auditors ask about first:

> Why did the system choose this action?

That is why reasoning and provenance should stay tightly connected in the protocol.

---

## Contract patterns for `&reason`

A capability contract makes `&reason` machine-checkable.

A typical argument-style contract might look like this:

    {
      "capability": "&reason.argument",
      "operations": {
        "evaluate":   { "in": "enriched_context", "out": "decision" },
        "deliberate": { "in": "candidate_set",    "out": "ranked_options" },
        "justify":    { "in": "decision",         "out": "justification" }
      },
      "accepts_from": ["&memory.*", "&time.*", "&space.*", "context"],
      "feeds_into":   ["&memory.*", "output"],
      "a2a_skills":   ["decision-evaluation", "evidence-based-deliberation"]
    }

This contract does three useful things:

1. defines legal operations
2. defines type boundaries
3. defines what can precede or follow the reasoning step

That lets a conforming implementation reject pipelines that "look plausible" but do not compose correctly.

---

## Protocol shape for the `&reason` primitive

In a registry-oriented shape, the `&reason` primitive may be published like this:

    {
      "&reason": {
        "subtypes": {
          "argument": {
            "ops": ["evaluate", "deliberate", "justify", "compare"],
            "description": "Evidence-weighted argumentative reasoning."
          },
          "vote": {
            "ops": ["propose", "vote", "aggregate", "select"],
            "description": "Consensus or committee-style decision aggregation."
          },
          "plan": {
            "ops": ["plan", "revise", "simulate", "commit"],
            "description": "Goal-oriented sequencing and plan generation."
          }
        },
        "providers": [
          {
            "id": "deliberatic",
            "subtypes": ["argument", "vote"],
            "protocol": "mcp_v1"
          }
        ]
      }
    }

This is not a complete registry; it is the primitive-level shape a registry entry may take.

---

## Schema considerations for `&reason`

At the declaration level, a `&reason` capability appears in `capabilities` just like any other protocol capability:

    {
      "&reason.argument": {
        "provider": "deliberatic",
        "config": {
          "governance": "constitutional"
        }
      }
    }

At the contract level, a `&reason` capability should define:

- supported operations
- input and output types
- composition adjacency via `accepts_from`
- composition adjacency via `feeds_into`
- optional A2A skill mappings

At the registry level, `&reason` should publish:

- subtype names
- operation sets
- providers that satisfy those subtypes
- optional transport and metadata

---

## Example providers

These are examples of provider categories and ecosystem fits, not an exhaustive registry.

### `deliberatic`

Default ecosystem example for deliberation-oriented reasoning.

Likely fit for:

- `&reason.argument`
- `&reason.vote`

### Custom policy engine

A custom enterprise reasoner may satisfy:

- `&reason.argument`
- `&reason.plan`

especially where governance and auditability are more important than model creativity.

### Framework-native planner

A planner embedded in a workflow engine may satisfy:

- `&reason.plan`

if it can expose stable contracts and operations.

### Ensemble consensus service

A committee or voting service may satisfy:

- `&reason.vote`

when the system combines multiple candidate outputs before selection.

The key protocol point is not which provider is "best." It is that a provider should satisfy the declared interface and contract.

---

## Example `ampersand.json` fragment

A governance-aware reasoning binding might look like this:

    {
      "&reason.argument": {
        "provider": "deliberatic",
        "config": {
          "governance": "constitutional",
          "mode": "evidence-first"
        }
      }
    }

A planning-focused binding might look like this:

    {
      "&reason.plan": {
        "provider": "auto",
        "need": "multi-step operational planning with policy-aware revision"
      }
    }

---

## Example pipeline using `&reason`

### Infrastructure operations pipeline

    stream_data
      |> &time.anomaly.detect()
      |> &memory.graph.enrich()
      |> &space.fleet.enrich()
      |> &reason.argument.evaluate()

Interpretation:

- `&time.anomaly.detect()` finds anomalous patterns
- `&memory.graph.enrich()` adds similar incident history
- `&space.fleet.enrich()` adds regional or fleet state
- `&reason.argument.evaluate()` decides what action is justified

### Customer support pipeline

    support_case
      |> &memory.vector.enrich()
      |> &memory.episodic.enrich()
      |> &reason.argument.deliberate()

Interpretation:

- knowledge base retrieval adds policy and product context
- episodic memory adds prior interactions
- reasoning chooses the safest and most useful response path

### Planning pipeline

    task_context
      |> &memory.graph.enrich()
      |> &space.route.enrich()
      |> &reason.plan.plan()

Interpretation:

- graph memory supplies dependency context
- spatial routing supplies route constraints
- planning produces an executable sequence

---

## A2A implications

A reasoning capability may also advertise A2A-facing skills.

Examples:

- `decision-evaluation`
- `evidence-based-deliberation`
- `policy-grounded-response-selection`
- `multi-agent-consensus`
- `goal-plan-generation`

This matters because `&reason` often maps cleanly to externally advertised agent behavior.

An A2A agent card generated from a declaration containing `&reason.argument` may publish a skill that reflects its ability to evaluate evidence and justify decisions, rather than just saying the agent has "reasoning."

---

## Research grounding

The `&reason` primitive sits at the intersection of several useful research threads.

### Cognitive architectures

Research on cognitive architectures supports decomposing intelligence into functional systems rather than treating it as a monolith. `&reason` is the protocol expression of the deliberation and decision layer in that decomposition.

### Argumentation and deliberation

Formal argumentation, evidence comparison, and structured deliberation all support the idea that "reasoning" should be treated as more than one hidden model call.

### Planning systems

Planning research reinforces the need to separate decision selection from sequence generation. This is why `&reason.plan` should remain distinct from `&reason.argument`.

### Constitutional and policy-aware AI

Work on constraint-aware or constitution-guided model behavior supports the protocol's decision to connect reasoning closely with governance.

### Multi-agent consensus

Ensemble and committee-style decision systems support `&reason.vote` as a meaningful interface rather than just an implementation trick.

The protocol is not trying to encode all of these fields directly. It is taking the practical step of giving them a shared declarative surface.

---

## Design rules for adding new `&reason` subtypes

If you want to extend the namespace, use a high bar.

A new subtype should:

- represent a distinct reasoning interface
- imply a meaningful contract difference
- support stable operation names
- be useful across more than one provider
- not just duplicate an existing subtype with different branding

Good reasons to add a subtype:

- different input/output contract
- materially different decision semantics
- distinct governance or provenance requirements
- reusable external skill mapping

Bad reasons to add a subtype:

- different prompt wording
- one-off product packaging
- marketing differentiation without contract difference

---

## Practical guidance

Use `&reason.argument` when you need:

- evidence-weighted evaluation
- justifiable decisions
- governance-aware deliberation
- auditable tradeoff analysis

Use `&reason.vote` when you need:

- committee-style consensus
- ensemble aggregation
- multi-agent ranking and selection

Use `&reason.plan` when you need:

- multi-step plans
- revisable action sequences
- structured decomposition of goals into steps

---

## Summary

`&reason` is the capability family for **decision-making in the [&] Protocol**.

It exists so that reasoning can be:

- declared explicitly
- separated from memory and retrieval
- validated through contracts
- connected to governance
- preserved in provenance
- published as A2A-facing skill surfaces
- compiled into downstream runtime configuration

Without `&reason`, an agent declaration can say what information exists but not how decisions are formed.

With `&reason`, the protocol can describe not only what the agent knows, but **how it decides**.

---

## Related pages

- `docs/capabilities/memory.md`
- `docs/capabilities/time.md`
- `docs/capabilities/space.md`
- `docs/architecture.md`
- `docs/research.md`
- `SPEC.md`
