# κ-Driven Deliberation Orchestrator — Build Prompt v1

> **Purpose:** Implementation prompt for the deliberation loop that κ triggers. The KAPPA_BUILD_PROMPT tells you *when* to think. This prompt tells you *how* to think — mechanically decomposing circular knowledge into focused reasoning passes driven by graph topology.
>
> **Depends on:** KAPPA_BUILD_PROMPT.md (κ computation must exist first)
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

**When κ > 0, fault-line edges become prompt boundaries. The Deliberator decomposes circular knowledge along those boundaries, runs focused reasoning passes on each partition, reconciles them, and writes conclusions back into the graph — reducing κ over time as uncertainty crystallizes into settled knowledge.**

---

## 1. Why This Exists (The Gap)

The [&] ecosystem already has:

| Product | What It Does | What It Doesn't Do |
|---------|-------------|-------------------|
| **Graphonomous** (κ computation) | Detects topology, returns `routing: "deliberate"` + fault lines | Doesn't execute the deliberation. Returns metadata and hopes the caller knows what to do. |
| **Deliberatic** | Formal multi-agent argumentation (Dung's AAF, Byzantine consensus, constitution DSL) | Overkill for single-agent reasoning on a 4-node cycle. Requires multiple agents submitting positions. |
| **AgenTroMatic** | Multi-agent task decomposition + bidding + election | Assumes tasks are pre-decomposed. Doesn't know about graph topology or fault lines. |
| **OpenSentience** | Executes actions, reports outcomes, closes feedback loop | Doesn't decide *what* to reason about. Waits for decisions to execute. |

**The gap:** Nothing takes a κ > 0 result and *mechanically drives focused reasoning* using the graph's own structure as the orchestration template. The Deliberator fills this gap as a **single-agent reasoning loop** that:

1. Uses fault-line edges as decomposition boundaries (not human-authored task splits)
2. Runs focused passes with subgraph-scoped context (not the whole graph)
3. Writes conclusions back as new nodes (not ephemeral chain-of-thought)
4. Reduces κ over time (the graph settles)
5. Escalates to Deliberatic only when single-agent convergence fails

### Relationship to Deliberatic

Deliberatic is **not replaced**. It remains the formal multi-agent argumentation protocol for high-stakes decisions requiring Byzantine fault tolerance, evidence chains, and constitutional constraints. The Deliberator is a **lightweight predecessor** — the thing you try first. Think of it as:

```
κ detected → Deliberator (single-agent, fast, graph-local)
           → if convergence fails → Deliberatic (multi-agent, formal, consensus)
           → if task decomposition needed → AgenTroMatic (bidding, election)
```

Deliberatic's formal argumentation is the escalation path, not the default path. Most κ > 0 regions can be resolved by a single agent reasoning through the fault lines systematically.

---

## 1.1 Current API Conventions (READ BEFORE IMPLEMENTING)

| Pattern | Convention |
|---------|-----------|
| **`Graphonomous.retrieve_context/2`** | Returns unwrapped map (not `{:ok, map}`). Contains `.results`, `.topology`, `.causal_context`, `.stats` |
| **`Store.list_edges_between/1`** | Returns `{:ok, [Edge.t()]}` |
| **`Topology.analyze/1`** | Returns map with `.sccs`, `.dag_nodes`, `.routing`, `.max_kappa`, `.scc_count` |
| **MCP components** | `use Anubis.Server.Component, type: :tool` with `schema do...end` block. Return `{:reply, tool_response(payload), frame}` |
| **Param access** | Use `p(params, :key, default)` helper in MCP components for string/atom key access |
| **Supervision** | Not needed for Deliberator (runs as tasks under calling process) |

---

## 2. Architecture

### 2.1 The Deliberation Loop

```
┌──────────────────────────────────────────────────────────────────┐
│                    DELIBERATION ORCHESTRATOR                      │
│                                                                  │
│  Input: topology_result from retrieve_context (κ > 0)            │
│         original_query                                           │
│         retrieval_results                                        │
│                                                                  │
│  For each SCC where κ > 0:                                       │
│                                                                  │
│    1. DECOMPOSE                                                  │
│       │ Read fault_line_edges from topology                      │
│       │ Partition SCC nodes along each fault line                │
│       │ Each partition = one "reasoning focus"                   │
│       │                                                          │
│    2. FOCUS (parallel, up to budget.agent_count)                 │
│       │ For each partition:                                      │
│       │   a. Extract subgraph: partition nodes + boundary edges  │
│       │   b. Build focused prompt with ONLY that context         │
│       │   c. Hold fault-line assumption fixed                    │
│       │   d. Reason forward through the partition                │
│       │   e. Produce intermediate conclusion                     │
│       │                                                          │
│    3. RECONCILE                                                  │
│       │ Feed ALL intermediate conclusions back through           │
│       │   full SCC context                                       │
│       │ Check: do conclusions contradict?                        │
│       │ Check: confidence ≥ budget.confidence_threshold?         │
│       │                                                          │
│    4. CONVERGE or ESCALATE                                       │
│       │ If confident: write conclusion nodes to graph            │
│       │ If contradictory: retry with different fault-line focus  │
│       │ If budget exhausted: escalate to Deliberatic             │
│       │                                                          │
│    5. CRYSTALLIZE                                                │
│       │ Write conclusion as new :semantic node                   │
│       │ Add :derived_from edges to source nodes                  │
│       │ Graph topology shifts → κ may decrease                   │
│       │ Emit telemetry                                           │
│                                                                  │
│  Output: conclusions + updated topology + confidence scores      │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Core Insight: Fault Lines Are Prompt Boundaries

This is the key architectural idea. A fault-line edge is the minimum-cut edge in an SCC — the weakest link in a feedback loop. The Deliberator treats each fault line as a **conditional assumption**:

```
SCC: A → B → C → D → A
Fault line: D → A (the weakest causal link)

Pass 1: "Assume D→A holds. Given that, what follows for A→B→C→D?"
Pass 2: "Assume D→A does NOT hold. Given that, what follows?"
Reconciliation: "Given both analyses, what is the actual relationship D→A?"
```

For κ = 2 (two independent fault lines), you get a 2×2 matrix of assumptions. The budget caps this at `max_iterations` passes.

The graph's structure **mechanically determines** the prompt structure. No human prompt engineering. The topology *is* the prompt template.

### 2.3 Graph Crystallization

The most important property: **deliberation changes the graph.**

When the Deliberator produces a conclusion, it writes back:

```
[New Node] "R&D investment has diminishing returns above $10M/quarter
            for companies under 500 employees"
  type: :semantic
  confidence: 0.82
  metadata: %{
    derived_by: :deliberator,
    source_scc: "scc-0",
    source_kappa: 1,
    fault_lines_examined: ["product-quality→market-share"],
    iteration: 2
  }

[New Edges]
  "conclusion-node" ←derived_from— "market-share"
  "conclusion-node" ←derived_from— "r-and-d"
  "conclusion-node" ←derived_from— "product-quality"
  "conclusion-node" ←derived_from— "revenue"
```

This conclusion node **breaks the cycle** for future queries. The next time someone asks about R&D investment, the retriever finds the conclusion node (high confidence, recent), and the subgraph topology may now show κ = 0 for that specific question — because the circular dependency has been partially resolved into a settled fact.

Over time, heavily-queried regions of the graph crystallize from circular uncertainty (κ > 0) into linear knowledge (κ = 0). Rarely-queried regions remain circular until someone asks. The graph **self-organizes** around actual information needs.

### 2.4 Escalation Rules

| Condition | Action |
|-----------|--------|
| Single SCC, κ ≤ 2, single agent available | Deliberator handles locally |
| Confidence below threshold after max_iterations | Escalate to Deliberatic (formal argumentation) |
| Multiple SCCs with κ > 2, task is decomposable | Escalate to AgenTroMatic (parallel agent assignment) |
| Policy constraint (Delegatic) blocks autonomous conclusion | Escalate to human via OpenSentience |
| Conclusion contradicts existing high-confidence node | Escalate to Deliberatic (evidence-based resolution) |

---

## 3. What to Build

### 3.1 Module: `Graphonomous.Deliberator`

**File:** `graphonomous/lib/graphonomous/deliberator.ex`

This is the core deliberation loop. It consumes topology results and produces conclusions.

#### 3.1.1 Public API

```elixir
defmodule Graphonomous.Deliberator do
  @moduledoc """
  κ-driven deliberation orchestrator. When topology analysis returns κ > 0,
  the Deliberator decomposes circular knowledge along fault-line edges,
  runs focused reasoning passes on each partition, reconciles them,
  and writes conclusions back into the graph.

  ## Usage

      topology = Graphonomous.Topology.analyze(adjacency)
      case topology.routing do
        :fast -> # single-pass retrieval is sufficient
        :deliberate ->
          Deliberator.deliberate(topology, query, retrieval_results)
      end
  """

  @type conclusion :: %{
    content: binary(),
    confidence: float(),
    source_scc_id: binary(),
    source_kappa: non_neg_integer(),
    fault_lines_examined: [{binary(), binary()}],
    iteration: non_neg_integer(),
    converged: boolean()
  }

  @type deliberation_result :: %{
    conclusions: [conclusion()],
    iterations_used: non_neg_integer(),
    converged: boolean(),
    escalated: boolean(),
    escalation_reason: binary() | nil,
    topology_before: map(),
    topology_after: map() | nil,
    duration_ms: float()
  }

  @doc """
  Run the deliberation loop for all SCCs with κ > 0 in the topology result.

  Options:
    - `:agent_fn` — function that takes a focused prompt and returns a response.
      Signature: `(prompt :: binary()) -> {:ok, binary()} | {:error, term()}`
      This is the LLM call. Injected for testability.
    - `:write_back` — whether to write conclusions to the graph (default: true)
    - `:escalation_callback` — function called when deliberation fails to converge.
      Signature: `(scc :: map(), reason :: binary()) -> :ok`

  Note on API conventions: follows Graphonomous public API style where
  `Graphonomous.retrieve_context/2` returns an unwrapped map (not `{:ok, map}`).
  The Deliberator returns `{:ok, result}` tuples for explicit success/error
  handling since deliberation can fail in more ways than retrieval.
  """
  @spec deliberate(
    topology :: map(),
    query :: binary(),
    retrieval_results :: [map()],
    opts :: keyword()
  ) :: {:ok, deliberation_result()} | {:error, term()}
  def deliberate(topology, query, retrieval_results, opts \\ [])
end
```

#### 3.1.2 Internal Functions

**`decompose/1`** — Partition an SCC along fault lines

```elixir
@doc false
@spec decompose(scc :: map()) :: [partition()]
def decompose(scc) do
  # For each fault-line edge {source, target}:
  #   1. Remove that edge from the SCC's internal adjacency
  #   2. The resulting graph may split into reachable partitions
  #   3. Each partition = a "reasoning focus" with:
  #      - nodes: the partition's node set
  #      - boundary: the removed fault-line edge (the assumption to hold fixed)
  #      - context_nodes: nodes in the partition + immediate neighbors across the fault line
  #
  # For κ = 1: one fault line → two partitions → two focused passes
  # For κ = 2: two fault lines → up to four partitions → capped by budget.max_iterations
end
```

**`build_focused_prompt/4`** — Construct a prompt scoped to one partition

```elixir
@doc false
@spec build_focused_prompt(
  query :: binary(),
  partition :: partition(),
  scc :: map(),
  retrieval_results :: [map()]
) :: binary()
def build_focused_prompt(query, partition, scc, retrieval_results) do
  # Structure:
  #
  # CONTEXT (scoped):
  #   Only nodes in this partition + boundary nodes.
  #   Include node content, confidence, edge relationships.
  #
  # ASSUMPTION (from fault line):
  #   "For this analysis, assume the relationship [source] → [target]
  #    holds with the current confidence of [X]. Reason forward from
  #    this assumption through the following knowledge."
  #
  # QUERY:
  #   The original user query, unchanged.
  #
  # INSTRUCTION:
  #   "Given only the context above and the stated assumption,
  #    what conclusion can you draw about [query]?
  #    State your confidence (0.0-1.0) and reasoning."
  #
  # The prompt does NOT include:
  #   - Nodes from other partitions (prevents context bleed)
  #   - The full graph (focuses attention)
  #   - Other fault-line assumptions (one at a time)
end
```

**`reconcile/4`** — Merge intermediate conclusions

```elixir
@doc false
@spec reconcile(
  intermediates :: [intermediate_conclusion()],
  scc :: map(),
  query :: binary(),
  budget :: map()
) :: {:converged, conclusion()} | {:divergent, [intermediate_conclusion()]}
def reconcile(intermediates, scc, query, budget) do
  # FAST PATH: If intermediate conclusions agree (embedding similarity
  # above threshold), skip the reconciliation LLM call entirely.
  # Take the higher-confidence conclusion directly. This saves ~33%
  # of LLM calls and provides a convergence signal that doesn't
  # depend on the model's metacognitive abilities.
  #
  # agreement_threshold = 0.85 (cosine similarity between conclusion embeddings)
  # If all pairs of intermediates exceed this threshold:
  #   → pick highest-confidence intermediate
  #   → return {:converged, best_intermediate}
  #
  # FULL PATH: If intermediates disagree, build a reconciliation prompt:
  #
  # INTERMEDIATE CONCLUSIONS:
  #   [List each partition's conclusion + confidence + assumption]
  #
  # FULL SCC CONTEXT:
  #   [All nodes in the SCC — now the agent sees the complete picture]
  #
  # INSTRUCTION:
  #   "These conclusions were reached by examining different parts of
  #    the feedback loop [SCC description]. Some were derived under
  #    different assumptions about [fault-line edges].
  #
  #    Synthesize a unified conclusion. If the intermediate conclusions
  #    contradict, identify which assumption was wrong and why.
  #    State your final confidence (0.0-1.0)."
  #
  # Convergence check:
  #   If final_confidence >= budget.confidence_threshold → :converged
  #   If final_confidence < threshold → :divergent (may retry or escalate)
end
```

**`crystallize/3`** — Write conclusions back to the graph

```elixir
@doc false
@spec crystallize(conclusion :: conclusion(), scc :: map(), opts :: keyword()) ::
  {:ok, node_id :: binary()} | {:error, term()}
def crystallize(conclusion, scc, opts) do
  # 1. Create a new :semantic node with the conclusion content
  #    - confidence = conclusion.confidence
  #    - metadata includes deliberation provenance:
  #      %{
  #        derived_by: :deliberator,
  #        source_scc: scc.id,
  #        source_kappa: scc.kappa,
  #        fault_lines_examined: [...],
  #        iteration: N,
  #        query: original_query
  #      }
  #
  # 2. Create :derived_from edges from conclusion node to each source node in the SCC
  #    - weight proportional to that node's contribution to the conclusion
  #
  # 3. Optionally create :supports or :contradicts edges if the conclusion
  #    explicitly agrees with or opposes existing nodes
  #
  # 4. The new node + edges change the graph topology.
  #    Next retrieve_context call to this region will find the conclusion node
  #    (high confidence, recent timestamp) and may see reduced κ.
  #
  # 5. Emit telemetry: [:graphonomous, :deliberator, :crystallize]
end
```

#### 3.1.3 The Loop (putting it together)

```elixir
defp deliberate_scc(scc, query, retrieval_results, budget, opts) do
  agent_fn = Keyword.fetch!(opts, :agent_fn)
  iteration = 0
  max = budget.max_iterations

  partitions = decompose(scc)

  # Phase: FOCUS — run partitions in parallel up to agent_count
  intermediates =
    partitions
    |> Enum.take(max)  # cap by budget
    |> Task.async_stream(
      fn partition ->
        prompt = build_focused_prompt(query, partition, scc, retrieval_results)
        {:ok, response} = agent_fn.(prompt)
        parse_intermediate(response, partition)
      end,
      max_concurrency: budget.agent_count,
      timeout: round(30_000 * budget.timeout_multiplier)
    )
    |> Enum.map(fn {:ok, result} -> result end)

  # Phase: RECONCILE
  case reconcile(intermediates, scc, query, budget) do
    {:converged, conclusion} ->
      if Keyword.get(opts, :write_back, true) do
        {:ok, _node_id} = crystallize(conclusion, scc, opts)
      end
      {:ok, conclusion}

    {:divergent, _intermediates} when iteration < max - 1 ->
      # Retry with different fault-line focus
      # (rotate which fault line is held fixed vs. questioned)
      retry_with_rotated_focus(scc, query, retrieval_results, budget, opts, iteration + 1)

    {:divergent, intermediates} ->
      # Budget exhausted — escalate
      escalation_callback = Keyword.get(opts, :escalation_callback, &default_escalation/2)
      escalation_callback.(scc, "Divergent after #{max} iterations")
      {:escalated, intermediates}
  end
end
```

### 3.2 MCP Tool: `Deliberate`

**File:** `graphonomous/lib/graphonomous/mcp/deliberate.ex`

Exposes deliberation as an MCP tool so external agents can trigger it explicitly.

```json
{
  "name": "deliberate",
  "description": "Run κ-driven focused deliberation on a knowledge region. Decomposes circular dependencies along fault-line edges, reasons through each partition independently, and synthesizes a unified conclusion. Use when retrieve_context returns routing: 'deliberate'. Writes conclusions back to the graph, reducing κ for future queries.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "The question or topic requiring deliberation."
      },
      "node_ids": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Optional. Node IDs to deliberate over. If omitted, retrieves relevant nodes first."
      },
      "write_back": {
        "type": "boolean",
        "default": true,
        "description": "Whether to write conclusion nodes back to the graph."
      }
    },
    "required": ["query"]
  }
}
```

**Response:**

```json
{
  "status": "ok",
  "query": "How does R&D investment affect market share for mid-size companies?",
  "deliberation": {
    "converged": true,
    "iterations_used": 2,
    "conclusions": [
      {
        "content": "R&D investment shows diminishing returns on market share above $10M/quarter for companies under 500 employees, mediated by product quality improvements that take 2-3 quarters to manifest in customer retention metrics.",
        "confidence": 0.84,
        "source_scc_id": "scc-0",
        "source_kappa": 1,
        "fault_lines_examined": [
          {"source": "product-quality", "target": "market-share"}
        ]
      }
    ],
    "topology_change": {
      "kappa_before": 1,
      "kappa_after": 1,
      "new_nodes_created": 1,
      "note": "Conclusion node added. Future queries to this region may see reduced effective κ as the conclusion provides a shortcut through the feedback loop."
    }
  }
}
```

Register in `lib/graphonomous/mcp/server.ex` (follows existing Anubis component pattern):

```elixir
component(Graphonomous.MCP.Deliberate)
```

**MCP component implementation note:** Follow the existing `Anubis.Server.Component` pattern used in `TopologyAnalyze`:

```elixir
defmodule Graphonomous.MCP.Deliberate do
  use Anubis.Server.Component, type: :tool

  schema do
    field(:query, :string, description: "The question or topic requiring deliberation.")
    field(:node_ids, :array, description: "Optional. Node IDs to deliberate over.")
    field(:write_back, :boolean, description: "Write conclusion nodes back to graph.")
  end

  @impl true
  def execute(params, frame) do
    # Use p(params, :key) helper for string/atom key access
    # Return {:reply, tool_response(payload), frame}
  end
