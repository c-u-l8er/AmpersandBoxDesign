# Model Tier Adaptation — Build Prompt v1

> **Purpose:** Defines how the κ-driven architecture (Deliberator, Attention Engine, crystallization) adapts across hardware and model tiers. The same graph topology drives all tiers — what changes is the *depth* of reasoning at each routing decision, not the routing itself.
>
> **Depends on:** KAPPA_BUILD_PROMPT.md, KAPPA_DELIBERATOR_PROMPT.md, ATTENTION_ENGINE_PROMPT.md
>
> **Target agent:** ChatGPT-5.3-Codex (or any coding agent with file access)
>
> **Author:** Travis / [&] Ampersand Box Design
>
> **Date:** 2026-03-22
>
> **Version:** 1.0

---

## 0. The One-Sentence Idea

**κ routing becomes *more* valuable on constrained hardware — it tells the system when to skip expensive inference entirely. The model tier determines *how much* reasoning happens when κ > 0, not *whether* to reason.**

---

## 1. Why This Exists

The KAPPA_DELIBERATOR_PROMPT assumes multi-pass LLM reasoning: decompose → focused passes per partition → reconciliation. This is correct for frontier models with large context windows and strong instruction-following. On smaller models (8B parameters, 4K-8K effective context), this architecture breaks in predictable ways:

| Assumption | Frontier Model | 8B Local Model | Failure Mode |
|-----------|---------------|----------------|--------------|
| Multi-pass reasoning across partitions | Works — model tracks assumptions across passes | Fails — model loses context of the "held fixed" assumption | Incoherent reconciliation |
| Context window holds partition + boundary nodes | 32K+ tokens available | 4K-8K effective (quality degrades above) | Partition context exceeds usable window |
| Reconciliation synthesizes contradictions | Model can weigh evidence and identify wrong assumptions | Model picks one side arbitrarily or hallucinates | Wrong crystallized conclusions compound over time |
| Heartbeat every 5 minutes with agent calls | Cloud API latency ~1s, cost ~$0.01/call | Local inference ~10-30s/call, machine pegged while generating | System unusable during attention cycles |
| Autonomous goal generation (PROPOSE mode) | Frontier models generate sensible goals | Smaller models hallucinate goals or drift | Noise in GoalGraph, wasted compute on meaningless goals |

**The fix is not to disable these features on small models. The fix is to make them *tier-aware* — the same architectural pipeline with different depth settings.**

---

## 2. Model Tiers

### 2.1 Tier Definition

Three tiers, configured at startup. The tier determines default budgets for deliberation and attention. Tiers are about *effective reasoning capability*, not parameter count — a well-tuned 13B may outperform a generic 70B.

```elixir
@type model_tier :: :local_small | :local_large | :cloud_frontier

# Configured in config/config.exs or runtime:
config :graphonomous, :model_tier, :local_small

# Or detected at startup based on available model:
config :graphonomous, :model_tier, :auto
```

### 2.2 Tier Profiles

