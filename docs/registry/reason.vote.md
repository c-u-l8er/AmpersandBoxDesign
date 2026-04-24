# `&reason.vote` -- Consensus-Oriented Reasoning for the [&] Protocol

`&reason.vote` is the capability page for the `&reason.vote` subtype in the [&] Protocol.

It represents a reasoning surface built for:

- multi-agent proposal comparison
- preference and ranking signal collection
- ballot aggregation into consensus state
- final selection from aggregated results
- auditable group decision making

In short:

> `&reason.vote` is the protocol capability for agents that must **reach consensus across multiple perspectives, not merely reason alone**.

---

## 1. Definition

`&reason.vote` is a subtype of the `&reason` primitive.

It describes a reasoning capability that coordinates multiple agents or evaluation paths to produce:

- a set of candidate proposals
- a collection of preference or ranking signals
- an aggregated consensus state
- a final selection with provenance

Unlike `&reason.argument`, which models a single agent evaluating evidence, `&reason.vote` models the consensus mechanism across multiple agents or evaluation perspectives.

---

## 2. Why this capability exists

Many agent systems need more than one perspective.

They need a way to:

- generate and compare competing proposals
- collect structured preference signals from multiple agents
- aggregate those signals into a defensible consensus
- select a final outcome from the aggregated state
- preserve the full voting record for audit

That is the role of `&reason.vote`.

This capability is especially important for systems where decisions must be:

- collectively endorsed
- resistant to single-point failure of judgment
- transparent about dissent and agreement
- reproducible across different agent configurations
- governed by explicit selection rules

Examples include:

- ensemble model decisions where multiple agents evaluate the same problem
- committee-style workflows with independent reviewers
- multi-agent consensus on remediation strategy
- ranking multiple candidate outputs before surfacing a final answer
- governance decisions requiring quorum or supermajority

---

## 3. Where it fits in the protocol

The [&] Protocol organizes cognition, embodiment, and governance into six primitive families:

- `&memory` -- what the agent knows
- `&reason` -- how the agent decides
- `&time` -- when things happen
- `&space` -- where things are
- `&body` -- how the agent is instantiated in an environment (perception, action, affordance)
- `&govern` -- who is acting, under what rules, at what cost

`&reason.vote` lives under `&reason` and is the subtype most directly associated with:

- consensus
- aggregation
- candidate ranking
- collective selection

It composes naturally with:

- `&reason.argument` for upstream evidence-weighted evaluation
- `&memory.*` for evidence retrieval and learning from past votes
- `&time.*` for deadline-aware or time-bounded consensus
- `&space.*` for region-scoped voting contexts

---

## 4. What makes `reason.vote` different from other reasoning subtypes

### Compared with `reason.argument`

- `reason.argument` emphasizes evidence-weighted evaluation by a single agent
- `reason.vote` emphasizes aggregation and consensus across multiple agents or perspectives

A common composition: agents use `&reason.argument` to evaluate evidence independently, then `&reason.vote` aggregates their conclusions into a consensus.

### Compared with `reason.deliberate`

- `reason.deliberate` is kappa-aware structured deliberation over cyclic knowledge
- `reason.vote` is the consensus mechanism that can operate within or after deliberation

### Compared with `reason.plan`

- `reason.plan` emphasizes goal decomposition and step sequencing
- `reason.vote` emphasizes selection among alternatives, not sequencing

### Compared with implicit model reasoning

- `reason.vote` is explicit, typed, inspectable, and composable
- implicit reasoning hides the consensus process inside application code or prompt engineering

---

## 5. Capability contract