end
```

### 3.3 Wire into Retriever (optional auto-deliberation)

**File:** `graphonomous/lib/graphonomous/retriever.ex`

After the topology analysis step added by KAPPA_BUILD_PROMPT, optionally trigger deliberation automatically. Note: `Graphonomous.retrieve_context/2` returns an unwrapped map (not `{:ok, map}`) — the Retriever follows this convention:

```elixir
# In retrieve/2, after topology is computed:
result =
  if result.topology.routing == :deliberate and opts[:auto_deliberate] do
    case Deliberator.deliberate(result.topology, query, result.results, opts) do
      {:ok, deliberation_result} ->
        Map.put(result, :deliberation, deliberation_result)
      {:escalated, _} ->
        Map.put(result, :deliberation, %{escalated: true})
      _ ->
        result
    end
  else
    result
  end
```

**Default: auto-deliberation is OFF.** The calling agent decides whether to call `deliberate` explicitly after seeing the topology. This preserves agent autonomy — the graph provides the map, the agent decides whether to drive.

### 3.4 [&] Protocol Integration

**File:** `AmpersandBoxDesign/SPEC.md` (amendment)

Add `&reason.deliberate` as a capability operation:

```
&reason.deliberate(
  budget: :κ,
  write_back: true,
  escalation: :deliberatic
)
```

Pipeline form:

```
context
  |> &memory.recall()
  |> &topology.analyze()
  |> &topology.route()
  |> &reason.deliberate(budget: :κ)
  |> &memory.store()            # crystallization
