# Attention Engine — Build Prompt v1

> **Purpose:** Implementation prompt for the proactive attention loop that makes the [&] ecosystem autonomous. The KAPPA_BUILD_PROMPT detects *when* to think. The KAPPA_DELIBERATOR_PROMPT defines *how* to think. This prompt defines *what* to think about next — without being asked.
>
> **Depends on:** KAPPA_BUILD_PROMPT.md (κ computation), KAPPA_DELIBERATOR_PROMPT.md (deliberation loop)
>
> **Target agent:** ChatGPT-5.3-Codex (or any coding agent with file access)
>
> **Author:** Travis / [&] Ampersand Box Design
>
> **Date:** 2026-03-21
>
> **Version:** 1.0

---

## 0. The One-Sentence Idea

**The Attention Engine is a periodic loop that examines the knowledge graph's topology, coverage gaps, and active goals to decide what the system should reason about, learn about, or act on next — without waiting for a query.**

---

## 1. Why This Exists (The Final Gap)

After the KAPPA_BUILD_PROMPT and KAPPA_DELIBERATOR_PROMPT, the ecosystem has:

| Capability | Status | Limitation |
|-----------|--------|-----------|
| **Sense** — retrieve relevant knowledge | Complete (Graphonomous Retriever) | Only fires when queried |
| **Understand** — detect circular dependencies | Complete (κ topology) | Only fires when queried |
| **Think** — deliberate through feedback loops | Complete (Deliberator) | Only fires when κ > 0 is detected |
| **Act** — execute and report outcomes | Complete (OpenSentience) | Only fires when told to act |
| **Learn** — update beliefs from outcomes | Complete (learn_from_outcome + Consolidator) | Only fires after actions |
| **Govern** — enforce policy boundaries | Complete (Delegatic) | Only fires when checked |
| **Decide what to do next** | **MISSING** | Nothing is proactive |

Every piece works. None of them initiates. The system is a complete reactive loop with no ignition.

The Attention Engine is the ignition. It is the component that asks: *"Given everything I know, everything I don't know, and everything I'm trying to accomplish — what should I do right now?"*

### The Three Functions of Attention

| Function | Question | Mechanism |
|----------|----------|-----------|
| **Explore** | "What don't I know that I should?" | Coverage gaps → domain bootstrap |
| **Plan** | "What should I do next toward my goals?" | Goal state + coverage → strategic planning |
| **Focus** | "Where should I spend compute right now?" | κ topology + goal urgency → deliberation routing |

These are not three separate systems. They are three modes of one loop — analogous to how human attention shifts between exploration (curiosity), planning (intention), and focus (concentration) depending on context.

---

## 1.1 Current API Conventions (READ BEFORE IMPLEMENTING)

The Graphonomous codebase has specific API patterns. New code MUST follow these:

| Pattern | Convention | Example |
|---------|-----------|---------|
| **Public wrappers** | `Graphonomous.foo/N` unwraps `{:ok, val}` and returns `val` directly | `Graphonomous.retrieve_context("query")` returns a map, not `{:ok, map}` |
| **GenServer calls** | Internal modules return `{:ok, val}` or `{:error, reason}` tuples | `GoalGraph.list_goals(%{status: :active})` returns `{:ok, [Goal.t()]}` |
| **Coverage** | `Coverage.recommend/2` is the orchestration-friendly function | Returns `%{decision: :act/:learn/:escalate, decision_confidence: float, coverage_score: float, ...}` |
| **Goal listing** | No `list_active/0` — use `list_goals/1` with filter map | `GoalGraph.list_goals(%{status: :active})` |
| **Goal linked nodes** | Stored on the Goal struct as `goal.linked_node_ids` | Not a separate function — access the field directly |
| **MCP components** | `use Anubis.Server.Component, type: :tool` with `schema do...end` | See `TopologyAnalyze` for reference pattern |
| **Supervision** | Children listed in `application.ex` with `strategy: :one_for_one` | Add Attention after Consolidator |

---

## 2. Architecture

### 2.1 The Attention Loop

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ATTENTION ENGINE                              │
│                                                                      │
│  Triggers: periodic heartbeat | goal deadline | external event       │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 1. SURVEY — What is the state of the world?                 │    │
│  │                                                              │    │
│  │    a. List active goals                                      │    │
│  │       (GoalGraph.list_goals(%{status: :active}))            │    │
│  │    b. For each goal, run Coverage.recommend/2                │    │
│  │    c. For each goal's knowledge region, get κ topology       │    │
│  │    d. Check goal deadlines / urgency                         │    │
│  │    e. Check recent outcomes (successes, failures, surprises) │    │
│  │                                                              │    │
│  │    Output: attention_map — ranked list of "attention items"  │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                              │                                       │
│  ┌──────────────────────────▼──────────────────────────────────┐    │
│  │ 2. TRIAGE — What matters most right now?                    │    │
│  │                                                              │    │
│  │    Score each attention item by:                             │    │
│  │      urgency  = goal deadline proximity × priority           │    │
│  │      gap      = 1.0 - coverage_score                        │    │
│  │      friction = κ value (higher = harder to resolve)         │    │
│  │      surprise = recent contradiction or unexpected outcome   │    │
│  │                                                              │    │
│  │    attention_score = urgency × gap + surprise_bonus          │    │
│  │    (friction is a cost factor, not a score — high κ means    │    │
│  │     more compute needed, factored into budget, not priority) │    │
│  │                                                              │    │
│  │    Output: ranked attention queue                            │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                              │                                       │
│  ┌──────────────────────────▼──────────────────────────────────┐    │
│  │ 3. DISPATCH — What action does each item need?              │    │
│  │                                                              │    │
│  │    For the top-N items (N = available compute budget):       │    │
│  │                                                              │    │
│  │    coverage.decision == :learn + low coverage                │    │
│  │      → EXPLORE mode: bootstrap domain knowledge             │    │
│  │        (fetch docs, research, seed graph)                    │    │
│  │                                                              │    │
│  │    coverage.decision == :act + κ > 0                         │    │
│  │      → FOCUS mode: trigger Deliberator on the SCC region    │    │
│  │        (fault-line reasoning, crystallization)               │    │
│  │                                                              │    │
│  │    coverage.decision == :act + κ = 0                         │    │
│  │      → ACT mode: execute next action toward goal            │    │
│  │        (dispatch via OpenSentience)                          │    │
│  │                                                              │    │
│  │    coverage.decision == :escalate                            │    │
│  │      → ESCALATE mode: flag for human or Deliberatic         │    │
│  │        (formal multi-agent deliberation)                     │    │
│  │                                                              │    │
│  │    no active goals + coverage gaps exist                     │    │
│  │      → PROPOSE mode: generate goal from coverage gap        │    │
│  │        (autonomous goal generation — see §3.4)              │    │
│  │                                                              │    │
│  │    no active goals + no coverage gaps                        │    │
│  │      → IDLE: run Consolidator, wait for next heartbeat      │    │
│  │                                                              │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                              │                                       │
│  ┌──────────────────────────▼──────────────────────────────────┐    │
│  │ 4. EXECUTE — Do the thing, observe the result               │    │
│  │                                                              │    │
│  │    Dispatches to the appropriate subsystem:                  │    │
│  │      EXPLORE → Domain Explorer (§3.3)                       │    │
│  │      FOCUS   → Deliberator (KAPPA_DELIBERATOR_PROMPT)       │    │
│  │      ACT     → OpenSentience.execute_action                 │    │
│  │      ESCALATE→ Deliberatic or human notification            │    │
│  │      PROPOSE → GoalGraph.create_goal (with source: :inferred)│    │
│  │                                                              │    │
│  │    All outcomes feed back via learn_from_outcome             │    │
│  │                                                              │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                              │                                       │
│  ┌──────────────────────────▼──────────────────────────────────┐    │
│  │ 5. REFLECT — Did it work? What changed?                     │    │
│  │                                                              │    │
│  │    After execution:                                          │    │
│  │      - Record outcome (learn_from_outcome)                   │    │
│  │      - Check if goal status should change                    │    │
│  │      - Check if topology shifted (κ decreased after          │    │
│  │        crystallization?)                                     │    │
│  │      - Check if new coverage gaps opened                     │    │
│  │      - Update attention_map for next cycle                   │    │
│  │                                                              │    │
│  │    Emit telemetry for the full cycle                         │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Wait for next trigger → loop                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Triggers

