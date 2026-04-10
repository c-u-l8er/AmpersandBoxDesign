# Dual- and Triple-Loop Machine Architecture

> **PULSE update (OS-010, 2026-04):** With the introduction of OS-010 PULSE,
> the loop-interlock pattern documented here is now formalized as a manifest
> standard. Graphonomous, PRISM, AgenTroMatic, and every other portfolio loop
> declare their phases in `<loop>.pulse.json` files (see `/PULSE/manifests/`),
> validated against `pulse-loop-manifest.v0.1.json`. The "dual loop" is a
> special case of arbitrarily nestable PULSE loops — the same machine grouping
> works at any depth, and PRISM's `interact` phase reads the inner system's
> PULSE manifest to discover the `retrieve` boundary at runtime rather than
> hard-coding the integration. See "Triple loop and beyond" below.

## The Problem

Graphonomous exposes 29 MCP tools. PRISM specifies 47. When both run in the same
session (the benchmarking use case), the client sees 76 tools. Research shows:

- Tool selection accuracy degrades past ~30 tools (Opus 4: 49% correct at that scale)
- Each tool definition consumes 500–2,000 tokens of context before conversation starts
- 76 tools can burn 40–80K tokens just on schema overhead

## The Insight: Machine Around the Loop, Not the Category

Instead of grouping tools by what they *touch* (graph write, graph read, belief, etc.),
group them by **which phase of the closed loop the agent is in** when it calls them.

Both Graphonomous and PRISM are closed-loop systems. Their loops are structurally
parallel and interlock when PRISM evaluates Graphonomous:

```
Graphonomous (memory loop)          PRISM (evaluation loop)
──────────────────────────          ───────────────────────
retrieve  "What do I know?"         compose    "What should I test?"
route     "What should I do?"       interact   "Run the test"
act       "Do it"                   observe    "Judge the result"
learn     "Did it work?"            reflect    "What should change?"
consolidate "Clean up"              diagnose   "What's actionable?"
```

## Graphonomous: 29 tools → 5 machines

### `retrieve` — "What do I know?"

The agent calls this when it needs context before reasoning or acting.

| Action | Replaces | Description |
|--------|----------|-------------|
| `context` | `retrieve_context` | κ-aware ranked retrieval with topology annotations |
| `episodic` | `retrieve_episodic` | Time-range filtered episodic nodes |
| `procedural` | `retrieve_procedural` | Semantic search scoped to procedural nodes |
| `coverage` | `coverage_query` | Standalone epistemic coverage (act/learn/escalate) |
| `trace_evidence` | `trace_evidence_path` | Weighted Dijkstra evidence path between nodes |
| `frontier` | `epistemic_frontier` | Wilson interval uncertainty analysis |

### `route` — "What should I do?"

The agent calls this to decide whether to act, learn, deliberate, or escalate.

| Action | Replaces | Description |
|--------|----------|-------------|
| `topology` | `topology_analyze` | SCC/κ analysis with routing recommendation |
| `deliberate` | `deliberate` | κ-driven deliberation over cyclic regions |
| `attention_survey` | `attention_survey` | Priority survey across active goals |
| `attention_cycle` | `attention_run_cycle` | Full triage → dispatch attention cycle |
| `review_goal` | `review_goal` | Coverage-driven act/learn/escalate gate |

### `act` — "Do it"

The agent calls this to mutate the knowledge graph.

| Action | Replaces | Description |
|--------|----------|-------------|
| `store_node` | `store_node` | Store a knowledge node |
| `store_edge` | `store_edge` | Store a relationship edge |
| `delete_node` | `delete_node` | Remove a node |
| `manage_edge` | `manage_edge` | CRUD on edges |
| `manage_goal` | `manage_goal` | Goal CRUD + lifecycle transitions |
| `belief_revise` | `belief_revise` | Expand/contract/replace beliefs |
| `forget_node` | `forget_node` | Soft-hide from retrieval |
| `forget_policy` | `forget_by_policy` | Budget-aware priority pruning |
| `gdpr_erase` | `gdpr_erase` | Hard delete with audit trail |