```

This makes deliberation **declarative and composable** within the [&] Protocol. An agent spec can declare that it uses κ-driven deliberation without encoding the loop mechanics.

### 3.5 Telemetry

**File:** `graphonomous/lib/graphonomous/deliberator.ex`

Emit events at each phase:

```elixir
# Deliberation started
:telemetry.execute(
  [:graphonomous, :deliberator, :start],
  %{scc_count: length(sccs_to_deliberate)},
  %{query: query, max_kappa: topology.max_kappa}
)

# Per-SCC focus pass completed
:telemetry.execute(
  [:graphonomous, :deliberator, :focus],
  %{duration_ms: duration, partition_count: length(partitions)},
  %{scc_id: scc.id, kappa: scc.kappa}
)

# Reconciliation completed
:telemetry.execute(
  [:graphonomous, :deliberator, :reconcile],
  %{duration_ms: duration, converged: converged},
  %{scc_id: scc.id, confidence: final_confidence}
)

# Crystallization (write-back)
:telemetry.execute(
  [:graphonomous, :deliberator, :crystallize],
  %{node_id: node_id},
  %{scc_id: scc.id, kappa_before: kappa, conclusion_confidence: confidence}
)

# Escalation
:telemetry.execute(
  [:graphonomous, :deliberator, :escalate],
  %{},
  %{scc_id: scc.id, reason: reason, target: :deliberatic | :agentromatic | :human}
)
```

---

## 4. The Crystallization Model (Detailed)

This section explains the "mechanized consciousness" property — how the graph self-organizes through deliberation.

### 4.1 How κ Decreases Over Time

Consider the 5-node business example SCC with κ = 1 (verified against kappa_reference.py):

```
market-share → revenue → r-and-d → product-quality → market-share
                                  ↗
              customer-retention ─┘