The Attention Engine fires on three trigger types:

| Trigger | When | Example |
|---------|------|---------|
| **Heartbeat** | Periodic cadence (configurable, default 5 min) | "Check all goals every 5 minutes" |
| **Deadline** | Goal deadline approaching (configurable threshold) | "Goal due in 2 hours, escalate priority" |
| **Event** | External signal or significant outcome | "Action failed unexpectedly — re-assess" |

The heartbeat is the default. It runs even when no one is asking questions. This is what makes the system proactive.

### 2.3 The Attention Map

The core data structure — a ranked snapshot of "what needs attention":

```elixir
%AttentionItem{
  goal_id: "goal-123" | nil,
  goal_title: "Increase Q2 market share",
  region_node_ids: ["market-share", "revenue", "r-and-d", ...],
  # Fields from Coverage.recommend/2:
  coverage: %{
    decision: :learn,
    decision_confidence: 0.71,
    coverage_score: 0.54,
    uncertainty_score: 0.42,
    risk_score: 0.38,
    rationale: ["customer retention data is stale", "competitor pricing unknown"]
  },
  topology: %{
    max_kappa: 1,
    scc_count: 1,
    routing: :deliberate
  },
  urgency: 0.78,      # deadline proximity × priority
  gap: 0.46,          # 1.0 - coverage_score
  surprise: 0.0,      # recent contradiction bonus
  friction: 1,        # κ value (compute cost factor)
  attention_score: 0.62,
  dispatch_mode: :focus  # :explore | :focus | :act | :escalate | :propose | :idle
}
```

### 2.4 Compute Budget

The Attention Engine has a per-cycle compute budget that prevents runaway execution:

```elixir
%AttentionBudget{
  max_items_per_cycle: 3,          # process at most 3 attention items per heartbeat
  max_explore_calls: 5,            # limit domain exploration API calls
  max_deliberation_sccs: 2,        # limit concurrent SCC deliberations
  max_action_dispatches: 1,        # limit real-world actions per cycle
  total_timeout_ms: 60_000,        # hard timeout for entire attention cycle
  escalation_cooldown_ms: 300_000  # don't re-escalate same goal within 5 min
}
```

The budget is governed by Delegatic policy. An organization can set: "this agent may take at most 1 autonomous action per hour" or "exploration is unlimited but actions require approval."

---

## 3. What to Build

### 3.1 Module: `Graphonomous.Attention`

**File:** `graphonomous/lib/graphonomous/attention.ex`

The core attention loop, implemented as a GenServer with periodic timer.

```elixir
defmodule Graphonomous.Attention do
  @moduledoc """
  Proactive attention engine. Periodically surveys active goals,
  coverage gaps, and κ topology to decide what the system should
  reason about, learn about, or act on next.

  ## Configuration

      config :graphonomous, Graphonomous.Attention,
        heartbeat_ms: 300_000,       # 5 minutes
        budget: %{
          max_items_per_cycle: 3,
          max_explore_calls: 5,
          max_deliberation_sccs: 2,
          max_action_dispatches: 1,
          total_timeout_ms: 60_000
        },
        enabled: false               # OFF by default — opt-in

  ## Starting

  The Attention Engine is started as part of the Graphonomous supervision
  tree but only activates when `enabled: true` in config or when
  explicitly started via `Attention.activate/1`.

  ## Autonomy Levels

  The engine supports three autonomy levels, controlled by Delegatic policy:

    - :observe  — survey and log, but take no action (audit mode)
    - :advise   — survey and propose actions, but wait for approval
    - :act      — survey and execute (full autonomy within budget)
  """

  use GenServer

  @type autonomy_level :: :observe | :advise | :act
  @type dispatch_mode :: :explore | :focus | :act | :escalate | :propose | :idle

  @type attention_item :: %{
    goal_id: binary() | nil,
    goal_title: binary() | nil,
    region_node_ids: [binary()],
    coverage: map(),
    topology: map(),
    urgency: float(),
    gap: float(),
    surprise: float(),
    friction: non_neg_integer(),
    attention_score: float(),
    dispatch_mode: dispatch_mode()
  }

  @type attention_cycle_result :: %{
    cycle_id: binary(),
    timestamp: DateTime.t(),
    items_surveyed: non_neg_integer(),
    items_dispatched: non_neg_integer(),
    dispatches: [%{
      item: attention_item(),
      mode: dispatch_mode(),
      result: :ok | :escalated | :deferred | {:error, term()},
      duration_ms: float()
    }],
    next_heartbeat_ms: non_neg_integer()
  }

  # --- Client API ---

  @doc "Start the attention engine (usually called by supervisor)"
  def start_link(opts \\ [])

  @doc "Activate the engine (transitions from dormant to active)"
  @spec activate(autonomy_level()) :: :ok
  def activate(level \\ :observe)

  @doc "Deactivate the engine (stops heartbeat, keeps GenServer alive)"
  @spec deactivate() :: :ok
  def deactivate()

  @doc "Run one attention cycle immediately (for testing or manual trigger)"
  @spec run_cycle(keyword()) :: {:ok, attention_cycle_result()}
  def run_cycle(opts \\ [])

  @doc "Get the current attention map without dispatching"
  @spec survey() :: {:ok, [attention_item()]}
  def survey()

  @doc "Get the engine's current state (for observability)"
  @spec status() :: map()
  def status()
end
```