A representative contract for `&reason.vote` looks like this:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&reason.vote",
  "provider": "deliberatic",
  "version": "0.1.0",
  "description": "Consensus-oriented reasoning contract for multi-agent proposal comparison, preference aggregation, and auditable selection.",
  "operations": {
    "propose": {
      "in": "context",
      "out": "candidate_set",
      "description": "Generate candidate proposals from enriched context or multiple agent outputs."
    },
    "vote": {
      "in": "candidate_set",
      "out": "ballot_set",
      "description": "Collect preference or ranking signals from participating agents."
    },
    "aggregate": {
      "in": "ballot_set",
      "out": "consensus_state",
      "description": "Merge ballots into an aggregated consensus state with support scores."
    },
    "select": {
      "in": "consensus_state",
      "out": "decision",
      "description": "Produce a final decision from the aggregated consensus state."
    }
  },
  "accepts_from": [
    "&reason.argument",
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
    "multi-agent-consensus",
    "candidate-ranking"
  ]
}
```

### Contract meaning

This contract says:

- `propose` consumes `context` and outputs `candidate_set`
- `vote` consumes `candidate_set` and outputs `ballot_set`
- `aggregate` consumes `ballot_set` and outputs `consensus_state`
- `select` consumes `consensus_state` and outputs `decision`

It also says:

- upstream inputs can come from argument reasoning, memory, time, space, or generic context
- outputs can feed memory or final output surfaces
- this capability may advertise A2A-facing skills such as `multi-agent-consensus`

---

## 6. Architecture diagram

A typical `&reason.vote` pipeline looks like this:

```text
raw_data
  -> &memory.graph.enrich()
  -> &reason.argument.evaluate()  [agent_1]
  -> &reason.argument.evaluate()  [agent_2]
  -> &reason.argument.evaluate()  [agent_3]
  -> &reason.vote.propose()
  -> &reason.vote.vote()
  -> &reason.vote.aggregate()
  -> &reason.vote.select()
  -> decision
```

Or, in a simpler ensemble workflow:

```text
candidate_outputs
  -> &reason.vote.vote()
  -> &reason.vote.aggregate()
  -> &reason.vote.select()
  -> decision