### `learn` — "Did it work?"

The agent calls this after acting, to close the feedback loop.

| Action | Replaces | Description |
|--------|----------|-------------|
| `from_outcome` | `learn_from_outcome` | Causal confidence updates from action results |
| `from_feedback` | `learn_from_feedback` | Positive/negative/correction feedback |
| `detect_novelty` | `learn_detect_novelty` | Similarity-based novelty scoring |
| `from_interaction` | `learn_from_interaction` | Full pipeline: novelty → store → extract → link |
| `contradictions` | `belief_contradictions` | Detect belief conflicts in the graph |

### `consolidate` — "Clean up"

The agent calls this to maintain graph quality, typically at session boundaries.

| Action | Replaces | Description |
|--------|----------|-------------|
| `run` | `run_consolidation` | Trigger a consolidation cycle |
| `stats` | `graph_stats` | Aggregate counts, distributions, confidence |
| `query` | `query_graph` | Operation-based graph inspection |
| `traverse` | `graph_traverse` | BFS walk with depth/relationship filters |

**Total: 5 tools exposed to the model.**

---

## PRISM: 47 tools → 5 machines + 1 admin

### `compose` — "What should I test?"

| Action | Replaces | Description |
|--------|----------|-------------|
| `scenarios` | `compose_scenarios` | Build scenarios from repo anchors + CL specs |
| `validate` | `validate_scenarios` | CL coverage validation on draft scenarios |
| `list` | `list_scenarios` | List with filters (kind, domain, dimension, difficulty) |
| `get` | `get_scenario` | Full scenario details + IRT params |
| `retire` | `retire_scenario` | Retire a scenario with reason |
| `import` | `import_external` | Import from BEAM/LongMemEval with CL tagging |
| `byor_register` | `byor_register_repo` | Register a personal repo |
| `byor_discover` | `byor_discover_events` | Auto-discover CL events in commit history |
| `byor_generate` | `byor_generate_scenarios` | Generate scenarios from discovered events |

### `interact` — "Run the test"

| Action | Replaces | Description |
|--------|----------|-------------|
| `run` | `run_interaction` | One scenario × one system |
| `run_sequence` | `run_sequence` | Scenario sequence, no memory reset |
| `run_matrix` | `run_matrix` | N systems × M models × all scenarios |
| `status` | `get_run_status` | Check in-progress run |
| `transcript` | `get_transcript` | Full interaction transcript |
| `cancel` | `cancel_run` | Cancel in-progress run |
| `byor_evaluate` | `byor_evaluate` | Full BYOR evaluation |
| `byor_compare` | `byor_compare` | Head-to-head on your repo |

### `observe` — "Judge the result"

| Action | Replaces | Description |
|--------|----------|-------------|
| `judge_transcript` | `judge_transcript` | L2: all 9 dimensions for one transcript |
| `judge_dimension` | `judge_dimension` | L2: one specific dimension (debug) |
| `meta_judge` | `meta_judge` | L3: meta-judge one L2 judgment |
| `meta_judge_batch` | `meta_judge_batch` | L3: meta-judge all L2 judgments for a run |
| `override` | `override_judgment` | Human override with audit trail |

### `reflect` — "What should change?"

| Action | Replaces | Description |
|--------|----------|-------------|
| `analyze_gaps` | `analyze_gaps` | Under-tested dims, saturated scenarios, domain gaps |
| `evolve` | `evolve_scenarios` | Retire, extend, fork, promote |
| `advance_cycle` | `advance_cycle` | Run all 4 phases (Compose → Interact → Observe → Reflect) |
| `calibrate_irt` | `calibrate_irt` | Recalibrate IRT difficulty/discrimination |
| `cycle_history` | `get_cycle_history` | Full history of cycles and improvements |
| `byor_recommend` | `byor_recommend` | System recommendation for your use case |
| `byor_infer_profile` | `byor_infer_profile` | Infer task profile from repo patterns |