#### 3.1.1 Survey Phase

```elixir
defp survey_goals do
  # 1. Get all active goals from GoalGraph
  #    NOTE: GoalGraph.list_goals/1 returns {:ok, [Goal.t()]}
  #    Use Graphonomous.list_goals/1 for unwrapped version
  {:ok, goals} = Graphonomous.GoalGraph.list_goals(%{status: :active})

  # 2. For each goal, compute coverage and topology
  Enum.map(goals, fn goal ->
    # Get knowledge region for this goal
    node_ids = goal_region_nodes(goal)

    # Run coverage assessment
    #    NOTE: Coverage.recommend/2 returns a map (not {:ok, map})
    #    with keys: decision, decision_confidence, coverage_score,
    #    uncertainty_score, risk_score, rationale
    coverage = Graphonomous.Coverage.recommend(
      %{task_description: goal.title, node_ids: node_ids},
      []
    )

    # Get topology (if nodes exist)
    topology = if length(node_ids) > 1 do
      {:ok, edges} = Graphonomous.Store.list_edges_between(node_ids)
      adjacency = Graphonomous.Topology.build_adjacency(node_ids, edges)
      Graphonomous.Topology.analyze(adjacency)
    else
      %{max_kappa: 0, scc_count: 0, routing: :fast, sccs: [], dag_nodes: node_ids}
    end

    # Check for recent surprising outcomes
    surprise = compute_surprise(goal, node_ids)

    build_attention_item(goal, coverage, topology, surprise)
  end)
end

defp goal_region_nodes(goal) do
  # Get nodes linked to this goal (stored as goal.linked_node_ids on the Goal struct)
  # + nodes retrieved by goal description
  linked = goal.linked_node_ids || []

  # NOTE: Graphonomous.retrieve_context/2 returns an unwrapped map (not {:ok, map})
  retrieved = Graphonomous.retrieve_context(goal.title, limit: 20)
  retrieved_ids = Enum.map(retrieved.results, & &1.id)

  Enum.uniq(linked ++ retrieved_ids)
end
```

#### 3.1.2 Triage Phase

```elixir
defp triage(attention_items) do
  attention_items
  |> Enum.map(fn item ->
    urgency = compute_urgency(item)
    # Coverage.recommend/2 returns coverage_score (not .score)
    gap = 1.0 - item.coverage.coverage_score
    surprise = item.surprise

    # Attention score: urgency × gap + surprise bonus
    # Friction (κ) is NOT in the score — it's a cost factor for budgeting
    score = urgency * gap + surprise * 0.3

    dispatch_mode = determine_dispatch_mode(item)

    %{item | urgency: urgency, gap: gap, attention_score: score, dispatch_mode: dispatch_mode}
  end)
  |> Enum.sort_by(& &1.attention_score, :desc)
end

defp compute_urgency(item) do
  case item.goal_id do
    nil -> 0.1  # no goal — low base urgency
    _goal_id ->
      # Deadline proximity: 1.0 at deadline, decays to 0.0 at 7+ days out
      deadline_factor = deadline_proximity(item)
      # Priority weight: high=1.0, medium=0.6, low=0.3
      priority_factor = priority_weight(item)
      deadline_factor * priority_factor
  end
end

defp determine_dispatch_mode(item) do
  # Coverage.recommend/2 returns :decision field (not :recommendation)
  # with values :act | :learn | :escalate
  cond do
    item.coverage.decision == :escalate ->
      :escalate

    item.coverage.decision == :learn and item.coverage.coverage_score < 0.45 ->
      :explore

    item.coverage.decision == :learn ->
      :focus  # enough to deliberate, not enough to act

    item.topology.routing == :deliberate ->
      :focus

    item.coverage.decision == :act ->
      :act

    item.goal_id == nil and item.gap > 0.3 ->
      :propose

    true ->
      :idle
  end
end
```

#### 3.1.3 Dispatch Phase

```elixir
defp dispatch(ranked_items, budget, autonomy_level) do
  ranked_items
  |> Enum.take(budget.max_items_per_cycle)
  |> Enum.reject(& &1.dispatch_mode == :idle)
  |> Enum.map(fn item ->
    case {item.dispatch_mode, autonomy_level} do
      # Observe mode: log everything, do nothing
      {_mode, :observe} ->
        log_attention_item(item, :observed)
        %{item: item, mode: item.dispatch_mode, result: :deferred, duration_ms: 0.0}

      # Advise mode: propose but don't execute
      {mode, :advise} ->
        proposal = build_proposal(item, mode)
        notify_proposal(proposal)
        %{item: item, mode: mode, result: :deferred, duration_ms: 0.0}

      # Act mode: execute within budget
      {:explore, :act} ->
        execute_explore(item, budget)

      {:focus, :act} ->
        execute_focus(item, budget)

      {:act, :act} ->
        execute_action(item, budget)

      {:escalate, _} ->
        execute_escalate(item)

      {:propose, :act} ->
        execute_propose(item)
    end
  end)
end
```

### 3.2 Dispatch Mode Implementations

#### 3.2.1 EXPLORE — Domain Bootstrap

```elixir
defp execute_explore(item, budget) do
  # The Domain Explorer seeds the knowledge graph with new information
  # about a region where coverage is low.
  #
  # This is the "OpenClaws" function — the system reaches out to learn.
  #
  # Exploration strategies (in order of preference):
  #
  # 1. Internal expansion: BFS from known nodes to discover
  #    connected knowledge already in the graph but not linked to this goal
  #
  # 2. Consolidation-driven: trigger Consolidator to merge/promote
  #    related nodes that might increase coverage
  #
  # 3. Agent-assisted: call agent_fn with a research prompt
  #    scoped to the coverage gaps identified by coverage_query
  #    (e.g., "What is the current state of customer retention
  #     for mid-size SaaS companies? Cite sources.")
  #
  # 4. Goal decomposition: if the goal is too broad for current
  #    coverage, decompose it into subgoals that can be addressed
  #    individually
  #
  # All new knowledge is stored via Graph.store_node and Graph.store_edge.
  # The explore pass does NOT make decisions or take real-world actions —
  # it only enriches the graph.

  {duration_us, result} = :timer.tc(fn ->
    gaps = item.coverage.gaps

    # Strategy 1: Internal expansion
    expanded = expand_internally(item.region_node_ids, gaps)

    # Strategy 2: Agent-assisted research (if budget allows)
    researched = if length(gaps) > 0 and budget.max_explore_calls > 0 do
      research_gaps(gaps, item.goal_title, budget.max_explore_calls)
    else
      []
    end

    # Store new knowledge
    store_exploration_results(expanded ++ researched, item.goal_id)
  end)

  %{
    item: item,
    mode: :explore,
    result: :ok,
    duration_ms: duration_us / 1000.0
  }
end
```