```

### Interpretation

- upstream capabilities generate and enrich candidate proposals
- `&reason.vote` collects preferences, aggregates them, and selects
- the result can be stored, surfaced, or escalated
- provenance preserves the full chain from proposals through ballots to selection

---

## 7. Example `ampersand.json` usage

### Explicit provider binding

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "ConsensusPanel",
  "version": "1.0.0",
  "capabilities": {
    "&reason.vote": {
      "provider": "deliberatic",
      "config": {
        "governance": "committee-safe",
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
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "EnsembleReviewer",
  "version": "0.1.0",
  "capabilities": {
    "&reason.vote": {
      "provider": "auto",
      "need": "multi-agent consensus with ranked candidate selection"
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

A provider implementing `&reason.vote` might expose operations like:

### `propose`

Input:

```json
{
  "context": {
    "problem": "select-remediation-strategy",
    "candidates_from": ["agent-alpha", "agent-beta", "agent-gamma"],
    "enrichment": {
      "anomalies": 2,
      "affected_regions": ["eu-west"],
      "historical_success_rates": [0.85, 0.72, 0.91]
    }
  }
}
```

Output:

```json
{
  "candidate_set": [
    {"id": "proposal-1", "source": "agent-alpha", "action": "scale_horizontally"},
    {"id": "proposal-2", "source": "agent-beta", "action": "failover_to_standby"},
    {"id": "proposal-3", "source": "agent-gamma", "action": "throttle_and_monitor"}
  ]
}
```

### `vote`

Input:

```json
{
  "candidate_set": [
    {"id": "proposal-1", "action": "scale_horizontally"},
    {"id": "proposal-2", "action": "failover_to_standby"},
    {"id": "proposal-3", "action": "throttle_and_monitor"}
  ],
  "voters": ["agent-alpha", "agent-beta", "agent-gamma"]
}
```

Output:

```json
{
  "ballot_set": [
    {"voter": "agent-alpha", "ranking": ["proposal-3", "proposal-1", "proposal-2"]},
    {"voter": "agent-beta", "ranking": ["proposal-1", "proposal-3", "proposal-2"]},
    {"voter": "agent-gamma", "ranking": ["proposal-3", "proposal-1", "proposal-2"]}
  ]
}
```

### `aggregate`

Input:

```json
{
  "ballot_set": [
    {"voter": "agent-alpha", "ranking": ["proposal-3", "proposal-1", "proposal-2"]},
    {"voter": "agent-beta", "ranking": ["proposal-1", "proposal-3", "proposal-2"]},
    {"voter": "agent-gamma", "ranking": ["proposal-3", "proposal-1", "proposal-2"]}
  ]
}
```

Output:

```json
{
  "consensus_state": {
    "scores": {
      "proposal-3": 0.78,
      "proposal-1": 0.67,
      "proposal-2": 0.22
    },
    "agreement_level": 0.81,
    "dissent_flags": []
  }
}
```

### `select`

Input:

```json
{
  "consensus_state": {
    "scores": {
      "proposal-3": 0.78,
      "proposal-1": 0.67,
      "proposal-2": 0.22
    },
    "agreement_level": 0.81
  }
}
```

Output:

```json
{
  "decision": "throttle_and_monitor",
  "confidence": 0.81,
  "selected_proposal": "proposal-3",
  "rationale": [
    "Two of three voters ranked throttle_and_monitor first",
    "Agreement level exceeds governance threshold",
    "No dissent flags raised"
  ]
}
```

---

## 9. Composition patterns

### Pattern A: Argument -> Vote

Use when multiple agents should argue independently, then vote on conclusions.

```text
&reason.argument [agent_1] -> &reason.vote
&reason.argument [agent_2] ->
&reason.argument [agent_3] ->
```

Good for:

- ensemble decisions
- committee review panels
- multi-perspective evaluation
- reducing single-agent bias

### Pattern B: Memory -> Vote

Use when the primary need is selecting among retrieved candidates or historical options.

```text
&memory.vector -> &reason.vote
```

Good for:

- best-match selection from a candidate pool
- ranking historical remediation strategies
- selecting from cached policy responses

### Pattern C: Time + Space -> Argument -> Vote

Use when the system must evaluate candidates in both temporal and spatial context before reaching consensus.

```text
&time.forecast -> &space.fleet -> &reason.argument [per agent] -> &reason.vote
```

Good for:

- fleet-wide remediation consensus
- regional capacity planning with multiple stakeholders
- time-bounded group decisions under operational pressure

### Pattern D: Vote -> Memory

Use when the system should preserve consensus outcomes and ballot records for later recall.

```text
&reason.vote -> &memory.graph.learn
```

Good for:

- audit trails for group decisions
- post-decision analysis
- improving future voting calibration
- governance compliance records

### Pattern E: Deliberate -> Vote

Use when structured deliberation produces candidates that require final consensus selection.

```text
&reason.deliberate -> &reason.vote
```

Good for:

- kappa-aware deliberation followed by collective selection
- resolving cyclic reasoning through group agreement
- combining deep analysis with democratic finality

---

## 10. Governance role

`&reason.vote` is one of the most governance-sensitive capabilities in the protocol.

It is often the capability where:

- quorum requirements are enforced
- dissent is surfaced and recorded
- selection rules are made explicit
- escalation is triggered when agreement is too low

### Example governance block

```json
{
  "governance": {
    "hard": [
      "Never select a proposal that violates safety constraints",
      "Require at least three voters for any production decision"
    ],
    "soft": [
      "Prefer proposals with higher historical success rates",
      "Prefer unanimous or near-unanimous outcomes"
    ],
    "escalate_when": {
      "agreement_below": 0.5,
      "dissent_count_above": 1,
      "hard_boundary_approached": true
    }
  }
}
```

### Governance modes

`&reason.vote` supports several governance modes:

- **constitutional** -- selection is constrained by an explicit set of inviolable rules
- **committee-safe** -- voting requires quorum and records dissent for review
- **evidence-first** -- proposals must carry supporting evidence to be eligible for selection

### Why this matters

A consensus mechanism without explicit governance tends to collapse into majority-wins without accountability.

A consensus mechanism with governance as data can:

- enforce quorum and participation requirements
- surface and preserve dissenting opinions
- apply different selection rules to different risk levels
- generate auditable records of collective reasoning

---

## 11. Provenance role

`&reason.vote` should be provenance-visible.

A representative provenance record for a consensus step might look like:

```json
{
  "source": "&reason.vote",
  "provider": "deliberatic",
  "operation": "select",
  "timestamp": "2026-03-14T14:27:42Z",
  "input_hash": "sha256:4c1a...",
  "output_hash": "sha256:9f3e...",
  "parent_hashes": [
    "sha256:a3f8...",
    "sha256:7b2c...",
    "sha256:e1d0..."
  ],
  "ballot_count": 3,
  "agreement_level": 0.81,
  "mcp_trace_id": "vote-sel-2a07..."
}
```

This is important because `&reason.vote` often produces the artifact that carries collective authority:

- the selected proposal
- the agreement level
- the ballot record
- the dissent summary

If you want to answer "How did the agents agree on this?", this is the most important step in the chain.

---

## 12. Compatible providers

The protocol is provider-agnostic, but representative providers for `&reason.vote` include:

- `deliberatic`
- custom ensemble orchestration engines
- committee and quorum management services
- ranked-choice and preference aggregation systems
- domain-specific consensus engines

The key protocol rule is:

> a provider may satisfy `&reason.vote` if it honors the declared contract

The capability should not collapse into a single vendor identity.

---

## 13. Typical compatible upstream capabilities

`&reason.vote` often accepts input from:

- `&reason.argument`
- `&reason.deliberate`
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
- `ranked_options`
- `enriched_context`

---

## 14. Typical downstream uses

Outputs from `&reason.vote` often feed into:

- final responses
- action execution layers
- escalation systems
- audit logs
- learning memory surfaces
- A2A skill publication
- dashboards and review workflows
- governance compliance reports

Typical downstream type tokens include:

- `decision`
- `consensus_state`
- `ballot_set`
- `output`

---

## 15. A2A skill mapping

A capability contract for `&reason.vote` may advertise skills like:

- `multi-agent-consensus`
- `candidate-ranking`

This makes it possible to generate an A2A-style agent card that exposes not just "reasoning," but a more meaningful external skill surface.

Example interpretation:

- an agent with `&reason.vote` can advertise that it can coordinate consensus across multiple agents or perspectives
- another agent can delegate group-decision tasks to it
- the published skill can still be derived from one canonical capability declaration

---

## 16. Example use cases

### Ensemble model decisions

Use `&reason.vote` when:

- multiple models or agents evaluate the same input
- their outputs must be compared and ranked
- a single best answer must be selected with confidence

### Committee-style review

Use `&reason.vote` when:

- independent reviewers assess a proposal
- each reviewer provides a ranking or preference signal
- the system must aggregate preferences into a final recommendation

### Multi-agent remediation consensus

Use `&reason.vote` when:

- several agents propose different remediation strategies
- the system must select one strategy with collective endorsement
- dissent must be recorded for post-incident review

### Ranking multiple outputs

Use `&reason.vote` when:

- a generation step produces multiple candidate outputs
- quality signals must be collected and aggregated
- the best candidate must be surfaced with justification

---

## 17. Anti-patterns

### Anti-pattern 1: using vote for single-agent decisions

If only one agent is evaluating, `&reason.argument` is the correct subtype. `&reason.vote` adds unnecessary coordination overhead when there is no plurality of perspectives.

### Anti-pattern 2: treating consensus as simple majority without governance

Without explicit governance, voting degrades into unreviewable majority-wins. Quorum, dissent recording, and escalation thresholds should be declared.

### Anti-pattern 3: skipping the argument phase

`&reason.vote` is strongest when agents have already performed evidence-weighted evaluation. Voting on uninformed preferences produces weak consensus.

### Anti-pattern 4: collapsing vote and deliberate into one opaque step

`&reason.deliberate` and `&reason.vote` serve different roles. Deliberation explores and structures the problem space. Voting selects from the structured output. Merging them removes composability and provenance clarity.

---

## 18. Research connections

`&reason.vote` is aligned with several useful research and systems traditions:

- social choice theory
- preference aggregation and ranked-choice methods
- ensemble methods in machine learning
- multi-agent systems and collective intelligence
- Byzantine fault tolerance and quorum protocols
- deliberative democracy and committee decision theory
- judgment aggregation

The protocol does not attempt to standardize one academic theory of voting or consensus.

Instead, it provides a practical interface for consensus systems that must be:

- composable
- inspectable
- governable
- publishable
- interoperable

---

## 19. Summary

`&reason.vote` is the protocol capability for **consensus-oriented, multi-agent decision making**.

It exists so that a system can say more than:

- "these agents voted"

It can say:

- what proposals were considered
- who voted and how
- how ballots were aggregated
- what the agreement level was
- how governance constrained the selection
- how provenance preserves the full record
- what A2A skills it can publish

That makes `&reason.vote` the primary consensus surface in the [&] Protocol.

---

## 20. Related pages

- `docs/registry/reason.argument.md`
- `docs/registry/reason.deliberate.md`
- `capabilities/memory.graph.md`
- `capabilities/memory.episodic.md`
- `capabilities/time.forecast.md`
- `capabilities/space.fleet.md`
- `docs/capabilities/reason.md`
- `docs/architecture.md`
- `SPEC.md`