```

After deliberation, a conclusion node is added:

```
market-share → revenue → r-and-d → product-quality → market-share
                                  ↗
              customer-retention ─┘

              [CONCLUSION: "R&D has diminishing returns above $10M/quarter"]
                ←derived_from— market-share
                ←derived_from— r-and-d
                ←derived_from— product-quality
                ←derived_from— revenue
```

The conclusion node is NOT part of the cycle — it's a DAG leaf with incoming `:derived_from` edges. But it has:
- High confidence (0.84)
- Recent timestamp
- Content that directly answers the query

**Next time** someone asks about R&D and market share:
1. The Retriever finds the conclusion node (high similarity, high confidence)
2. The retrieved subgraph now includes the conclusion node in its node set
3. The conclusion node has no outgoing directed edges into the SCC
4. The effective topology for the retrieved context may have lower κ because the conclusion provides a "shortcut" — the agent can use the settled conclusion instead of re-traversing the full cycle

This isn't κ literally decreasing on the original SCC (that's structural), but the **effective κ of the retrieved subgraph** decreasing because the conclusion node resolves the circular dependency for that query class.

### 4.2 Conclusion Decay and Re-Deliberation

Conclusions are nodes. They participate in the normal Consolidator lifecycle:

- **Confidence decay:** Unused conclusions decay like any other node (Consolidator's idle-time decay)
- **Access reinforcement:** Conclusions that keep getting retrieved stay high-confidence
- **Contradiction:** If new evidence contradicts a conclusion, its confidence drops. When confidence drops below threshold, the Deliberator may re-run on the SCC with updated context → new conclusion replaces old one
- **Pruning:** Very old, low-confidence, unused conclusions get pruned by the Consolidator

This creates a **natural lifecycle** for deliberated knowledge:
```
uncertain (κ > 0) → deliberated → crystallized → reinforced by use
                                                → OR decayed by time
                                                → OR contradicted by evidence
                                                → re-deliberated