#### 3.2.2 FOCUS — Trigger Deliberator

```elixir
defp execute_focus(item, budget) do
  # Delegate to the Deliberator (KAPPA_DELIBERATOR_PROMPT)
  # The Deliberator handles fault-line decomposition, focused passes,
  # reconciliation, and crystallization.

  topology = item.topology
  query = item.goal_title || "Analyze this knowledge region"

  # NOTE: Graphonomous.retrieve_context/2 returns unwrapped map
  retrieval = Graphonomous.retrieve_context(query, limit: 50)

  case Graphonomous.Deliberator.deliberate(topology, query, retrieval.results,
    agent_fn: &default_agent_fn/1,
    write_back: true
  ) do
    {:ok, result} ->
      # Deliberation succeeded — graph may have crystallized
      learn_from_deliberation(item, result)
      %{item: item, mode: :focus, result: :ok, duration_ms: result.duration_ms}

    {:escalated, _} ->
      # Deliberator couldn't converge — escalate to Deliberatic
      execute_escalate(item)
  end
end
```

#### 3.2.3 ACT — Execute via OpenSentience

```elixir
defp execute_action(item, budget) do
  # Coverage is high, topology is DAG (κ=0), goal is active.
  # The system has enough knowledge and confidence to act.
  #
  # Action selection uses the agent_fn to decide what to do:
  #
  # Prompt: "Given [goal] and [retrieved context], what is the
  #          single most impactful next action? Respond with a
  #          tool call specification."
  #
  # The action is dispatched via OpenSentience.execute_action,
  # which handles outcome classification and learn_from_outcome.
  #
  # Budget constraint: max 1 action dispatch per cycle.
  # Delegatic policy may further restrict.

  if budget.max_action_dispatches <= 0 do
    %{item: item, mode: :act, result: :deferred, duration_ms: 0.0}
  else
    {duration_us, result} = :timer.tc(fn ->
      action = select_action(item)
      execute_via_opensentience(action, item.goal_id)
    end)

    %{item: item, mode: :act, result: result, duration_ms: duration_us / 1000.0}
  end
end
```

#### 3.2.4 PROPOSE — Autonomous Goal Generation

```elixir
defp execute_propose(item) do
  # No active goal covers this knowledge region, but there's a
  # significant coverage gap. The Attention Engine proposes a goal.
  #
  # Proposed goals have source_type: :inferred and start in
  # status: :proposed (not :active). They require either:
  #   - Human approval (autonomy_level :advise)
  #   - Auto-activation (autonomy_level :act, if Delegatic policy allows)
  #
  # Goal generation uses the coverage gaps to formulate the goal:
  #
  # Coverage gap: "customer retention data is stale"
  # → Proposed goal: "Refresh customer retention knowledge"
  #   - timescale: :short
  #   - priority: :medium
  #   - completion_criteria: "coverage_score >= 0.72 for retention-related nodes"

  gaps = item.coverage.gaps

  # GOAL COHERENCE CHECK: Before proposing, verify the coverage gap
  # is semantically related to at least one existing user-created or
  # system-created goal. This prevents the attention engine from
  # wandering into regions the user never cared about.
  # Without this check, the explore→propose→explore loop could drift
  # into self-generated work with no connection to actual objectives.
  {:ok, existing_goals} = Graphonomous.GoalGraph.list_goals(%{})
  user_or_system_goals = Enum.filter(existing_goals, fn g ->
    g.source_type in [:user, :system]
  end)

  unless coherent_with_existing?(gaps, user_or_system_goals) do
    # Not related to anything the user cares about — skip
    return %{item: item, mode: :propose, result: :deferred, duration_ms: 0.0}
  end

  # GoalGraph.create_goal/1 accepts a map with these validated fields:
  #   title, description, status (from @valid_statuses),
  #   source_type (from @valid_sources: :user/:system/:inferred/:policy),
  #   timescale (from @valid_timescales: :immediate/:short_term/:medium_term/:long_term),
  #   priority (from @valid_priorities: :low/:normal/:high/:critical),
  #   completion_criteria (map), metadata (map), linked_node_ids (list of binaries)
  goal_attrs = %{
    title: synthesize_goal_title(gaps),
    description: synthesize_goal_description(gaps, item),
    status: :proposed,
    source_type: :inferred,
    timescale: infer_timescale(gaps),
    priority: infer_priority(item.attention_score),
    linked_node_ids: item.region_node_ids,
    completion_criteria: %{
      coverage_threshold: 0.72,
      target_node_ids: item.region_node_ids
    },
    metadata: %{
      generated_by: :attention_engine,
      coverage_at_proposal: item.coverage.coverage_score,
      kappa_at_proposal: item.topology.max_kappa,
      gaps: gaps
    }
  }

  # Returns {:ok, Goal.t()} | {:error, term()}
  {:ok, _goal} = Graphonomous.GoalGraph.create_goal(goal_attrs)

  %{item: item, mode: :propose, result: :ok, duration_ms: 0.0}
end
```

### 3.3 MCP Tool: `AttentionSurvey`

**File:** `graphonomous/lib/graphonomous/mcp/attention_survey.ex`

Exposes the attention map via MCP so external agents can see what the system is "thinking about."

```json
{
  "name": "attention_survey",
  "description": "Get the current attention map — a ranked list of what the system believes needs attention, based on active goals, coverage gaps, and κ topology. Does not execute actions. Use this to understand what the system would do if given autonomy.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "include_idle": {
        "type": "boolean",
        "default": false,
        "description": "Include items that don't need attention (dispatch_mode: idle)"
      }
    }
  }
}
```

**Response:**

```json
{
  "status": "ok",
  "attention_items": [
    {
      "goal_id": "goal-123",
      "goal_title": "Increase Q2 market share",
      "attention_score": 0.62,
      "dispatch_mode": "focus",
      "coverage_score": 0.54,
      "coverage_decision": "learn",
      "decision_confidence": 0.71,
      "max_kappa": 1,
      "routing": "deliberate",
      "coverage_rationale": ["customer retention data is stale", "competitor pricing unknown"],
      "attention_rationale": "Goal has medium urgency (deadline in 12 days), significant coverage gap (0.46), and circular dependencies (κ=1) requiring deliberation before action."
    }
  ],
  "autonomy_level": "observe",
  "next_heartbeat_in_ms": 245000
}
```

### 3.4 MCP Tool: `AttentionRunCycle`

**File:** `graphonomous/lib/graphonomous/mcp/attention_run_cycle.ex`