```elixir
defmodule Graphonomous.ModelTier do
  @moduledoc """
  Hardware-adaptive profiles for deliberation and attention.
  The κ computation is tier-independent (pure graph algorithm).
  The LLM-dependent operations adapt to what the model can handle.
  """

  @profiles %{
    local_small: %{
      label: "Local 8B (e.g., Llama 3.1 8B, Qwen 2.5 7B, Gemma 2 9B)",
      effective_context_tokens: 4096,
      max_nodes_per_prompt: 8,
      avg_inference_ms: 15_000,

      deliberation: %{
        strategy: :single_pass,
        max_agent_calls_per_scc: 1,
        max_iterations: 1,
        confidence_threshold: 0.6,
        timeout_multiplier: 3.0,
        kappa_deliberation_floor: 2
      },

      attention: %{
        trigger_mode: :demand,
        heartbeat_ms: :disabled,
        max_items_per_cycle: 1,
        max_explore_calls: 2,
        max_deliberation_sccs: 1,
        max_action_dispatches: 1,
        total_timeout_ms: 120_000,
        propose_enabled: false,
        default_autonomy: :observe
      },

      embedding: %{
        model: "all-MiniLM-L6-v2",
        dimensions: 384,
        device: :cpu,
        retrieval_limit: 10
      },

      crystallization: %{
        aggressive: true,
        cache_retrievals: true
      }
    },

    local_large: %{
      label: "Local 70B+ (e.g., Llama 3.1 70B, Qwen 2.5 72B, DeepSeek-V3)",
      effective_context_tokens: 16_384,
      max_nodes_per_prompt: 20,
      avg_inference_ms: 5_000,

      deliberation: %{
        strategy: :multi_pass,
        max_agent_calls_per_scc: 3,
        max_iterations: 3,
        confidence_threshold: 0.7,
        timeout_multiplier: 2.0,
        kappa_deliberation_floor: 1
      },

      attention: %{
        trigger_mode: :heartbeat,
        heartbeat_ms: 600_000,
        max_items_per_cycle: 2,
        max_explore_calls: 5,
        max_deliberation_sccs: 1,
        max_action_dispatches: 1,
        total_timeout_ms: 90_000,
        propose_enabled: false,
        default_autonomy: :advise
      },

      embedding: %{
        model: "nomic-embed-text",
        dimensions: 768,
        device: :gpu,
        retrieval_limit: 20
      },

      crystallization: %{
        aggressive: true,
        cache_retrievals: true
      }
    },

    cloud_frontier: %{
      label: "Cloud API (e.g., Claude 4/Opus, GPT-5, Gemini Ultra)",
      effective_context_tokens: 128_000,
      max_nodes_per_prompt: 50,
      avg_inference_ms: 1_500,

      deliberation: %{
        strategy: :multi_pass,
        max_agent_calls_per_scc: :budget,
        max_iterations: 5,
        confidence_threshold: 0.75,
        timeout_multiplier: 1.0,
        kappa_deliberation_floor: 1
      },

      attention: %{
        trigger_mode: :heartbeat,
        heartbeat_ms: 300_000,
        max_items_per_cycle: 3,
        max_explore_calls: 10,
        max_deliberation_sccs: 2,
        max_action_dispatches: 1,
        total_timeout_ms: 60_000,
        propose_enabled: true,
        default_autonomy: :advise
      },

      embedding: %{
        model: :provider_default,
        dimensions: :provider_default,
        device: :api,
        retrieval_limit: 50
      },

      crystallization: %{
        aggressive: false,
        cache_retrievals: false
      }
    }
  }

  @doc "Get the full profile for a tier"
  @spec profile(model_tier()) :: map()
  def profile(tier), do: Map.fetch!(@profiles, tier)

  @doc "Get the deliberation config for a tier"
  @spec deliberation_config(model_tier()) :: map()
  def deliberation_config(tier), do: profile(tier).deliberation

  @doc "Get the attention config for a tier"
  @spec attention_config(model_tier()) :: map()
  def attention_config(tier), do: profile(tier).attention
end
```

### 2.3 Key Design Decisions

**`kappa_deliberation_floor`** — The minimum κ value that triggers LLM-based deliberation.

- On `local_small`: floor is **2**. For κ=1 (single feedback loop), the model gets a structured single-pass prompt that *acknowledges* the circularity but doesn't attempt partition-and-reconcile. The fault-line is mentioned in context ("Note: these concepts form a feedback loop; the weakest link is X→Y"), giving the model a chance to reason about it without the overhead of multi-pass prompting. Only κ≥2 (genuinely tangled) triggers the full Deliberator.
- On `local_large` and `cloud_frontier`: floor is **1**. Any circularity gets deliberation.

This means κ routing has *three* outcomes on constrained hardware:

```
κ = 0 → fast retrieval (no LLM reasoning pass, just return context)
κ = 1 → enriched retrieval (single prompt with topology annotation)
κ ≥ 2 → deliberation (full Deliberator pipeline, adapted to tier)
```

**`strategy: :single_pass`** — Replaces the decompose→focus→reconcile pipeline with a single structured prompt:

```
CONTEXT (scoped to SCC nodes, max 8 nodes):
  [node contents + edge relationships]

TOPOLOGY NOTE:
  These concepts form a feedback loop (κ=N).
  The weakest link in this loop is: [fault_line_source] → [fault_line_target].
  This means [fault_line_source] depends on [fault_line_target] with the
  least evidential support.

QUERY:
  [original query]

INSTRUCTION:
  Consider the circular dependency described above. The weakest point
  is [fault line]. Given this structure, what conclusion can you draw?
  State your confidence (0.0-1.0).
```

This preserves the core insight (fault lines as reasoning anchors) without requiring the model to track assumptions across multiple calls.

**`trigger_mode: :demand`** — The Attention Engine fires on user action (query, BendScript interaction, goal creation) instead of a timer. The survey/triage/dispatch pipeline is identical — only the trigger changes.

```elixir
# In Retriever, after topology analysis (demand-triggered attention):
if tier_config.attention.trigger_mode == :demand and result.topology.max_kappa > 0 do
  # Piggyback a lightweight attention check on this query
  Attention.on_demand_check(result.topology, query)
end

# In Attention GenServer:
def on_demand_check(topology, query) do
  # Only survey goals related to this query's knowledge region
  # Much cheaper than a full survey
  partial_survey(topology.sccs, query)
end
```

**`propose_enabled: false`** — Goal generation is disabled on small models. The risk of hallucinated goals outweighs the value. Goals must come from the user (`:user`) or from explicit system rules (`:system`). Enable only after validating that the model produces sensible goals on your specific domain.

**`crystallization.aggressive: true`** — On constrained hardware, every LLM call is expensive. Crystallized conclusion nodes are *critical performance optimizations*:
- A crystallized conclusion means you never re-deliberate that SCC region for similar queries
- The graph "learns" faster because conclusions are aggressively written back
- Combined with `cache_retrievals: true`, the system memoizes the full retrieve→deliberate→conclude pipeline

**`crystallization.aggressive: false`** on cloud — When inference is cheap, it can be better to re-derive conclusions from fresh context than to rely on potentially stale crystallized nodes. The Consolidator's decay/prune cycle handles staleness, but with aggressive crystallization disabled, the system stays more dynamic.

---

## 3. Integration with Existing Modules

### 3.1 Deliberator Adaptation

The Deliberator (KAPPA_DELIBERATOR_PROMPT.md) already accepts `agent_fn` and `budget` as options. Tier adaptation plugs into these:

```elixir
# In Graphonomous.Deliberator.deliberate/4:
def deliberate(topology, query, retrieval_results, opts \\ []) do
  tier = Application.get_env(:graphonomous, :model_tier, :local_small)
  tier_config = ModelTier.deliberation_config(tier)

  # Merge tier defaults with explicit opts (explicit wins)
  budget = Map.merge(tier_config, Keyword.get(opts, :budget, %{}))

  # Check deliberation floor
  sccs_to_deliberate =
    topology.sccs
    |> Enum.filter(fn scc -> scc.kappa >= tier_config.kappa_deliberation_floor end)

  case tier_config.strategy do
    :single_pass ->
      deliberate_single_pass(sccs_to_deliberate, query, retrieval_results, budget, opts)

    :multi_pass ->
      deliberate_multi_pass(sccs_to_deliberate, query, retrieval_results, budget, opts)
  end
end

defp deliberate_single_pass(sccs, query, retrieval_results, budget, opts) do
  agent_fn = Keyword.fetch!(opts, :agent_fn)

  Enum.map(sccs, fn scc ->
    prompt = build_single_pass_prompt(query, scc, retrieval_results)
    {:ok, response} = agent_fn.(prompt)
    conclusion = parse_single_pass_conclusion(response, scc)

    if Keyword.get(opts, :write_back, true) do
      {:ok, _node_id} = crystallize(conclusion, scc, opts)
    end

    {:ok, conclusion}
  end)
end
```

### 3.2 Attention Engine Adaptation

The Attention Engine (ATTENTION_ENGINE_PROMPT.md) reads tier config at startup:

```elixir
# In Graphonomous.Attention.init/1:
def init(opts) do
  tier = Application.get_env(:graphonomous, :model_tier, :local_small)
  tier_config = ModelTier.attention_config(tier)

  # Merge with explicit config (explicit wins)
  config = Map.merge(tier_config, Map.new(opts))

  state = %{
    config: config,
    active: config.trigger_mode == :heartbeat,
    autonomy_level: config.default_autonomy,
    # ...
  }

  # Only start heartbeat timer if tier supports it
  if state.active and config.heartbeat_ms != :disabled do
    Process.send_after(self(), :heartbeat, config.heartbeat_ms)
  end

  {:ok, state}
end
```

### 3.3 Retriever Adaptation — Enriched Retrieval for κ=1

For `local_small` tier where `kappa_deliberation_floor` is 2, κ=1 regions get *enriched retrieval* instead of full deliberation. This is a lightweight annotation pass:

```elixir
# In Graphonomous.Retriever, after topology analysis:
defp maybe_enrich_or_deliberate(result, query, opts) do
  tier = Application.get_env(:graphonomous, :model_tier, :local_small)
  tier_config = ModelTier.deliberation_config(tier)

  cond do
    result.topology.max_kappa == 0 ->
      # DAG — fast path, no enrichment needed
      result

    result.topology.max_kappa < tier_config.kappa_deliberation_floor ->
      # Below deliberation floor — enrich context with topology annotations
      # This is FREE (no LLM calls, just context decoration)
      enrich_with_topology_notes(result)

    opts[:auto_deliberate] ->
      # Above floor — full deliberation
      case Deliberator.deliberate(result.topology, query, result.results, opts) do
        {:ok, deliberation_result} ->
          Map.put(result, :deliberation, deliberation_result)
        _ ->
          result
      end

    true ->
      # Above floor but auto_deliberate off — let caller decide
      result
  end
end

defp enrich_with_topology_notes(result) do
  # Annotate the retrieval result with human-readable topology context
  # The calling LLM gets this as structured context, not a separate prompt
  topology_notes =
    result.topology.sccs
    |> Enum.map(fn scc ->
      fault_lines =
        scc.fault_line_edges
        |> Enum.map(fn {s, t} -> "#{s} → #{t}" end)
        |> Enum.join(", ")

      %{
        scc_id: scc.id,
        kappa: scc.kappa,
        node_ids: scc.nodes,
        note: "These #{length(scc.nodes)} concepts form a feedback loop (κ=#{scc.kappa}). " <>
              "Weakest link: #{fault_lines}. Consider this circularity when reasoning."
      }
    end)

  Map.put(result, :topology_notes, topology_notes)
end
```

This three-tier routing is the key insight: **κ is a routing signal, and the routes themselves adapt to hardware.**

---

## 4. The Consolidator Is More Important on Constrained Hardware

On `local_small`, graph size directly impacts performance:

- More nodes → more embedding comparisons (CPU-bound on 384-dim vectors)
- More edges → more SCC computation (Tarjan is O(V+E) but constant factors matter)
- Larger SCCs → more context needed per deliberation (hits the 4K token wall faster)

The Consolidator's pruning and merging are therefore **performance-critical**, not just knowledge-hygiene:

```elixir
# Tier-aware consolidation thresholds
defp consolidation_config(:local_small) do
  %{
    # Prune more aggressively to keep graph lean
    min_confidence_for_retention: 0.3,     # default 0.2
    idle_decay_rate: 0.15,                 # default 0.1 — faster decay
    max_graph_size_nodes: 5_000,           # hard cap
    consolidation_trigger: :every_nth_query,
    consolidation_n: 10,                   # consolidate every 10 queries
    merge_similarity_threshold: 0.88       # default 0.92 — merge more aggressively
  }
end

defp consolidation_config(:local_large) do
  %{
    min_confidence_for_retention: 0.2,
    idle_decay_rate: 0.1,
    max_graph_size_nodes: 50_000,
    consolidation_trigger: :periodic,
    consolidation_interval_ms: 600_000,    # every 10 min
    merge_similarity_threshold: 0.92
  }
end

defp consolidation_config(:cloud_frontier) do
  %{
    min_confidence_for_retention: 0.15,
    idle_decay_rate: 0.05,                 # slow decay — cheap to keep
    max_graph_size_nodes: 500_000,
    consolidation_trigger: :periodic,
    consolidation_interval_ms: 300_000,    # every 5 min
    merge_similarity_threshold: 0.95       # conservative merge
  }
end
```