```

### 4.3 The Consciousness Analogy

The system exhibits properties analogous to focused attention:

| Human Cognition | Deliberator Equivalent |
|-----------------|----------------------|
| Noticing confusion | κ > 0 detected in retrieval |
| Focusing attention on the confusing part | Fault-line decomposition scopes context |
| Reasoning through assumptions | Focused passes with held-fixed assumptions |
| Reaching a conclusion | Reconciliation produces unified answer |
| Committing to memory | Crystallization writes node to graph |
| Forgetting stale conclusions | Consolidator decay + prune |
| Changing your mind | Re-deliberation when evidence contradicts |
| Knowing what you don't know | `coverage_query` + κ detection = epistemic self-modeling |

This is not sentience. It is **mechanical epistemology** — the graph knows its own structure, uses that structure to route reasoning, and updates itself based on the results.

---

## 5. Tests

### File: `test/graphonomous/deliberator_test.exs`

```
[x] decompose/1 on κ=1 SCC with one fault line → two partitions
[ ] decompose/1 on κ=2 SCC with two fault lines → up to four partitions, capped by budget
[ ] build_focused_prompt/4 includes ONLY partition nodes, not full graph
[ ] build_focused_prompt/4 includes fault-line assumption statement
[ ] reconcile/4 with agreeing intermediates → :converged
[ ] reconcile/4 with contradicting intermediates → :divergent
[ ] reconcile/4 checks confidence against budget.confidence_threshold
[ ] deliberate/4 on κ=0 topology → returns immediately (no-op)
[x] deliberate/4 on κ=1 SCC → runs focus + reconcile → converged conclusion
[x] deliberate/4 on κ=2 SCC → runs multiple partitions → converged or escalated
[ ] deliberate/4 budget.max_iterations respected (does not run forever)
[x] deliberate/4 with write_back: true → creates new node in graph
[x] deliberate/4 with write_back: false → no graph mutation
[x] crystallize/3 creates :semantic node with correct metadata
[ ] crystallize/3 creates :derived_from edges to source SCC nodes
[ ] escalation fires when budget exhausted without convergence
[ ] telemetry events emitted at each phase
[x] agent_fn injection works (mock LLM for deterministic tests)
```

### File: `test/graphonomous/deliberator_integration_test.exs`

```
[ ] End-to-end: store cyclic graph → retrieve → auto_deliberate → conclusion node exists
[x] Conclusion node has correct metadata (derived_by, source_scc, source_kappa)
[ ] Second retrieval of same region finds conclusion node
[ ] Effective κ of retrieved subgraph may be lower after crystallization
[x] MCP tool `deliberate` returns valid response matching schema
[x] MCP tool registered and callable
```

---

## 6. File Manifest

### New files to create:

| File | Language | Purpose |
|------|----------|---------|
| `graphonomous/lib/graphonomous/deliberator.ex` | Elixir | Core deliberation loop |
| `graphonomous/lib/graphonomous/mcp/deliberate.ex` | Elixir | MCP tool for explicit deliberation |
| `graphonomous/test/graphonomous/deliberator_test.exs` | Elixir | Unit tests |
| `graphonomous/test/graphonomous/deliberator_integration_test.exs` | Elixir | Integration tests |

### Files to modify:

| File | Change |
|------|--------|
| `graphonomous/lib/graphonomous/retriever.ex` | Add optional `auto_deliberate` flag |
| `graphonomous/lib/graphonomous/mcp/server.ex` | Register `Deliberate` component |

### Depends on (must exist first, from KAPPA_BUILD_PROMPT):

| File | Required Function |
|------|-------------------|
| `graphonomous/lib/graphonomous/topology.ex` | `analyze/1`, `build_adjacency/2`, `preview_edge_impact/3` |
| `graphonomous/lib/graphonomous/store.ex` | `list_edges_between/1` |
| `graphonomous/lib/graphonomous/mcp/topology_analyze.ex` | Registered MCP tool |

---

## 7. Success Criteria

### Gate A — Decomposition Correctness (MUST PASS)

1. `decompose/1` produces correct partitions for κ=1 and κ=2 SCCs
2. Partitions are disjoint and cover all SCC nodes
3. Each partition includes correct boundary context (fault-line neighbors)
4. Partition count is bounded by `budget.max_iterations`

### Gate B — Prompt Scoping (MUST PASS)

1. Focused prompts contain ONLY partition-relevant nodes
2. No context bleed between partitions
3. Fault-line assumption is clearly stated in prompt
4. Reconciliation prompt includes ALL intermediate conclusions

### Gate C — Convergence Behavior (MUST PASS)

1. Convergence check uses `budget.confidence_threshold`
2. Divergent results trigger retry (up to budget) then escalation
3. Escalation callback fires with correct reason
4. Budget is never exceeded (no infinite loops)

### Gate D — Crystallization (MUST PASS)

1. Conclusion nodes created with correct type, confidence, and metadata
2. `:derived_from` edges created to source nodes
3. Graph mutation is atomic (all-or-nothing)
4. Telemetry emitted on crystallization

### Gate E — Integration (SHOULD PASS)

1. Second retrieval of the same region finds conclusion node
2. Auto-deliberation flag works in Retriever
3. MCP tool returns valid schema-compliant response
4. Escalation to Deliberatic is wired (even if Deliberatic handler is a stub)

---

## 8. Architectural Notes

### Why inject `agent_fn` instead of hardcoding an LLM call?

Testability. The Deliberator's logic is graph decomposition + prompt construction + convergence checking. The actual LLM call is a dependency that should be injected:

- In tests: mock function returns deterministic responses
- In production: wraps the MCP client or direct API call
- In BendScript (future): wraps a browser-side LLM call

This also means the Deliberator is **model-agnostic** — it works with any LLM that accepts text prompts and returns text responses.

### Why not use Deliberatic for everything?

Deliberatic requires:
- Multiple agents submitting independent positions
- Byzantine fault tolerance overhead
- Evidence chain construction
- Constitutional constraint checking
- Moderator election

For a single agent reasoning through a 4-node cycle, this is ~50x more overhead than needed. The Deliberator is the fast path: one agent, focused prompts, write-back. Deliberatic is the escalation path when the fast path fails.

### Why write conclusions back to the graph?

Three reasons:

1. **Performance:** Avoids re-deliberating the same cycle on every query
2. **Learning:** The graph accumulates knowledge from deliberation, not just from external inputs
3. **Epistemic honesty:** The conclusion is a node with confidence and provenance. It can be questioned, contradicted, and decayed — unlike ephemeral chain-of-thought that disappears after the conversation

### How does this relate to the Consolidator?

The Consolidator already handles:
- Confidence decay (unused knowledge fades)
- Pruning (low-confidence, old, unused nodes removed)
- Merging (duplicate/near-duplicate nodes consolidated)

Deliberator conclusions participate in all of these. The Consolidator doesn't need to know about the Deliberator — it just sees nodes with metadata. The `derived_by: :deliberator` metadata is for provenance tracking, not special-case logic.

**Future (not in scope for v1):** The Consolidator could become κ-aware — preferring to prune nodes that don't break SCCs (preserving feedback loop integrity) and merging conclusion nodes that cover the same SCC.

### Thread safety

The Deliberator runs as a task under the calling process (Retriever or MCP handler). Multiple deliberations can run concurrently on different SCCs. Graph writes (crystallization) go through the Store, which handles SQLite serialization. No additional locking needed — the Store is the synchronization point.

**Concurrent deliberation on overlapping SCCs:** If two queries trigger deliberation on SCCs that share nodes, they may produce conflicting conclusion nodes. SQLite serialization prevents data corruption but not semantic conflicts. For v1, this is acceptable — the Consolidator's merge/prune cycle will eventually resolve duplicates. For v2, consider a per-SCC deliberation lock (e.g., an ETS-based advisory lock keyed by SCC node set hash) to serialize deliberation on the same region.

### Cost model

Deliberation involves LLM calls. Each focused pass and the reconciliation pass are separate LLM invocations. The cost scales with κ and SCC size:

```
Per-SCC cost estimate:
  focused_passes = min(num_fault_lines × 2, budget.max_iterations)
  reconciliation = 1
  total_llm_calls = focused_passes + reconciliation

  Per-call token estimate:
    input  ≈ partition_nodes × avg_node_content_tokens + prompt_template_tokens
    output ≈ 200-500 tokens (conclusion + confidence + reasoning)

  Example (κ=1 SCC, 5 nodes, ~200 tokens/node):
    focused_passes = 2
    reconciliation = 1
    total_calls = 3
    input_tokens_per_call ≈ 5 × 200 + 300 = 1,300
    output_tokens_per_call ≈ 400
    total_tokens ≈ 3 × 1,700 = ~5,100 tokens

  Example (κ=2 SCC, 10 nodes):
    total_calls = 5 (4 focused + 1 reconciliation)
    total_tokens ≈ 5 × 2,300 = ~11,500 tokens