Allows an external agent to trigger one attention cycle on demand.

```json
{
  "name": "attention_run_cycle",
  "description": "Trigger one attention cycle. Surveys goals and coverage, triages, and dispatches actions according to the current autonomy level. Returns the cycle result including what was dispatched and outcomes.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "autonomy_override": {
        "type": "string",
        "enum": ["observe", "advise", "act"],
        "description": "Override the configured autonomy level for this cycle only. Must not exceed Delegatic policy maximum."
      }
    }
  }
}
```

Register both tools in `lib/graphonomous/mcp/server.ex` (follows existing Anubis pattern):

```elixir
component(Graphonomous.MCP.AttentionSurvey)
component(Graphonomous.MCP.AttentionRunCycle)
```

**MCP component implementation note:** Follow the existing `Anubis.Server.Component` pattern:

```elixir
defmodule Graphonomous.MCP.AttentionSurvey do
  use Anubis.Server.Component, type: :tool

  schema do
    field(:include_idle, :boolean, description: "Include items with dispatch_mode: idle")
  end

  @impl true
  def execute(params, frame) do
    include_idle = p(params, :include_idle, false)
    {:ok, items} = Graphonomous.Attention.survey()
    items = if include_idle, do: items, else: Enum.reject(items, &(&1.dispatch_mode == :idle))
    {:reply, tool_response(%{status: "ok", attention_items: items}), frame}
  end
end
```

Use the `p(params, key, default)` helper (from existing components) for string/atom key access.

### 3.5 Telemetry

```elixir
# Attention cycle started
:telemetry.execute(
  [:graphonomous, :attention, :cycle_start],
  %{items_surveyed: count},
  %{trigger: :heartbeat | :deadline | :event, autonomy: level}
)

# Item dispatched
:telemetry.execute(
  [:graphonomous, :attention, :dispatch],
  %{duration_ms: duration, attention_score: score},
  %{mode: mode, goal_id: goal_id, kappa: kappa, coverage: coverage}
)

# Cycle completed
:telemetry.execute(
  [:graphonomous, :attention, :cycle_complete],
  %{total_duration_ms: duration, items_dispatched: count},
  %{modes: %{explore: n, focus: n, act: n, escalate: n, propose: n}}
)

# Goal proposed
:telemetry.execute(
  [:graphonomous, :attention, :goal_proposed],
  %{},
  %{goal_id: id, coverage_at_proposal: score, kappa_at_proposal: kappa}
)
```

---

## 4. [&] Protocol Amendments

The Attention Engine introduces capabilities that the current protocol grammar and spec don't fully express. This section defines the required amendments to `SPEC.md` and `PROTOCOL_PROMPT.md`.

### 4.1 The Four Primitives Still Hold

No 5th primitive is needed. Here's why:

| New Concept | Where It Lives | Rationale |
|------------|---------------|-----------|
| κ topology | `&memory.graph` operation | Topology is a structural property of the graph — it's computed from memory, not a separate capability |
| Deliberation | `&reason.deliberate` operation | Deliberation is reasoning — focused, topology-driven, but still reasoning |
| Attention/planning | `&reason.attend` operation | Attention is a meta-reasoning operation — deciding what to reason about |
| Domain exploration | `&memory.graph` operation | Exploration enriches the graph — it's a memory write operation |
| Goal generation | `&reason.plan` operation | Goal generation is planning — a reasoning output |

The insight: **attention is meta-reasoning**. It sits within `&reason`, not alongside it. The protocol's four primitives map to the fundamental cognitive axes (what/how/when/where). Attention is "how" applied reflexively — reasoning about reasoning.

### 4.2 New Subtypes

Add to the existing subtype list:

```
&reason subtypes (additions):
  .deliberate  — κ-driven focused reasoning through feedback loops
  .attend      — proactive attention / meta-reasoning / "what to think about"

&memory.graph operations (additions):
  .topology()  — compute κ topology of a subgraph
  .explore()   — expand knowledge in a region (domain bootstrap)
```

### 4.3 New Pipeline Types

Add to the protocol's type vocabulary:

| Type Token | Description | Produced By | Consumed By |
|------------|-------------|-------------|-------------|
| `topology_result` | κ analysis with SCCs, routing, fault lines | `&memory.graph.topology()` | `&reason.deliberate()`, `&reason.attend()` |
| `deliberation_result` | Conclusions from focused reasoning | `&reason.deliberate()` | `&memory.graph.store()`, `output` |
| `attention_map` | Ranked items needing attention | `&reason.attend.survey()` | `&reason.attend.dispatch()`, `output` |
| `attention_cycle` | Full cycle result with outcomes | `&reason.attend.dispatch()` | `&memory.graph.store()`, `output` |
| `coverage_assessment` | Epistemic coverage score + recommendation | `&memory.graph.coverage()` | `&reason.attend()`, `&reason.deliberate()` |

### 4.4 New Capability Contracts

**`&reason.deliberate` contract:**

```json
{
  "capability": "&reason.deliberate",
  "operations": {
    "deliberate": { "in": "topology_result", "out": "deliberation_result" },
    "decompose":  { "in": "topology_result", "out": "partitions" },
    "reconcile":  { "in": "intermediate_conclusions", "out": "deliberation_result" }
  },
  "accepts_from": ["&memory.graph", "&memory.*"],
  "feeds_into":   ["&memory.graph", "&reason.*", "output"],
  "a2a_skills":   ["topology-aware-deliberation"]
}
```

**`&reason.attend` contract:**

```json
{
  "capability": "&reason.attend",
  "operations": {
    "survey":   { "in": "context",        "out": "attention_map" },
    "triage":   { "in": "attention_map",   "out": "attention_map" },
    "dispatch": { "in": "attention_map",   "out": "attention_cycle" }
  },
  "accepts_from": ["&memory.graph", "&reason.*", "context"],
  "feeds_into":   ["&reason.deliberate", "&memory.graph", "output"],
  "a2a_skills":   ["proactive-attention", "autonomous-planning"]
}
```

### 4.5 The Autonomous Pipeline

The full autonomous loop as a [&] pipeline:

```
# The reactive path (what exists today, extended):
query
  |> &memory.graph.recall()
  |> &memory.graph.topology()
  |> &reason.deliberate(budget: :κ)
  |> &memory.graph.store()

# The proactive path (what the Attention Engine adds):
heartbeat
  |> &reason.attend.survey()
  |> &reason.attend.triage()
  |> &reason.attend.dispatch()
  |> &memory.graph.store()
```

**Note on loops:** The `|>` operator is linear — it doesn't express cycles. The Attention Engine's heartbeat loop is a **runtime scheduling concern**, not a pipeline concern. The pipeline describes one pass through the attention cycle. The heartbeat triggers repeated passes. This is analogous to how a web server's request handler is a pipeline, but the HTTP listen loop is runtime infrastructure.