---

## 5. Cost Model

Every tier has a different cost function. The Deliberator and Attention Engine should track and expose these:

```elixir
defmodule Graphonomous.CostTracker do
  @moduledoc """
  Tracks inference cost per tier. On cloud tiers, cost is monetary (tokens × price).
  On local tiers, cost is compute time (inference_ms × opportunity_cost).
  """

  @type cost_entry :: %{
    operation: :deliberation | :exploration | :attention | :retrieval,
    tier: ModelTier.model_tier(),
    tokens_in: non_neg_integer(),
    tokens_out: non_neg_integer(),
    inference_ms: float(),
    timestamp: DateTime.t()
  }

  @doc "Record an inference cost event"
  @spec record(cost_entry()) :: :ok
  def record(entry)

  @doc "Get total cost for the current session"
  @spec session_summary() :: %{
    total_calls: non_neg_integer(),
    total_tokens: non_neg_integer(),
    total_inference_ms: float(),
    estimated_cost_usd: float() | nil,
    by_operation: map()
  }
  def session_summary()

  @doc "Get cost per deliberation (useful for budgeting)"
  @spec avg_deliberation_cost() :: %{
    avg_tokens: float(),
    avg_inference_ms: float(),
    avg_cost_usd: float() | nil
  }
  def avg_deliberation_cost()

  @doc "Check if daily cost cap has been exceeded. Returns true if
  the Attention Engine heartbeat should be paused."
  @spec budget_exceeded?() :: boolean()
  def budget_exceeded?()

  @doc "Reset daily cost counter (called at midnight or manually)"
  @spec reset_daily() :: :ok
  def reset_daily()
end
```

Telemetry integration:

```elixir
# Emitted after every LLM call
:telemetry.execute(
  [:graphonomous, :inference, :complete],
  %{tokens_in: n, tokens_out: n, inference_ms: ms},
  %{tier: tier, operation: op, scc_id: scc_id}
)
```

### 5.1 Cost Estimates by Tier

```
local_small (8B, ~15s/call):
  Single-pass deliberation: 1 call × ~1K tokens = ~15s
  Attention cycle (demand): 1 item × 1 call = ~15s
  Daily cost at 20 queries with κ>0: ~5 min inference time
  Monetary: $0 (self-hosted)

local_large (70B, ~5s/call):
  Multi-pass deliberation: 3 calls × ~2K tokens = ~15s
  Attention heartbeat (10 min): 6 cycles/hr × 2 calls = ~1 min/hr
  Daily cost: ~30 min inference time
  Monetary: $0 (self-hosted) + electricity

cloud_frontier (~1.5s/call):
  Multi-pass deliberation: 3-5 calls × ~3K tokens = ~5s
  Attention heartbeat (5 min): 12 cycles/hr × 3 calls = ~$0.50/hr
  Daily cost (active 8hr): ~$4
  Monetary: ~$4-10/day depending on query volume

WORST-CASE (cloud_frontier, all goals active, all κ>0):
  Heartbeat: 12 cycles/hr × 3 goals × (survey + deliberate + act)
           = 12 × 3 × ~5 calls = ~180 calls/hr
           ≈ ~$2/hr at frontier pricing
  Daily (8hr active): ~$16
  Daily (24hr unattended): ~$48

  → Implement a daily cost cap in CostTracker (default: $10/day)
    that pauses the heartbeat when exceeded. Resume on next day
    or on manual override. Log the pause as telemetry event.
```

---

## 6. [&] Protocol Integration

### 6.1 Tier in Governance Block

The model tier is a governance concern — it affects what the agent can do autonomously. Declare it in the `ampersand.json` governance block:

```json
{
  "governance": {
    "hard": ["..."],
    "soft": ["..."],
    "autonomy": {
      "level": "advise",
      "model_tier": "local_small",
      "heartbeat_seconds": null,
      "budget": {
        "max_actions_per_hour": 2,
        "max_deliberation_calls_per_query": 1,
        "require_approval_for": ["act", "propose"]
      }
    }
  }
}
```

When `model_tier` is declared, the runtime loads the corresponding profile and uses it as defaults. Explicit budget values override tier defaults.

### 6.2 Tier-Aware Pipeline Compilation

When `ampersand compose` processes a pipeline, it validates against the declared tier:

```
# This pipeline:
query
  |> &memory.graph.recall()
  |> &memory.graph.topology()
  |> &reason.deliberate(budget: :κ)
  |> &memory.graph.store()

# Compiles differently per tier:

# local_small: deliberate step uses single_pass strategy,
#   skips SCCs with κ < 2, enriches κ=1 regions with topology notes

# cloud_frontier: deliberate step uses multi_pass strategy,
#   full partition-and-reconcile for all κ > 0 SCCs
```

The pipeline declaration is the same. The tier determines compilation. This is the Terraform analogy extended: same HCL, different providers, different execution plans.

---

## 7. Phase 0 Validation Test

Before building the full Deliberator/Attention stack, validate the core thesis on the target hardware. This is the single most important test:

### 7.1 The Test

```
1. Seed Graphonomous with a small cyclic knowledge graph (~10-20 nodes)
   containing at least one SCC with κ ≥ 1.

2. Query the graph about a topic that spans the SCC.

3. Run three conditions:
   A. Raw retrieval — no topology, no deliberation
   B. Enriched retrieval — topology notes included in context
   C. Single-pass deliberation — full structured prompt with fault lines

4. For each condition, have the model (your target 8B) generate an answer.

5. Human-evaluate: which answer best handles the circular dependency?
   Score 1-5 on coherence (does it make sense?) and
   1-5 on circularity awareness (does it acknowledge/resolve the loop?).
```

### 7.2 What Success Looks Like

- **B > A** would validate that topology annotations help even without deliberation
- **C > B** would validate that fault-line prompting adds value on 8B
- **C ≈ B** would suggest deliberation overhead isn't worth it on 8B — stick with enriched retrieval
- **A ≈ B ≈ C** would suggest the 8B model can't usefully leverage topology information at all — the architecture's value proposition depends on the model being able to use structural hints