### `diagnose` — "What's actionable?"

| Action | Replaces | Description |
|--------|----------|-------------|
| `report` | `get_diagnostic_report` | Full diagnostic (failures, fixes, regressions) |
| `failure_patterns` | `get_failure_patterns` | Clustered failure analysis per dimension |
| `retest` | `run_retest` | Re-run specific scenarios after a fix |
| `verify` | `get_verification_report` | Before/after comparison from retest |
| `regressions` | `get_regression_alerts` | Cross-cycle regression analysis |
| `suggest_fixes` | `suggest_fixes` | AI-generated fix suggestions |
| `leaderboard` | `get_leaderboard` | Rankings with domain filter |
| `leaderboard_history` | `get_leaderboard_history` | Scores over time |
| `compare_systems` | `compare_systems` | Head-to-head across all 9 dimensions |
| `dimension_leaders` | `get_dimension_leaders` | Top system per CL dimension |
| `fit_recommendation` | `get_fit_recommendation` | System rec for a task profile |
| `compare_fit` | `compare_fit` | Compare two systems for a specific task |
| `task_profiles` | `list_task_profiles` | List pre-built and custom profiles |

### `config` — Admin/setup (outside the loop)

| Action | Replaces | Description |
|--------|----------|-------------|
| `set_weights` | `set_cl_weights` | Update 9-dimension weight vector |
| `register_system` | `register_system` | Register memory system + MCP endpoint |
| `list_systems` | `list_systems` | List registered systems |
| `get_config` | `get_config` | Current full configuration |
| `create_profile` | `create_task_profile` | Define custom task profile |

**Total: 6 tools exposed to the model (5 loop + 1 admin).**

---

## Combined Impact

| Scenario | Before | After |
|----------|--------|-------|
| Graphonomous alone | 29 tools | 5 tools |
| PRISM alone | 47 tools | 6 tools |
| Both in same session | 76 tools | 11 tools |

Context savings: ~80% reduction in tool schema tokens.
Selection accuracy: from ~49% (76 tools) to ~95% (11 tools).

## The Interlocking Loops

When PRISM benchmarks Graphonomous, the loops nest:

```
PRISM compose ──→ PRISM interact ──→ PRISM observe ──→ PRISM reflect ──→ PRISM diagnose
                       │
                       ▼
              ┌─── Graphonomous ───┐
              │  retrieve → route  │
              │  → act → learn     │
              │  → consolidate     │
              └────────────────────┘
```

PRISM's `interact` phase drives the system-under-test through its own closed loop.
PRISM's `observe` phase judges how well that inner loop performed.
PRISM's `reflect` phase evolves scenarios based on where the inner loop failed.

This is the knockout feature: **two self-improving loops, one inside the other.**
The outer loop (PRISM) improves the benchmark. The inner loop (Graphonomous)
improves the memory. Each makes the other sharper.

## Implementation Pattern

Both systems use the same Elixir pattern: a single MCP component module per
machine with an `action` field that dispatches internally.

```elixir
defmodule Graphonomous.MCP.Retrieve do
  use Anubis.Server.Component, type: :tool

  schema do
    field(:action, :string,
      required: true,
      description: "context | episodic | procedural | coverage | trace_evidence | frontier"
    )
    # Union of all action-specific fields, each documented with which action uses it
    field(:query, :string, description: "Search query (context, episodic, procedural, frontier)")
    field(:limit, :number, description: "Max results (context, episodic, procedural)")
    # ... etc
  end

  def execute(%{action: "context"} = params, frame), do: do_context(params, frame)
  def execute(%{action: "episodic"} = params, frame), do: do_episodic(params, frame)
  # ...
end
```