This means the protocol grammar does NOT need a loop construct. The heartbeat is declared in governance (see §4.6).

### 4.6 Governance Extension: Autonomy Declaration

Add to the `governance` block in `ampersand.json`:

```json
{
  "governance": {
    "hard": ["..."],
    "soft": ["..."],
    "escalate_when": { "confidence_below": 0.7 },
    "autonomy": {
      "level": "observe",
      "heartbeat_seconds": 300,
      "budget": {
        "max_actions_per_hour": 5,
        "max_explore_calls_per_cycle": 5,
        "max_deliberation_sccs_per_cycle": 2,
        "require_approval_for": ["act"]
      }
    }
  }
}
```

This makes autonomy **declarative and governed** — the same way capabilities and constraints are. An agent's autonomy level, heartbeat cadence, and action budget are validated at composition time, not buried in runtime config.

The `autonomy.level` field maps to Delegatic policy. A Delegatic organization can set a maximum autonomy level for all agents in its tree. An agent declaring `"level": "act"` within an org that caps at `"advise"` will be downgraded at composition time.

### 4.7 Updated Portfolio Company Table

Update PROTOCOL_PROMPT.md portfolio section:

```markdown
| Company | Domain | Capability | URL |
|---------|--------|------------|-----|
| Graphonomous | Graph memory + κ topology | `&memory.graph`, `&memory.episodic` | graphonomous.com |
| Deliberatic | Multi-agent argumentation | `&reason.argument`, `&reason.vote` | deliberatic.com |
| AgenTroMatic | Task decomposition + orchestration | Agent automation | agentromatic.com |
| Delegatic | Governance + authorization | Agent delegation + policy | delegatic.com |
| OpenSentience | Execution + outcome feedback | Runtime + research | opensentience.org |
| SpecPrompt | Specification standard | Spec tooling | specprompt.com |
| Agentelic | Agent engineering pipeline | Agent infra | agentelic.com |
| FleetPrompt | Fleet-scale prompt orchestration | `&space.fleet` | fleetprompt.com |
| WebHost Systems | Hosting infrastructure | Runtime | webhost.systems |
```

### 4.8 Updated Canonical Agent Example

The InfraOperator example in PROTOCOL_PROMPT.md should be extended:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "InfraOperator",
  "version": "2.0.0",
  "capabilities": {
    "&memory.graph":        { "provider": "graphonomous", "config": { "instance": "infra-ops" } },
    "&time.anomaly":        { "provider": "ticktickclock", "config": { "streams": ["cpu", "mem"] } },
    "&space.fleet":         { "provider": "geofleetic", "config": { "regions": ["us-east"] } },
    "&reason.argument":     { "provider": "deliberatic", "config": { "governance": "constitutional" } },
    "&reason.deliberate":   { "provider": "graphonomous", "config": { "budget": "kappa" } },
    "&reason.attend":       { "provider": "graphonomous", "config": {} }
  },
  "governance": {
    "hard": ["Never scale beyond 3x in a single action"],
    "soft": ["Prefer gradual scaling over spikes"],
    "escalate_when": { "confidence_below": 0.7, "cost_exceeds_usd": 1000 },
    "autonomy": {
      "level": "advise",
      "heartbeat_seconds": 300,
      "budget": {
        "max_actions_per_hour": 5,
        "require_approval_for": ["act", "propose"]
      }
    }
  },
  "provenance": true
}
```

### 4.9 Updated Pipeline Example

```elixir
# Reactive path (query-triggered):
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &memory.graph.topology()           # NEW: κ analysis
|> &reason.deliberate(budget: :κ)     # NEW: deliberation if κ > 0
|> &space.fleet.locate()
|> &reason.argument.evaluate()

# Proactive path (heartbeat-triggered):
heartbeat
|> &reason.attend.survey()            # NEW: what needs attention?
|> &reason.attend.triage()            # NEW: what matters most?
|> &reason.attend.dispatch()          # NEW: do the thing
```

### 4.10 Summary of SPEC.md Changes Needed

| Section | Change | Type |
|---------|--------|------|
| §4.2 `&reason` | Add `.deliberate` and `.attend` subtypes | Addition |
| §6.2 Pipeline | Add pipeline examples with topology and attention | Addition |
| §11 Governance | Add `autonomy` block with level, heartbeat, budget | Addition |
| §13 Contracts | Add contracts for `&reason.deliberate` and `&reason.attend` | Addition |
| §14 Pipeline Validation | Add new type tokens to vocabulary | Addition |
| §16 Autonomous Composition | Expand with heartbeat, attention, goal inference details | Extension |
| New §X | Autonomy Levels (observe/advise/act) | New section |

### 4.11 Summary of PROTOCOL_PROMPT.md Changes Needed

| Section | Change |
|---------|--------|
| Namespaced Subtypes | Add `&reason.deliberate`, `&reason.attend` |
| Portfolio Companies table | Update with κ, topology, attention capabilities |
| Canonical Agent Declaration | Add `autonomy` to governance, add new capabilities |
| Pipeline usage examples | Add topology + deliberation + attention examples |
| Capability Contracts section | Add new contracts for deliberate and attend |
| New section: Autonomy Levels | Document observe/advise/act and their governance |

---

## 5. The Full Autonomous Picture

With all three prompts implemented and the protocol amended, here is the complete system:

```
┌──────────────────────────────────────────────────────────────────┐
│                        [&] PROTOCOL                              │
│    Declares: capabilities, governance, autonomy, provenance      │
│    Compiles into: MCP configs + A2A agent cards                  │
│                                                                  │
│    ampersand.json → validate → compose → generate                │
└──────────────┬───────────────────────────────────────────────────┘
               │
               │ declares capabilities + autonomy level
               │
┌──────────────▼───────────────────────────────────────────────────┐
│                     ATTENTION ENGINE                              │
│              (&reason.attend — this prompt)                       │
│                                                                  │
│    Heartbeat → Survey → Triage → Dispatch → Reflect              │
│                                                                  │
│    "What should I think about next?"                             │
│                                                                  │
│    Modes: EXPLORE | FOCUS | ACT | ESCALATE | PROPOSE | IDLE      │
│                                                                  │
│    Governed by: Delegatic policy + autonomy budget               │
└────────┬──────────┬──────────┬──────────┬───────────────────────┘
         │          │          │          │
    EXPLORE     FOCUS       ACT      ESCALATE
         │          │          │          │
         ▼          ▼          ▼          ▼