If A ≈ B ≈ C, the κ computation is still valuable (it's free CPU work that correctly identifies structure), but the *deliberation* pipeline should be deferred to a larger model. The system would run in "topology-aware retrieval" mode: compute κ, annotate results, let the calling agent handle the reasoning.

### 7.3 Elixir Test Sketch

```elixir
defmodule Graphonomous.ModelTierValidationTest do
  use ExUnit.Case

  @tag :manual
  @tag :requires_llm
  test "Phase 0: topology awareness improves answer quality on target model" do
    # 1. Seed a cyclic business graph
    seed_business_cycle_graph()

    query = "How does R&D investment affect market share for mid-size companies?"

    # Condition A: raw retrieval
    raw = Graphonomous.retrieve_context(query, topology: false)
    answer_a = call_target_model(format_raw_context(raw, query))

    # Condition B: enriched retrieval (topology notes, no deliberation)
    enriched = Graphonomous.retrieve_context(query, topology: true)
    answer_b = call_target_model(format_enriched_context(enriched, query))

    # Condition C: single-pass deliberation
    deliberated = Graphonomous.retrieve_context(query,
      topology: true,
      auto_deliberate: true,
      model_tier: :local_small
    )
    answer_c = call_target_model(format_deliberated_context(deliberated, query))

    # Log for human evaluation
    IO.puts("=== CONDITION A (raw) ===\n#{answer_a}")
    IO.puts("=== CONDITION B (enriched) ===\n#{answer_b}")
    IO.puts("=== CONDITION C (deliberated) ===\n#{answer_c}")

    # Automated check: deliberated answer should mention the circular dependency
    assert String.contains?(answer_c, "feedback") or
           String.contains?(answer_c, "circular") or
           String.contains?(answer_c, "loop") or
           String.contains?(answer_c, "cycle"),
           "Single-pass deliberation should surface circularity awareness"
  end
end
```

---

## 8. Build Order (Hardware-Constrained Solo Developer)

This reorders the crosswalk's phased implementation for a solo developer validating on real hardware:

### Phase 0 — Prove the thesis (1-2 days)

```
├── Get Graphonomous running with SQLite + local embeddings (all-MiniLM-L6-v2)
├── Implement Topology.analyze/1 (Tarjan + κ) [KAPPA_BUILD_PROMPT]
├── Wire topology into retrieve_context response
├── Write the Phase 0 validation test (§7)
├── Run it. Does B > A? Does C > B?
│
└── STOP HERE if A ≈ B ≈ C. Revisit with a larger model.
```

### Phase 1 — Minimum viable κ-aware agent (3-5 days)

```
├── ModelTier module with local_small profile
├── Single-pass deliberation (Deliberator with strategy: :single_pass)
├── Enriched retrieval for κ=1 (topology notes, no LLM call)
├── Demand-triggered attention (on query, not heartbeat)
├── Crystallization (write conclusions back, aggressive mode)
├── CostTracker (telemetry for inference time)
│
└── Gate: retrieve cyclic graph → enriched/deliberated answer → conclusion node exists
```

### Phase 2 — BendScript visual debugging (2-3 days)

```
├── Port κ to JavaScript
├── SCC visualization, HUD, fault-line highlighting
├── Visual debugging of which SCCs get deliberated vs enriched vs skipped
│
└── This gives you eyes on the graph. Invaluable for a solo developer.
```

### Phase 3 — Upgrade path (when model/hardware improves)

```
├── Multi-pass deliberation (local_large / cloud_frontier profiles)
├── Heartbeat attention engine
├── Autonomous goal generation (PROPOSE mode)
├── Protocol amendments (SPEC.md, schema, PROTOCOL_PROMPT.md)
│
└── Only build this when Phase 0 validates with the target model tier.
```

---

## 9. What to Build

### 9.1 Module: `Graphonomous.ModelTier`

**File:** `graphonomous/lib/graphonomous/model_tier.ex`

The tier profile module as specified in §2.2. Pure data — no side effects, no LLM calls.

### 9.2 Module: `Graphonomous.CostTracker`

**File:** `graphonomous/lib/graphonomous/cost_tracker.ex`

Inference cost tracking as specified in §5. ETS-backed for fast writes.

### 9.3 Modifications to Existing Modules

| File | Change |
|------|--------|
| `graphonomous/lib/graphonomous/deliberator.ex` | Read tier from config, branch on `strategy` (`:single_pass` vs `:multi_pass`), respect `kappa_deliberation_floor` |
| `graphonomous/lib/graphonomous/attention.ex` | Read tier from config, support `:demand` trigger mode, respect `propose_enabled` |
| `graphonomous/lib/graphonomous/retriever.ex` | Add `enrich_with_topology_notes/1` for sub-floor κ regions |
| `graphonomous/config/config.exs` | Add `:model_tier` configuration |

---

## 10. Tests

### File: `test/graphonomous/model_tier_test.exs`

```
[x] profile/1 returns correct defaults for each tier
[x] deliberation_config/1 returns tier-appropriate strategy
[x] attention_config/1 returns tier-appropriate trigger_mode
[x] local_small has single_pass strategy and demand trigger
[x] local_large has multi_pass strategy and heartbeat trigger
[x] cloud_frontier has multi_pass strategy and heartbeat trigger
[x] local_small has kappa_deliberation_floor of 2
[x] local_large has kappa_deliberation_floor of 1
```

### File: `test/graphonomous/model_tier_integration_test.exs`

```
[x] Deliberator with local_small config → single_pass on κ=2 SCC
[x] Deliberator with local_small config → skips κ=1 SCC (below floor)
[x] Deliberator with cloud_frontier config → multi_pass on κ=1 SCC
[x] Retriever with local_small config → enriches κ=1 with topology_notes
[x] Attention with demand trigger → does NOT fire on timer
[x] Attention with demand trigger → fires on on_demand_check call
[x] Attention with heartbeat trigger → fires on timer
[x] CostTracker records inference events and computes session summary
[x] Explicit opts override tier defaults
```

---

## 11. Success Criteria

### Gate A — Tier Routing (MUST PASS)

1. κ=0 → fast retrieval (no LLM) on ALL tiers
2. κ=1 → enriched retrieval (no LLM) on `local_small`
3. κ=1 → full deliberation on `local_large` and `cloud_frontier`
4. κ≥2 → deliberation on ALL tiers (adapted to tier strategy)

### Gate B — Single-Pass Quality (MUST PASS)

1. Single-pass prompt includes fault-line context
2. Single-pass conclusion is parseable (confidence + content)
3. Single-pass crystallization writes valid node to graph
4. Second retrieval finds crystallized conclusion

### Gate C — Cost Tracking (MUST PASS)

1. Every LLM call is tracked with tokens + duration
2. Session summary is accurate
3. Telemetry events fire for all inference

### Gate D — Phase 0 Validation (SHOULD PASS)

1. Enriched retrieval (B) scores ≥ raw retrieval (A) on human eval
2. Single-pass deliberation (C) scores ≥ enriched retrieval (B) on human eval
3. Or: clear evidence of which tier is the minimum viable tier for this architecture

---

## 12. Architectural Notes

### Why not auto-detect tier from hardware?

You could probe available VRAM, check for GPU, estimate model size. But:

1. Model quality ≠ model size. A fine-tuned 8B may outperform a generic 13B.
2. The tier determines reasoning *depth*, which depends on task domain and model strengths.
3. Auto-detection creates a false sense of optimization. Explicit configuration forces the operator to think about their hardware constraints.

Provide `:auto` as an option that guesses based on available resources, but default to explicit configuration.

### Why three tiers and not a continuous slider?

Three tiers map to three real-world deployment scenarios:
- **local_small**: Developer laptop, hobbyist, air-gapped environments
- **local_large**: Dedicated inference server, multi-GPU workstation
- **cloud_frontier**: Production deployment with API budget

A continuous slider (e.g., "reasoning depth: 0.0-1.0") would require interpolating between strategies, which adds complexity without clear benefit. The three tiers have qualitatively different strategies (single-pass vs multi-pass, demand vs heartbeat), not just quantitatively different parameters.

### How does this relate to the [&] Protocol's model-agnosticism?

The [&] Protocol is model-agnostic by design — it declares *what* capabilities an agent needs, not *how* they're implemented. Model tier adaptation is an implementation concern, not a protocol concern. The tier lives in the `governance.autonomy` block because it affects *what the agent is allowed to do*, which is governance.

A valid ampersand.json can declare `&reason.deliberate` without specifying a tier. The runtime (Graphonomous) picks the tier based on its own configuration. The protocol doesn't need to know about 8B vs 70B — it just needs to know that deliberation is a declared capability.

### The κ paradox: more valuable when inference is expensive

On cloud with cheap, fast inference, κ routing is a quality optimization — "use deliberation to get better answers on circular topics." You could skip it and still get decent answers via brute-force long-context reasoning.

On local with expensive, slow inference, κ routing is a **resource optimization** — "don't waste 15 seconds of inference on a region that doesn't need it." The κ=0 fast path (no LLM call at all, just return retrieved context) is the single biggest performance win. Every query where κ=0 saves you a full inference pass.

This means the ROI of implementing κ topology is *higher* on constrained hardware, not lower. The Tarjan + bipartition computation is CPU-bound and takes <1ms. It saves you 15+ seconds of inference on every query that hits a DAG region. The more constrained your hardware, the more valuable this routing becomes.

---

*Companion to: KAPPA_BUILD_PROMPT.md (κ computation), KAPPA_DELIBERATOR_PROMPT.md (deliberation loop), ATTENTION_ENGINE_PROMPT.md (proactive attention). This prompt ensures the architecture degrades gracefully across hardware tiers, with the same graph topology driving all decisions.*