```

At current API prices (~$3/M input, ~$15/M output for frontier models), a single deliberation costs $0.01-$0.05. This is acceptable for explicit `deliberate` calls but adds up fast with auto-deliberation on every retrieval. **This is why auto-deliberation is OFF by default.**

The Attention Engine (ATTENTION_ENGINE_PROMPT.md) adds budget constraints that cap deliberation frequency. The telemetry events (§3.5) should include token counts for cost tracking.

### Convergence properties

The Deliberator does not guarantee convergence. LLM responses are stochastic — focused passes on different partitions may produce irreconcilable conclusions. The convergence check (confidence ≥ threshold) is necessary but not sufficient.

**Known failure modes:**

1. **Persistent divergence:** Partitions produce contradictory conclusions that reconciliation can't resolve. Capped by `max_iterations`, then escalates.
2. **Hallucination in focused pass:** LLM invents facts not present in the partition context. Mitigated by strict prompt scoping (only partition nodes in context) and confidence calibration.
3. **Confidence inflation:** LLM reports high confidence on wrong conclusions. Mitigated by the Consolidator's eventual decay and by outcome grounding via `learn_from_outcome`.
4. **Cascading wrong conclusions:** A crystallized conclusion that's wrong gets used in future retrievals, compounding the error. Mitigated by confidence decay and re-deliberation when contradicting evidence appears.

These are inherent to LLM-based reasoning and not unique to this architecture. The Deliberator's advantage is that failures are **traceable** (provenance metadata on conclusion nodes) and **correctable** (conclusion nodes participate in normal confidence decay/contradiction cycles).

### Evaluation baseline (needed before claiming product effect)

Gate D ("Product Effect") in KAPPA_BUILD_PROMPT requires "directional improvement with logged evidence." To measure this, establish baselines BEFORE implementing the Deliberator:

1. **Assemble eval set:** 20-30 queries that touch circular knowledge regions (manually identified or auto-detected via κ > 0 on existing graph data)
2. **Baseline:** Run each query through standard `retrieve_context` (no topology, no deliberation). Record answer quality via human eval (1-5 coherence, 1-5 completeness)
3. **Treatment:** Run same queries with κ-routed deliberation. Same eval criteria.
4. **Metric:** Mean coherence improvement on circular queries. Target: ≥ 0.5 point improvement on 5-point scale.

This baseline must exist before the Deliberator is claimed to work. Telemetry alone is necessary but not sufficient — it measures that the system runs, not that it reasons better.

---

## 9. BendScript Visualization (Future — Path 2 Extension)

After Path 2 of KAPPA_BUILD_PROMPT is complete (SCC halos, κ badges), extend BendScript to visualize deliberation:

### 9.1 Deliberation Animation

When deliberation runs on a visible SCC:
1. **Partition highlight:** Each partition gets a different tint within the SCC halo
2. **Focus sweep:** During each focused pass, the active partition's nodes pulse brighter
3. **Fault-line glow:** The fault-line edge being examined pulses with a distinct color
4. **Conclusion node appearance:** New conclusion node fades in at the SCC centroid with a "crystallize" animation (expanding ring)
5. **κ badge update:** Badge value updates after crystallization

### 9.2 Deliberation HUD

Extend the HUD (from KAPPA_BUILD_PROMPT Task 2.3):

```
κ: 2 | SCCs: 1 | mode: DELIBERATING (pass 2/3, scc-0)
```

After convergence:
```
κ: 2 | SCCs: 1 | mode: CRYSTALLIZED (scc-0 → confidence: 0.84)
```

### 9.3 Manual Deliberation Trigger

Add to context menu on SCC nodes:
- **"Deliberate — Reason Through Loop"** — triggers deliberation on the containing SCC
- Shows progress in HUD
- Conclusion node appears on canvas when done

*This is documented here for context but should NOT be built until Paths 1 and 2 from KAPPA_BUILD_PROMPT are working and the Elixir Deliberator is passing all gates.*

---

*Companion to: `KAPPA_BUILD_PROMPT.md` (κ computation + visualization). This prompt builds the deliberation loop that κ triggers. Together they form the complete system: detect topology → route → deliberate → crystallize → the graph learns from its own reasoning.*

*Reference documents: `graphonomous.com/project_spec/kappa_integration_spec.md`, `graphonomous.com/project_spec/kappa_theory_applied.md`, `deliberatic.com/project_spec/README.md`, `agentromatic.com/project_spec/README.md`, `opensentience.org/project_spec/README.md`.*