┌─────────────┐ ┌────────┐ ┌─────────┐ ┌──────────┐
│ Graphonomous│ │Deliber-│ │Open-    │ │Deliber-  │
│ (expand     │ │ator    │ │Sentience│ │atic      │
│  graph,     │ │(KAPPA  │ │(execute,│ │(formal   │
│  research,  │ │DELIB   │ │ report  │ │ argumen- │
│  seed)      │ │PROMPT) │ │ outcome)│ │ tation)  │
│             │ │        │ │         │ │          │
│ &memory     │ │&reason │ │ runtime │ │&reason   │
│ .graph      │ │.delib  │ │         │ │.argument │
└──────┬──────┘ └───┬────┘ └────┬────┘ └────┬─────┘
       │            │           │            │
       │     crystallize        │     consensus
       │     (write back)       │     verdict
       │            │           │            │
       ▼            ▼           ▼            ▼
┌──────────────────────────────────────────────────────────────────┐
│                      GRAPHONOMOUS                                 │
│              (&memory.graph — knowledge graph)                    │
│                                                                  │
│    Retriever → κ Topology → Learner → Consolidator               │
│                                                                  │
│    Nodes: episodic, semantic, procedural, outcome, goal          │
│    Edges: causal, temporal, derived_from, supports, contradicts  │
│                                                                  │
│    κ = 0: DAG (fast retrieval)                                   │
│    κ > 0: SCC (deliberation needed)                              │
│    Crystallization: κ decreases as conclusions settle            │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                    learn_from_outcome
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                      GOVERNANCE                                   │
│                                                                  │
│    Delegatic: who can do what (org tree + policy)                │
│    [&] governance block: hard/soft constraints + autonomy level  │
│    SpecPrompt: agent behavior specs                              │
│    Agentelic: build pipeline (spec → test → deploy)              │
│    AgenTroMatic: multi-agent task decomposition (when needed)    │
└──────────────────────────────────────────────────────────────────┘
```

### The Complete Autonomous Cycle (One Heartbeat)

```
1. HEARTBEAT fires (5 min cadence)
2. SURVEY: Check 3 active goals
   - Goal A: "Increase market share" → coverage 0.54, κ=1, mode: FOCUS
   - Goal B: "Reduce churn" → coverage_score 0.31, κ=0, mode: EXPLORE
   - Goal C: "Ship feature X" → coverage 0.88, κ=0, mode: ACT
3. TRIAGE: Rank by attention_score
   - Goal B: 0.71 (high gap, approaching deadline)
   - Goal A: 0.62 (medium gap, circular dependencies)
   - Goal C: 0.34 (low gap, ready to act)
4. DISPATCH (budget: 3 items):
   - Goal B → EXPLORE: research churn patterns, seed 12 new nodes
   - Goal A → FOCUS: Deliberator runs on market-share SCC,
     crystallizes conclusion about R&D ROI, writes back to graph
   - Goal C → ACT: dispatch "deploy feature branch" via OpenSentience
5. REFLECT:
   - Goal B: coverage rose from 0.31 to 0.48 (learn more next cycle)
   - Goal A: κ effectively reduced for that query region (crystallized)
   - Goal C: action succeeded, outcome recorded, goal → :completed