Each machine module delegates to the existing `Graphonomous.*` functions — the
internal API doesn't change, only the MCP surface.

## Migration Strategy

1. **Phase 1: Add machine modules alongside existing tools.** Both surfaces work.
   Register machines in `server.ex` with a `v2_` prefix for testing.
2. **Phase 2: Update skill prompts** to reference machine verbs instead of
   individual tools. Run PRISM benchmarks comparing v1 vs v2 tool selection accuracy.
3. **Phase 3: Deprecate individual tools.** Remove from `server.ex`, keep modules
   for reference.
4. **Phase 4: Remove deprecated modules.** Clean cut.

## Backward Compatibility

Existing clients calling `retrieve_context` directly will break at Phase 3.
Mitigation: the adapter layer in `Prism.MCP.Adapter` can translate legacy tool
names to machine + action pairs during the transition.

---

## Triple loop and beyond — PULSE generalization

The Graphonomous ↔ PRISM dual loop is the canonical example, but the [&]
ecosystem actually runs **at least three** nested loops today:

```
PRISM (outer)        compose → interact → observe → reflect → diagnose
  │
  └─ Graphonomous    retrieve → route → act → learn → consolidate
       │
       └─ Deliberation    survey → triage → dispatch → act → learn
```

OS-010 PULSE encodes this nesting in each manifest's `nesting` block:

- `prism.benchmark` declares `inner_loops: [graphonomous.continual_learning]`
- `graphonomous.continual_learning` declares `inner_loops: [graphonomous.deliberate]` and `parent_loop: prism.benchmark`
- `graphonomous.deliberate` declares `parent_loop: graphonomous.continual_learning`

PULSE supports unbounded nesting depth. OS-008 (Agent Harness, draft) is
expected to add a fourth outer layer that wraps PRISM itself — when it
ships, the only change required is a new manifest with
`inner_loops: [prism.benchmark]`. No code changes to existing machines.

### Why this matters for the machine architecture

The 5/6/11-tool count documented above is a **floor**, not a ceiling.
Adding a third loop adds at most 5 more machines (one per phase kind), and
because PULSE manifests declare the inner-loop boundary explicitly, the
outer machines do not need to learn about inner machines individually.
PRISM's `interact` machine, for example, drives any PULSE-conforming
inner loop through its declared `retrieve` phase — it does not need a
Graphonomous-specific code path.

| Layers in session | Tool count (machines) | Tool count (legacy v1) |
|---|---|---|
| Graphonomous alone | 5 | 29 |
| Graphonomous + PRISM | 11 | 76 |
| Graphonomous + PRISM + OS-008 Harness | ~16 | ~100+ |
| Graphonomous + PRISM + OS-008 + AgenTroMatic deliberation | ~21 | ~130+ |

The savings compound with depth, and PULSE's manifest standard is what
makes the composition algebraic instead of ad-hoc.

### Three-protocol stack at runtime

```
┌──────────────────────────────────────────────────────────┐
│  PRISM    — measures loops over time      (diagnostic)   │ OS-009
├──────────────────────────────────────────────────────────┤
│  PULSE    — declares loops + circulation   (temporal)    │ OS-010
├──────────────────────────────────────────────────────────┤
│  [&]      — composes capabilities          (structural)  │ AmpersandBoxDesign
└──────────────────────────────────────────────────────────┘
```

A loop is **PULSE-conforming** if its manifest validates against
`pulse-loop-manifest.v0.1.json` and its runtime passes all 12 conformance
tests. A system is **PRISM-evaluable** automatically once it is
PULSE-conforming — PRISM's `compose` phase reads the manifest, injects
scenarios at the declared `retrieve` boundary, and observes outcomes via
the declared `learn` phase. No bespoke per-system integration required.

See `/PULSE/manifests/` for the canonical reference manifests and
`opensentience.org/docs/spec/OS-010-PULSE-SPECIFICATION.md` for the full
PULSE protocol spec.