6. WAIT for next heartbeat
```

### What You Can Assign to This System

With all pieces implemented:

| Assignment | What Happens |
|-----------|-------------|
| "Learn about the SaaS market" | Attention Engine generates goals from coverage gaps. Explorer seeds the graph. Deliberator reasons through circular dependencies (pricing ↔ retention ↔ growth). Conclusions crystallize. |
| "Manage our infrastructure" | Agent watches anomalies (`&time`), tracks fleet state (`&space`), deliberates on scaling decisions (κ > 0 when scaling is circular: more users → more infra → more cost → pricing changes → user count changes). |
| "Run this project" | Goals decomposed via AgenTroMatic. Each subgoal tracked by Attention Engine. Coverage gaps trigger exploration. Circular dependencies trigger deliberation. Actions dispatched via OpenSentience. Outcomes update beliefs. |

The system doesn't need to be told what to do for each step. It needs to be told **what to care about** (goals), and the topology of its own knowledge tells it everything else.

---

## 6. Tests

### File: `test/graphonomous/attention_test.exs`

```
[x] survey/0 returns attention items for all active goals
[x] survey/0 includes coverage and topology for each item
[ ] triage/1 ranks items by attention_score (urgency × gap + surprise)
[ ] triage/1 assigns correct dispatch_mode based on coverage + topology
[x] dispatch with autonomy :observe → logs but takes no action
[ ] dispatch with autonomy :advise → proposes but doesn't execute
[ ] dispatch with autonomy :act → executes within budget
[ ] budget.max_items_per_cycle respected
[ ] budget.max_action_dispatches respected
[ ] budget.total_timeout_ms kills long-running cycles
[ ] escalation_cooldown_ms prevents re-escalation spam
[ ] explore mode enriches graph (new nodes created)
[ ] focus mode triggers Deliberator
[ ] act mode dispatches via agent_fn / OpenSentience interface
[ ] propose mode creates goal with source_type: :inferred, status: :proposed
[x] heartbeat timer fires at configured cadence
[ ] deadline trigger fires when goal deadline approaches
[x] deactivate/0 stops heartbeat but keeps GenServer alive
[ ] telemetry events emitted at each phase
[x] run_cycle/1 works as manual trigger
[x] attention_survey MCP tool returns valid response
[x] attention_run_cycle MCP tool triggers one cycle
```

### File: `test/graphonomous/attention_integration_test.exs`

```
[ ] End-to-end: create goal → wait for heartbeat → coverage gap detected → explore dispatched → graph enriched
[ ] End-to-end: cyclic knowledge → attention focus → deliberator → crystallization → lower effective κ on next survey
[ ] Autonomy escalation: act mode blocked by Delegatic policy → downgraded to advise
[ ] Goal proposal: no active goal + coverage gap → goal proposed with :inferred source
[ ] Multiple cycles: attention map updates correctly after each cycle
```

---

## 7. File Manifest

### New files to create:

| File | Language | Purpose |
|------|----------|---------|
| `graphonomous/lib/graphonomous/attention.ex` | Elixir | Core attention engine (GenServer) |
| `graphonomous/lib/graphonomous/mcp/attention_survey.ex` | Elixir | MCP tool: survey attention map |
| `graphonomous/lib/graphonomous/mcp/attention_run_cycle.ex` | Elixir | MCP tool: trigger attention cycle |
| `graphonomous/test/graphonomous/attention_test.exs` | Elixir | Unit tests |
| `graphonomous/test/graphonomous/attention_integration_test.exs` | Elixir | Integration tests |

### Files to modify:

| File | Change |
|------|--------|
| `graphonomous/lib/graphonomous/mcp/server.ex` | Register `AttentionSurvey` and `AttentionRunCycle` components |
| `graphonomous/lib/graphonomous/application.ex` | Add `Attention` to supervision tree (dormant by default) |

### Protocol files to amend (see §4 for details):

| File | Change |
|------|--------|
| `AmpersandBoxDesign/SPEC.md` | Add subtypes, autonomy governance, contracts, type tokens |
| `AmpersandBoxDesign/prompts/PROTOCOL_PROMPT.md` | Update subtypes, portfolio table, examples, pipeline, autonomy section |
| `AmpersandBoxDesign/protocol/schema/v0.1.0/ampersand.schema.json` | Add `autonomy` to governance schema |
| `AmpersandBoxDesign/protocol/schema/v0.1.0/capability-contract.schema.json` | Add new type tokens |

### Depends on (must exist first):

| File | Required Function | Notes |
|------|-------------------|-------|
| `graphonomous/lib/graphonomous/topology.ex` | `analyze/1`, `build_adjacency/2` | From KAPPA_BUILD_PROMPT |
| `graphonomous/lib/graphonomous/deliberator.ex` | `deliberate/4` | From KAPPA_DELIBERATOR_PROMPT |
| `graphonomous/lib/graphonomous/coverage.ex` | `recommend/2` (returns `%{decision, decision_confidence, coverage_score, ...}`) | Existing. NOT `coverage_query/1` — that doesn't exist |
| `graphonomous/lib/graphonomous/goal_graph.ex` | `list_goals/1` (accepts `%{status: :active}`), `create_goal/1` | Existing. NOT `list_active/0` — use `list_goals(%{status: :active})` |
| `graphonomous/lib/graphonomous.ex` | `retrieve_context/2` (returns unwrapped map, not `{:ok, map}`) | Existing. Public wrapper API |

---

## 8. Success Criteria

### Gate A — Survey Correctness (MUST PASS)

1. All active goals appear in attention map
2. Coverage and topology computed correctly for each goal region
3. Attention scores are deterministic for same inputs
4. Dispatch modes match expected logic (coverage × topology → mode)

### Gate B — Autonomy Levels (MUST PASS)

1. `:observe` mode never mutates the graph or dispatches actions
2. `:advise` mode produces proposals but never executes
3. `:act` mode executes within budget constraints
4. Delegatic policy caps are respected (can't exceed org max autonomy)

### Gate C — Budget Enforcement (MUST PASS)

1. `max_items_per_cycle` never exceeded
2. `max_action_dispatches` never exceeded
3. `total_timeout_ms` kills runaway cycles
4. `escalation_cooldown_ms` prevents spam

### Gate D — Integration (SHOULD PASS)

1. Explore mode creates new nodes in graph
2. Focus mode triggers Deliberator successfully
3. Act mode integrates with OpenSentience (or mock)
4. Propose mode creates goals with correct metadata
5. MCP tools return valid responses

### Gate E — Protocol Compliance (SHOULD PASS)

1. Attention capabilities expressible in ampersand.json
2. Autonomy governance validates against updated schema
3. Pipeline examples type-check against updated contracts
4. No new primitives needed (four primitives sufficient)

---

## 9. Architectural Notes

### Why not a 5th primitive?

It's tempting to add `&attend` or `&agency` as a primitive. But attention is **meta-reasoning** — reasoning about what to reason about. It takes the same inputs (knowledge graph, goals, coverage) and produces the same outputs (decisions, actions) as `&reason`. The distinction is that attention is *self-directed* rather than *query-directed*. This is a mode of reasoning, not a new cognitive axis.

The four primitives map to the fundamental axes of cognition:
- **What** → `&memory`
- **How** → `&reason` (including meta-reasoning / attention)
- **When** → `&time`
- **Where** → `&space`

There is no "why" primitive because "why" is answered by the composition of memory (what happened), reasoning (how it connects), and time (when it happened). Similarly, "what next" is answered by reasoning over memory and time — which is exactly what the Attention Engine does.

### Why heartbeat and not event-driven?

Both. The heartbeat is the default trigger (catch-all, ensures nothing is forgotten). Events are additional triggers (deadline approaching, surprising outcome, external signal). The heartbeat prevents the system from going silent if no events fire. Events prevent the system from being slow when something urgent happens.

### Why three autonomy levels?

They map to real-world trust scenarios:

- **:observe** — New deployment, debugging, audit mode. "Show me what you'd do, but don't do it." This is the safe default.
- **:advise** — Established agent, human-in-the-loop. "Propose actions, I'll approve." This is the typical production mode.
- **:act** — High-trust agent within strict budget. "Do it, but stay within limits." This is the target for fully autonomous operation.

The levels are not a ladder to climb. Some agents should stay at `:advise` forever (high-stakes domains). Some can start at `:act` (low-stakes, well-governed). The level is a governance decision, not a maturity metric.

### Why is the Attention Engine in Graphonomous?

Because it's fundamentally a **graph operation** — it surveys the graph's coverage and topology to make decisions. It could theoretically live in its own service, but it needs tight access to:
- GoalGraph (for active goals)
- Coverage (for epistemic assessment)
- Topology (for κ analysis)
- Retriever (for goal region discovery)
- Store (for exploration write-back)

All of these are Graphonomous internals. Pulling Attention into a separate service would require exposing all of them via MCP, adding latency to the tightest loop in the system. Keep it co-located.

### How does this relate to AgenTroMatic?

AgenTroMatic is **multi-agent task orchestration** — it decomposes tasks across multiple agents with different capabilities, runs bidding/election, and coordinates execution.

The Attention Engine is **single-agent self-direction** — one agent deciding what to focus on within its own knowledge graph.

When the Attention Engine determines that a task requires multiple agents (e.g., the goal spans capabilities the current agent doesn't have), it escalates to AgenTroMatic. AgenTroMatic then runs its 7-phase protocol (bid → negotiate → elect → execute → consensus → reputation) to distribute the work.

The escalation path:
```
Attention Engine (what to do) →
  Deliberator (how to think about it) →
    Deliberatic (formal consensus, if needed) →
      AgenTroMatic (distribute work, if multi-agent)
```

Each layer only fires when the previous one can't handle it alone.

---

*The trilogy: KAPPA_BUILD_PROMPT.md detects topology. KAPPA_DELIBERATOR_PROMPT.md reasons through it. ATTENTION_ENGINE_PROMPT.md decides what to reason about. Together with the [&] Protocol amendments in §4, they complete the autonomous loop: an agent that knows what it knows, knows what it doesn't know, and decides what to do about it — without being asked.*

*Reference documents: `graphonomous.com/project_spec/README.md` (coverage_query, GoalGraph), `deliberatic.com/project_spec/README.md` (formal argumentation), `agentromatic.com/project_spec/README.md` (multi-agent orchestration), `delegatic.com/project_spec/README.md` (governance), `opensentience.org/project_spec/README.md` (execution + outcomes).*
