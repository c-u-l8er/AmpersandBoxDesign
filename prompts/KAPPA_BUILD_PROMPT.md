# κ-Aware Routing — Build Prompt v2 for Graphonomous + BendScript

> **Purpose:** Implementation prompt for adding the cyclicity invariant κ as the routing primitive that tells an LLM agent *when to think* vs. *when to retrieve*. Two parallel workstreams, one integration.
>
> **Target agent:** ChatGPT-5.3-Codex (or any coding agent with file access)
>
> **Author:** Travis / [&] Ampersand Box Design
>
> **Date:** 2026-03-21
>
> **Version:** 2.0 — Execution-safe. All schema drift, tool naming, and UI reality issues from v1 review resolved.

---

## v2 Changelog (what changed from v1 and why)

| Issue (from Codex review) | v1 Problem | v2 Fix |
|---|---|---|
| **Tool naming drift** | Spec said `memory_recall_with_topology`; prompt said `analyze_topology` + augment `retrieve_context` | **Resolved:** `analyze_topology` = standalone tool. `retrieve_context` = existing tool, augmented with `topology` field. No `memory_recall_with_topology`. |
| **Routing key drift** | Reference used `overall_routing`; prompt used `routing` | **Resolved:** `routing` everywhere. See §A.1 canonical schema. |
| **Approximate κ typing** | Prompt suggested `kappa: :approximate` atom | **Resolved:** `kappa` is always an integer. Large SCCs add `"approximate": true` boolean. |
| **BendScript edge-preview assumes drag-to-connect** | Prompt said "during drag-to-connect"; BendScript has no drag-to-connect | **Resolved:** Edge preview via right-click "Connect to…" context menu item. No drag-to-connect in this phase. |
| **Missing instrumentation** | No telemetry tasks | **Resolved:** Task 1.7 adds `:telemetry` events for latency + routing counters. |
| **Undirected edge ambiguity** | "bidirectional or skip — see design note" | **Resolved:** Hard rule: only `causal` + `temporal` are directed for κ. `context`/`associative`/`user` are excluded. No toggle. |

---

## 0. The One-Sentence Idea

**κ detects irreducible feedback loops in a knowledge graph. When κ = 0, the subgraph is a DAG — retrieve context in one pass. When κ > 0, the subgraph has circular dependencies — iterate/deliberate before answering.**

This is proved (1,926,351 finite systems, zero counterexamples). The proof and reference implementation live at `graphonomous.com/project_spec/kappa_reference.py`. The full theory is at `graphonomous.com/project_spec/kappa_theory_applied.md`. The product integration spec is at `graphonomous.com/project_spec/kappa_integration_spec.md`.

---

## A. Canonical Schema (READ THIS FIRST)

### A.1 The Single Source of Truth

Every κ topology result — Elixir struct, JavaScript object, MCP JSON response — MUST use these exact field names:

```json
{
  "sccs": [
    {
      "id": "scc-0",
      "nodes": ["node-a", "node-b", "node-c"],
      "kappa": 2,
      "approximate": false,
      "fault_line_edges": [
        {"source": "node-a", "target": "node-b"}
      ],
      "routing": "deliberate",
      "deliberation_budget": {
        "max_iterations": 3,
        "agent_count": 2,
        "timeout_multiplier": 2.0,
        "confidence_threshold": 0.80
      }
    }
  ],
  "dag_nodes": ["node-x", "node-y"],
  "routing": "fast",
  "max_kappa": 2,
  "scc_count": 1
}
```

### A.2 Field Name Rules

| Field | Canonical Name | NOT this | Type |
|-------|---------------|----------|------|
| Top-level routing | `routing` | ~~overall_routing~~ | `"fast"` \| `"deliberate"` |
| Per-SCC routing | `routing` | — | `"fast"` \| `"deliberate"` |
| Edge source | `source` | ~~from~~, ~~a~~ | string (node ID) |
| Edge target | `target` | ~~to~~, ~~b~~ | string (node ID) |
| Fault lines | `fault_line_edges` | ~~min_cut_edges~~ | array of `{source, target}` |
| κ value | `kappa` | — | integer (always, never atom/string) |
| Approximation flag | `approximate` | — | boolean |
| SCC identifier | `id` | — | string `"scc-N"` |
| Max κ | `max_kappa` | — | integer |
| SCC count | `scc_count` | — | integer |

### A.3 Language-Specific Conventions

**Elixir:**
```elixir
# Internal: atoms for routing values
%{routing: :fast}   # or :deliberate

# MCP JSON output: convert atoms to strings
Jason.encode!(%{routing: "fast"})
```

**JavaScript (schema boundary mapping):**
```javascript
// Local UI objects may use camelCase for ergonomics
{ routing: 'fast', maxKappa: 0, sccCount: 0, faultLineEdges: [] }

// Any MCP/network payload must use canonical snake_case keys
{ routing: 'fast', max_kappa: 0, scc_count: 0, fault_line_edges: [] }
```

### A.4 Approximation (Large SCCs)

When SCC size > 20 nodes, exact bipartition enumeration is infeasible. Return:

```json
{
  "id": "scc-0",
  "nodes": ["...25 nodes..."],
  "kappa": 25,
  "approximate": true,
  "fault_line_edges": [],
  "routing": "deliberate",
  "deliberation_budget": { "max_iterations": 4, "agent_count": 3, "timeout_multiplier": 3.5, "confidence_threshold": 0.95 }
}
```

Rules:
- `kappa` = SCC size (integer, used as upper-bound proxy)
- `approximate` = `true`
- `fault_line_edges` = empty array (can't compute without exact bipartition)
- `deliberation_budget` still computed from the `kappa` value, capped:
  - `max_iterations: min(kappa + 1, 4)`
  - `agent_count: min(kappa, 3)`
  - `timeout_multiplier: min(1.0 + 0.5 * kappa, 3.5)`
  - `confidence_threshold: min(0.7 + 0.05 * kappa, 0.95)`

---

## 1. What Exists Today

### 1.1 Graphonomous (Elixir/OTP) — `graphonomous/`

A continual learning knowledge graph engine with an MCP server. Ships as an escript binary + npm package.

**Stack:** Elixir 1.17+, OTP 27, SQLite via exqlite, Bumblebee embeddings, ETS cache, vendored `anubis_mcp` for MCP stdio transport.

**Key modules and their current state:**

| Module | File | Role | κ-Relevant State |
|--------|------|------|-------------------|
| `Store` | `lib/graphonomous/store.ex` (~1293 lines) | SQLite persistence + ETS cache | Has `list_edges_for_node/1`. Missing `list_edges_between/1`. |
| `Graph` | `lib/graphonomous/graph.ex` (~493 lines) | GenServer. Node/edge CRUD, embedding, cosine similarity, `query/1`. | Has `get_edges_for_node/1`. |
| `Retriever` | `lib/graphonomous/retriever.ex` | Similarity → BFS expansion → ranking. Returns `{results, causal_context, stats}`. | No topology field. No edge structure in response. |
| `Learner` | `lib/graphonomous/learner.ex` | Outcome → confidence updates. | No κ interaction. |
| `Consolidator` | `lib/graphonomous/consolidator.ex` | Periodic decay/prune/merge. | Future: κ-aware pruning (don't break SCCs). Not in scope for v1. |
| `MCP.Server` | `lib/graphonomous/mcp/server.ex` | Anubis.Server with 7 tool + 2 resource components. | No topology tool registered. |
| `MCP.RetrieveContext` | `lib/graphonomous/mcp/retrieve_context.ex` | MCP wrapper for Retriever. Returns `{status, query, count, results, causal_context, stats}`. | No topology in response. |

**Data types:**

```elixir
# lib/graphonomous/types/node.ex
%Node{
  id: binary(),
  content: binary(),
  node_type: :episodic | :semantic | :procedural,
  confidence: float(),
  embedding: binary(),
  metadata: map(),
  source: binary(),
  access_count: non_neg_integer(),
  created_at: DateTime.t(),
  updated_at: DateTime.t(),
  last_accessed_at: DateTime.t()
}

# lib/graphonomous/types/edge.ex
%Edge{
  id: binary(),
  source_id: binary(),
  target_id: binary(),
  edge_type: :causal | :related | :contradicts | :supports | :derived_from,
  weight: float(),
  metadata: map(),
  created_at: DateTime.t(),
  last_activated_at: DateTime.t()
}
```

**MCP tools (7 registered):**
1. `StoreNode` — persist knowledge nodes
2. `RetrieveContext` — semantic search + neighborhood expansion
3. `LearnFromOutcome` — confidence updates from grounding
4. `QueryGraph` — list/filter/similarity
5. `ManageGoal` — goal lifecycle
6. `ReviewGoal` — goal inspection
7. `RunConsolidation` — trigger decay/prune

**What does NOT exist (confirmed by codebase audit 2026-03-21):**
- No `Graphonomous.Topology` module
- No SCC decomposition (no Tarjan, no Kosaraju)
- No cycle detection
- No topological sorting
- No κ computation
- No topology annotations on retrieval results
- No routing decision based on graph structure
- No `Store.list_edges_between/1`
- No `StoreEdge` or `QueryEdges` MCP tool
- No `:telemetry` events for topology

**Retriever flow (current):**
1. `Graph.retrieve_similar(text)` → top-K by embedding cosine similarity
2. BFS expand neighbors via edges (hop decay 0.85x per level, max 1 hop default)
3. Rank by `similarity × confidence`, take limit
4. Return `%{results: [...], causal_context: [node_ids], stats: %{...}}`

**Build/test commands:**
```bash
cd graphonomous
mix deps.get
mix compile --warnings-as-errors
mix test
mix format --check-formatted
```

### 1.2 BendScript Prototype — `bendscript.com/index.html`

A ~4,068-line single-file HTML/CSS/JS canvas-based graph editor. Vanilla JavaScript, no framework.

**Graph data model (JavaScript):**

```javascript
// Node
{
  id: "uid-string",
  text: "node content (markdown)",
  type: "normal" | "stargate",
  x: 0.0, y: 0.0,
  vx: 0.0, vy: 0.0,
  fx: 0.0, fy: 0.0,
  pinned: false,
  portalPlaneId: "uid" | null,
  pulse: 0.0,
  width: 180, height: 60,
  scrollY: 0,
  createdAt: Date.now()
}

// Edge
{
  id: "uid-string",
  a: "node-id",   // source
  b: "node-id",   // target
  props: {
    label: "causes",
    kind: "context" | "causal" | "temporal" | "associative" | "user",
    strength: 1-5
  }
}

// Plane (multi-level graph)
{
  id: "uid-string",
  name: "Main",
  parentPlaneId: null | "uid",
  parentNodeId: null | "uid",
  nodes: [],
  edges: [],
  camera: { x: 0, y: 0, zoom: 1 },
  tick: 0
}
```

**Key functions in index.html:**
- `addNode(plane, text, x, y, type)` (~L1510) — creates node object
- `addEdge(plane, a, b, props)` (~L1559) — creates edge object
- `activePlane()` (~L1590) — returns current plane
- `nodeAtPoint(px, py)` (~L1755) — hit testing
- `simulate(dt)` (~L3142) — physics step
- `tick()` (~L3903) — main render loop (rAF)

**HUD (existing):** `nodes: N | edges: N | depth: N | zoom: N` — Bottom-left overlay.

**What does NOT exist (confirmed by codebase audit 2026-03-21):**
- No SCC computation
- No κ computation
- No topology visualization
- No routing indicator in HUD
- No "bend/unbend" actions
- No edge impact preview
- **No drag-to-connect edge creation** — edges are created programmatically (during merge, portal creation, clone) or via seed setup, NOT by user dragging between nodes

**Edge types recognized:** `context`, `causal`, `temporal`, `associative`, `user`

**Important data model notes:**
- BendScript edges use `a`/`b` (not `source_id`/`target_id`)
- Edges use `props.kind` (not `edge_type`)
- The κ engine must map: `edge.a` → `source`, `edge.b` → `target`, `edge.props.kind` → kind filter

### 1.3 κ Reference Implementation — `graphonomous.com/project_spec/kappa_reference.py`

Python reference code (~629 lines). Contains:
- `DirectedGraph` class
- `tarjan_scc_matrix(adj, n)` → list of SCCs
- `compute_kappa_matrix(adj, n, scc_nodes)` → `{kappa, min_cut_partition, ...}`
- `analyze_topology(graph)` → full routing analysis
- `deliberation_budget(kappa)` → `{max_iterations, agent_count, timeout_multiplier, confidence_threshold}`
- `preview_edge_impact(graph, src, dst)` → topology change preview
- Exhaustive verification functions (1,926,351 objects)

**Use this as the porting reference for both Elixir and JavaScript.**

---

## 2. What to Build

### Path 1: κ in Graphonomous (Elixir) — Agent Automation

**Goal:** When an LLM agent calls `retrieve_context` via MCP, the response includes topology annotations that tell the agent whether to think or retrieve.

#### Task 1.1: Create `Graphonomous.Topology` module

**File:** `lib/graphonomous/topology.ex`

Port the following from `kappa_reference.py` to Elixir:

1. **`tarjan_scc/1`** — Tarjan's algorithm on an adjacency map.
   - Input: `%{node_id => MapSet.new([neighbor_ids])}` (directed adjacency)
   - Output: `[MapSet.new([node_ids_in_scc]), ...]` — list of SCCs
   - Use iterative (stack-based) implementation to avoid deep recursion on large graphs

2. **`compute_kappa/2`** — κ for a single SCC.
   - Input: adjacency map, `MapSet.t()` of SCC node IDs
   - Output: `%{kappa: integer, approximate: boolean, min_cut_partition: {list, list} | nil, fault_line_edges: [{source, target}]}`
   - Enumerate bipartitions via bitmask (for SCC size ≤ 20)
   - For SCC size > 20: return `%{kappa: MapSet.size(scc), approximate: true, fault_line_edges: []}`
   - Early exit when κ = 0 found

3. **`analyze/1`** — Full topology analysis.
   - Input: list of `{source_id, target_id}` edge tuples, or adjacency map
   - Output (must match canonical schema §A.1):
     ```elixir
     %{
       sccs: [
         %{
           id: "scc-0",
           nodes: ["node-a", "node-b"],
           kappa: 2,
           approximate: false,
           fault_line_edges: [%{source: "node-a", target: "node-b"}],
           routing: :deliberate,
           deliberation_budget: %{
             max_iterations: 3,
             agent_count: 2,
             timeout_multiplier: 2.0,
             confidence_threshold: 0.80
           }
         }
       ],
       dag_nodes: ["node-x", "node-y"],
       routing: :deliberate,
       max_kappa: 2,
       scc_count: 1
     }
     ```

4. **`deliberation_budget/1`** — Map κ to inference parameters.
   - `max_iterations: min(kappa + 1, 4)` — capped at 4 for approximated SCCs
   - `agent_count: min(kappa, 3)`
   - `timeout_multiplier: min(1.0 + 0.5 * kappa, 3.5)` — capped for large approximate SCCs
   - `confidence_threshold: min(0.7 + 0.05 * kappa, 0.95)` — capped at 0.95

5. **`build_adjacency/2`** — Build adjacency using an explicit node universe.
   ```elixir
   @spec build_adjacency(node_ids :: [binary()], edges :: [Edge.t()]) :: %{binary() => MapSet.t(binary())}
   def build_adjacency(node_ids, edges) do
     node_set = MapSet.new(node_ids)

     base =
       Enum.reduce(node_ids, %{}, fn node_id, acc ->
         Map.put(acc, node_id, MapSet.new())
       end)

     Enum.reduce(edges, base, fn edge, acc ->
       cond do
         edge.source_id == edge.target_id ->
           acc

         not MapSet.member?(node_set, edge.source_id) or not MapSet.member?(node_set, edge.target_id) ->
           acc

         true ->
           Map.update(acc, edge.source_id, MapSet.new([edge.target_id]), &MapSet.put(&1, edge.target_id))
       end
     end)
   end
   ```

6. **`preview_edge_impact/3`** — Preview adding an edge.
   - Input: adjacency map, source_id, target_id
   - Output: `%{creates_new_scc: boolean, kappa_before: integer, kappa_after: integer, kappa_delta: integer, description: binary()}`

**Style:** Follow `mix format` conventions. Use `@moduledoc`, `@doc`, `@spec` on all public functions. Pattern match aggressively. Use `Enum` and `MapSet` — no mutable state.

#### Task 1.2: Wire topology into `Retriever`

**File:** `lib/graphonomous/retriever.ex`

After the existing retrieval flow (similarity search → BFS expansion → ranking), add a topology analysis step:

1. Collect all unique node IDs from the retrieval results (this is the node universe for analysis)
2. Fetch all edges between those nodes via `Store.list_edges_between(node_ids)`
3. Build adjacency map via `Topology.build_adjacency(node_ids, edges)` so isolated/sink nodes are preserved
4. Exclude self-loops (`source_id == target_id`) during adjacency construction
5. Call `Topology.analyze(adjacency)`
6. Merge the topology result into the return value

**Updated return shape:**

```elixir
%{
  query: "...",
  results: [...],              # existing — unchanged
  causal_context: [...],       # existing — unchanged
  stats: %{...},               # existing — unchanged
  topology: %{                 # NEW
    sccs: [...],
    dag_nodes: [...],
    routing: :fast | :deliberate,
    max_kappa: 0,
    scc_count: 0
  }
}
```

#### Task 1.3: Add `Store.list_edges_between/1`

**File:** `lib/graphonomous/store.ex`

Add a function that returns all edges where both `source_id` and `target_id` are in the given set of node IDs:

```elixir
@spec list_edges_between(node_ids :: [binary()]) :: {:ok, [Edge.t()]}
def list_edges_between(node_ids) when is_list(node_ids) do
  # Query SQLite: SELECT * FROM edges
  # WHERE source_id IN (?, ?, ...) AND target_id IN (?, ?, ...)
  # Use parameterized query with the node_ids list
  #
  # If ETS cache has all edges, filter from ETS instead of hitting SQLite.
end
```

#### Task 1.4: Add MCP tool `TopologyAnalyze`

**File:** `lib/graphonomous/mcp/topology_analyze.ex`

Register a new MCP tool that exposes topology analysis directly:

```json
{
  "name": "analyze_topology",
  "description": "Compute topological structure (SCCs, κ values, routing decision) for a set of nodes in the knowledge graph. Use this to determine whether a knowledge region requires iterative deliberation (κ > 0) or can be answered with simple retrieval (κ = 0).",
  "inputSchema": {
    "type": "object",
    "properties": {
      "node_ids": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Node IDs to analyze. If omitted, analyzes the full graph."
      },
      "query": {
        "type": "string",
        "description": "Optional query text. If provided, retrieves relevant nodes first, then analyzes their topology."
      }
    }
  }
}
```

**Response (must match canonical schema §A.1):**
```json
{
  "routing": "deliberate",
  "max_kappa": 2,
  "scc_count": 1,
  "sccs": [
    {
      "id": "scc-0",
      "nodes": ["market-share", "revenue", "r-and-d", "product-quality"],
      "kappa": 2,
      "approximate": false,
      "fault_line_edges": [
        {"source": "market-share", "target": "r-and-d"},
        {"source": "product-quality", "target": "revenue"}
      ],
      "routing": "deliberate",
      "deliberation_budget": {
        "max_iterations": 3,
        "agent_count": 2,
        "timeout_multiplier": 2.0,
        "confidence_threshold": 0.80
      }
    }
  ],
  "dag_nodes": ["founding-date", "ceo-name"],
  "recommendation": "This knowledge region contains 1 strongly connected component with κ=2. The concepts [market-share, revenue, r-and-d, product-quality] are mutually dependent. Deliberate on the fault lines before answering: market-share→r-and-d, product-quality→revenue."
}
```

Register the new tool in `lib/graphonomous/mcp/server.ex`:
```elixir
component(Graphonomous.MCP.TopologyAnalyze)
```

#### Task 1.5: Update `RetrieveContext` MCP tool response

**File:** `lib/graphonomous/mcp/retrieve_context.ex`

The existing `RetrieveContext` tool should include topology annotations in its response. After retrieving context, the topology data from the Retriever flows through:

```json
{
  "status": "ok",
  "query": "...",
  "count": 5,
  "results": ["...existing..."],
  "causal_context": ["...existing..."],
  "stats": {"...existing..."},
  "topology": {
    "routing": "fast",
    "max_kappa": 0,
    "scc_count": 0,
    "sccs": [],
    "dag_nodes": ["node-1", "node-2"]
  }
}
```

**This is the key integration: every retrieval call now tells the LLM agent whether to think or just answer.**

#### Task 1.6: Tests

**File:** `test/graphonomous/topology_test.exs`

Write tests for:

1. **Empty graph → κ = 0, routing = :fast**
2. **Linear chain (A→B→C) → κ = 0, routing = :fast**
3. **Simple cycle (A→B→C→A) → κ = 1, routing = :deliberate**
4. **Two independent cycles → two SCCs, each with κ > 0**
5. **Mixed DAG + cycle → DAG nodes listed separately, SCC identified**
6. **Business example from the spec:** market-share → revenue → r-and-d → product-quality → market-share, plus customer-retention loop → κ = 2
7. **Single node → κ = 0**
8. **Self-loop only → κ = 0 (self-loops excluded from adjacency)**
9. **Bipartite complete graph K₂,₂ with both directions → κ = 2**
10. **Large SCC (> 20 nodes) → returns `approximate: true`, `kappa` = SCC size**
11. **Schema compliance:** All output maps use canonical field names from §A.1
12. **`build_adjacency/2`** converts Edge structs correctly
13. **`preview_edge_impact/3`** correctly detects new SCC creation

**File:** `test/graphonomous/retriever_topology_test.exs`

Integration test:
1. Store nodes and edges forming a mixed DAG+cycle graph
2. Call `Retriever.retrieve/2`
3. Assert response includes `topology` key with correct `routing` decision
4. Assert `topology.sccs` contains expected SCC with correct `kappa`
5. Assert all field names match canonical schema

#### Task 1.7: Instrumentation (NEW in v2)

**File:** `lib/graphonomous/topology.ex` (add to existing module)

Emit **both** topology analysis telemetry and routing decision telemetry.

```elixir
defp emit_analyze_telemetry(result, duration_us, node_count, edge_count) do
  :telemetry.execute(
    [:graphonomous, :topology, :analyze],
    %{
      duration_ms: duration_us / 1000.0,
      node_count: node_count,
      edge_count: edge_count
    },
    %{
      scc_count: result.scc_count,
      max_kappa: result.max_kappa,
      routing: result.routing
    }
  )
end

defp emit_route_telemetry(result, trigger) do
  :telemetry.execute(
    [:graphonomous, :topology, :route],
    %{},
    %{
      decision: result.routing,
      max_kappa: result.max_kappa,
      trigger: trigger
    }
  )
end
```

Wrap `analyze/1` to measure and emit both events:
```elixir
def analyze(edges_or_adjacency) do
  {duration_us, result} = :timer.tc(fn -> do_analyze(edges_or_adjacency) end)
  {node_count, edge_count} = graph_size(edges_or_adjacency)
  emit_analyze_telemetry(result, duration_us, node_count, edge_count)
  emit_route_telemetry(result, :analyze_topology)
  result
end
```

**Retriever integration requirement:** after topology is computed during retrieval, emit route telemetry with `trigger: :retrieve_context` so routing counters cover both entry points.

---

### Path 2: κ Visualization in BendScript (JavaScript) — Visual Demo

**Goal:** Users build graphs on the canvas and see κ in real time — SCC clusters glow, κ badges appear, HUD shows routing mode.

**All changes go in `bendscript.com/index.html`** (the existing prototype). Do not create a new file or refactor to SvelteKit — that's Path 3.

#### Task 2.1: Port Tarjan + κ to JavaScript

Add these functions to the `<script>` section of `index.html`, grouped together with a comment banner:

```javascript
// ═══════════════════════════════════════════════════════════════
// κ TOPOLOGY ENGINE
// Canonical schema: see kappa_integration_spec.md §2.4
// ═══════════════════════════════════════════════════════════════
```

**Edge directionality rule (HARD — no toggle):**

```javascript
const DIRECTED_KINDS = ['causal', 'temporal'];
// Only edges with these kinds participate in SCC/κ computation.
// All other edge kinds are excluded entirely from the directed graph.
```

**Functions to implement:**

1. **`tarjanSCC(nodes, edges)`**
   - Input: arrays of node objects and edge objects (from `activePlane().nodes` / `.edges`)
   - Output: array of arrays (each inner array = node IDs in one SCC, only nontrivial SCCs with size > 1)
   - Filter edges: `edges.filter(e => DIRECTED_KINDS.includes(e.props?.kind))`
   - Map edge endpoints: `e.a` → source, `e.b` → target
   - Recursive implementation is fine (BendScript graphs are < 1000 nodes)

2. **`computeKappa(adjMap, sccNodeIds)`**
   - Input: adjacency Map (nodeId → Set of neighbor IDs), array of node IDs in one SCC
   - Output: `{ kappa: number, approximate: false, minCutPartition: [arrayA, arrayB] | null, faultLineEdges: [{source, target}] }`
   - Bipartition enumeration via bitmask (SCC size ≤ 20)
   - For SCC > 20: return `{ kappa: sccNodeIds.length, approximate: true, faultLineEdges: [] }`

3. **`analyzeTopology(plane)`**
   - Input: a plane object (has `.nodes` and `.edges`)
   - Output (matches canonical schema §A.1, camelCase for JS):
     ```javascript
     {
       sccs: [{ id, nodes, kappa, approximate, faultLineEdges, routing, deliberationBudget }],
       dagNodes: [...],
       routing: 'fast' | 'deliberate',
       maxKappa: number,
       sccCount: number
     }
     ```
   - **Cache:** Store result on `plane._topologyCache`. Set `plane._topologyDirty = true` in `addEdge()` and when edges are removed. Only recompute when dirty.
   - **Timing:** Log computation time via `performance.now()`: `console.debug(\`[κ] topology: ${ms}ms\`)`

4. **`previewEdgeImpact(plane, srcId, dstId)`**
   - Temporarily add the edge to a copied adjacency map, recompute topology, diff against cached result
   - Return `{ createsNewSCC: bool, kappaBefore: number, kappaAfter: number, kappaDelta: number, description: string }`
   - **Do NOT mutate the actual plane** — work on a copy of the adjacency map

#### Task 2.2: SCC Visualization on Canvas

In the existing render loop (`tick()` function, around line 3903), add SCC cluster rendering **before** node/edge drawing (so clusters appear as background regions):

1. **Cluster halos:** For each SCC with κ > 0, compute the convex bounding box of its member nodes (with 30px padding). Draw a rounded-rect background fill:
   - κ = 1: `rgba(0, 255, 200, 0.06)` (subtle cyan-green)
   - κ = 2: `rgba(0, 200, 255, 0.08)` (cyan)
   - κ ≥ 3: `rgba(180, 100, 255, 0.10)` (purple)
   - Corner radius: 16px. Use `ctx.roundRect()` or manual arc path.

2. **κ badge:** Draw a small label at the top-right corner of each SCC bounding box: `κ=2` in monospace font, 10px, white text on dark pill background (`rgba(0,0,0,0.6)` with border-radius). Use `ctx.fillText()` + manual background rect.

3. **Fault-line edge highlight:** Edges that are fault lines get a dashed stroke (`ctx.setLineDash([6, 4])`) and a brighter color (e.g., `rgba(0, 255, 200, 0.6)`) than normal edges. Reset dash after drawing: `ctx.setLineDash([])`.

4. **Pulse animation for SCC nodes:** Nodes inside an SCC with κ > 0 get a subtle pulse on their border. The `node.pulse` property already exists — modulate it: `node.pulse = Math.sin(Date.now() / 1000) * 0.3 + 0.7`. Use this to modulate border opacity or width.

#### Task 2.3: HUD Extension

The existing HUD shows: `nodes: N | edges: N | depth: N | zoom: N`

Extend it to show:
```
nodes: N | edges: N | depth: N | zoom: N | κ: N | SCCs: N | mode: RETRIEVAL
```

Or when κ > 0:
```
nodes: N | edges: N | depth: N | zoom: N | κ: 2 | SCCs: 1 | mode: DELIBERATION
```

- `κ` = max κ across all SCCs in the active plane
- `SCCs` = count of nontrivial SCCs
- `mode` = `RETRIEVAL` when all κ = 0, `DELIBERATION` when any κ > 0
- Color the mode label: green (#00ff88) for RETRIEVAL, cyan (#00ccff) for DELIBERATION

#### Task 2.4: Edge Creation via Context Menu (Topology Preview)

**Important: BendScript has NO drag-to-connect. Use the context menu instead.**

Add a **"Connect to…"** item to the existing right-click context menu on nodes. When clicked:

1. Show a submenu listing nearby nodes (within 500px world distance) as connection targets
2. For each candidate, compute `previewEdgeImpact(plane, thisNodeId, candidateId)` with `kind: 'causal'`
3. Display each candidate with its topology impact:
   - "→ NodeX (κ: 0→1 — creates feedback loop)" in cyan
   - "→ NodeY (κ: 2→2 — no change)" in gray
   - "→ NodeZ (κ: 0→0 — no change)" in gray
4. When the user clicks a candidate, call `addEdge(plane, thisNodeId, candidateId, { kind: 'causal' })`
5. Set `plane._topologyDirty = true`

**Throttling:** Compute previews lazily — only when the submenu opens, not on every right-click.

#### Task 2.5: Context Menu — Bend / Unbend

Add to the existing right-click context menu (which already has fork/merge/pin/stargate/delete):

**On DAG nodes (nodes NOT in any SCC):**
- **"Bend — Create Feedback Loop"** — When clicked, finds the nearest node that would create a cycle if connected (via `previewEdgeImpact` on nearby candidates), and adds that edge. If no cycle-creating candidate exists within 500px, show "No feedback loop possible nearby" (grayed out).

**On SCC nodes (nodes IN an SCC with κ > 0):**
- **"Unbend — Break Feedback Loop"** — When clicked, identifies the fault-line edge in this node's SCC and removes it, reducing κ. Show a confirmation: "Remove edge X→Y? This breaks the feedback loop (κ: 2→1)."

---

### Path 3: Integration (After Paths 1 & 2)

Path 3 is documented here for context but should NOT be built until Paths 1 and 2 are working.

- BendScript SvelteKit migration (see `bendscript.com/prompts/BUILD.md`)
- BendScript backend connects to Graphonomous via MCP
- κ computed server-side by Graphonomous, visualized client-side by BendScript
- Real-time κ updates when graph mutations arrive via Supabase broadcast
- `&topology.analyze` and `&topology.route` registered as [&] Protocol capabilities

---

## 3. The κ Algorithm — Detailed Reference

This section provides everything needed to implement without reading the full theory paper.

### 3.1 Tarjan's SCC Algorithm

**Input:** Directed graph as adjacency map/list.
**Output:** List of strongly connected components (each SCC = set of node IDs).

A strongly connected component is a maximal set of nodes where every node can reach every other node following directed edges.

```
function tarjan(graph):
    index = 0
    stack = []
    result = []

    for each node v:
        v.index = undefined
        v.lowlink = undefined
        v.onStack = false

    function strongconnect(v):
        v.index = index
        v.lowlink = index
        index += 1
        stack.push(v)
        v.onStack = true

        for each edge (v → w):
            if w.index is undefined:
                strongconnect(w)
                v.lowlink = min(v.lowlink, w.lowlink)
            elif w.onStack:
                v.lowlink = min(v.lowlink, w.index)

        if v.lowlink == v.index:
            component = []
            repeat:
                w = stack.pop()
                w.onStack = false
                component.push(w)
            until w == v
            result.push(component)

    for each node v:
        if v.index is undefined:
            strongconnect(v)

    return result
```

**Complexity:** O(V + E)

**Elixir note:** Use an iterative (explicit stack) version to avoid stack overflow on large graphs. Elixir's immutable data structures mean you'll pass state through function arguments or use a `Map` accumulator.

**JavaScript note:** Recursive is fine for graphs under ~1000 nodes (BendScript's typical scale).

### 3.2 κ Computation

**Input:** Adjacency data + list of node IDs forming one SCC.
**Output:** κ value (integer ≥ 0) + minimum-cut partition + fault-line edges.

```
function compute_kappa(adjacency, scc_node_ids):
    n = len(scc_node_ids)
    if n <= 1: return { kappa: 0, approximate: false }
    if n > 20: return { kappa: n, approximate: true, faultLineEdges: [] }

    min_kappa = infinity
    best_partition = null

    # Enumerate all nontrivial bipartitions via bitmask
    for mask in 1 to (2^n - 2):
        A = [scc_node_ids[i] for i where bit i of mask is set]
        B = [scc_node_ids[i] for i where bit i of mask is unset]

        edges_A_to_B = count edges from any node in A to any node in B
        edges_B_to_A = count edges from any node in B to any node in A
        cut = min(edges_A_to_B, edges_B_to_A)

        if cut < min_kappa:
            min_kappa = cut
            best_partition = (A, B)
            if min_kappa == 0: break  # can't go lower

    # Identify fault-line edges (edges in the minimum-direction crossing)
    fault_lines = edges in the direction with fewer crossings

    return { kappa: min_kappa, approximate: false, partition: best_partition, faultLineEdges: fault_lines }
```

**Complexity:** O(2^n × n²) where n = SCC size. Practical for n ≤ 20.

**Optimization (both languages):** Use bitwise operations for the mask loop. Pre-compute edge presence in a matrix/map for O(1) lookup during bipartition evaluation.

### 3.3 Deliberation Budget

```
function deliberation_budget(kappa):
    return {
        max_iterations: min(kappa + 1, 4),
        agent_count: min(kappa, 3),
        timeout_multiplier: min(1.0 + 0.5 * kappa, 3.5),
        confidence_threshold: min(0.7 + 0.05 * kappa, 0.95)
    }
```

This is an engineering heuristic, not proved. Tune empirically. The `min()` caps prevent runaway values on approximated large SCCs.

### 3.4 Routing Decision

```
function route(topology_result):
    if topology_result.max_kappa == 0:
        return "fast"
    else:
        return "deliberate"
```

---

## 4. Testing Checklist

### Elixir (Path 1)

```
[ ] tarjan_scc on empty graph → []
[ ] tarjan_scc on linear chain → all trivial SCCs (size 1)
[ ] tarjan_scc on simple cycle → one SCC with all cycle nodes
[ ] tarjan_scc on disconnected graph → separate SCCs
[ ] compute_kappa on trivial SCC → 0
[ ] compute_kappa on simple 3-cycle → 1
[ ] compute_kappa on business example (4-node cycle + cross-edge) → 2
[ ] analyze on mixed DAG+SCC graph → correct routing, dag_nodes, sccs
[ ] analyze output uses canonical field names (§A.1)
[ ] approximate: false for SCC ≤ 20
[ ] approximate: true + kappa = SCC size for SCC > 20
[ ] build_adjacency correctly maps Edge structs
[ ] preview_edge_impact detects new SCC creation
[ ] Retriever returns topology key in results
[ ] MCP tool analyze_topology returns valid JSON matching §A.1
[ ] MCP tool retrieve_context includes topology field
[ ] :telemetry events emitted from analyze/1
[ ] mix test passes
[ ] mix format --check-formatted passes
[ ] mix compile --warnings-as-errors passes
```

### JavaScript (Path 2)

```
[ ] tarjanSCC on simple cycle → correct SCC
[ ] computeKappa on 3-cycle → kappa: 1, approximate: false
[ ] computeKappa on > 20 node SCC → approximate: true
[ ] analyzeTopology on active plane → correct routing
[ ] analyzeTopology uses internal camelCase, plus explicit mapper to canonical snake_case for any network/persisted payload
[ ] SCC clusters render as background halos
[ ] κ badges appear on SCC clusters
[ ] Fault-line edges render dashed
[ ] HUD shows κ, SCC count, routing mode
[ ] "Connect to…" context menu shows topology preview
[ ] Bend context menu creates feedback loop
[ ] Unbend context menu breaks feedback loop
[ ] performance.now() logging shows < 50ms on 100-node graph
[ ] No visual regression on existing graph rendering
[ ] Topology cache invalidated on edge add/remove
[ ] DIRECTED_KINDS filter only includes causal + temporal
```

---

## 5. File Manifest

### New files to create:

| File | Language | Purpose |
|------|----------|---------|
| `graphonomous/lib/graphonomous/topology.ex` | Elixir | SCC + κ computation + telemetry |
| `graphonomous/lib/graphonomous/mcp/topology_analyze.ex` | Elixir | MCP tool for topology |
| `graphonomous/test/graphonomous/topology_test.exs` | Elixir | Unit tests |
| `graphonomous/test/graphonomous/retriever_topology_test.exs` | Elixir | Integration tests |

### Files to modify:

| File | Change |
|------|--------|
| `graphonomous/lib/graphonomous/retriever.ex` | Add topology analysis after retrieval |
| `graphonomous/lib/graphonomous/store.ex` | Add `list_edges_between/1` |
| `graphonomous/lib/graphonomous/mcp/server.ex` | Register `TopologyAnalyze` component |
| `graphonomous/lib/graphonomous/mcp/retrieve_context.ex` | Include topology in response |
| `bendscript.com/index.html` | Add κ engine, SCC visualization, HUD, context menu |

### Reference files (read-only, do not modify):

| File | Purpose |
|------|---------|
| `graphonomous.com/project_spec/kappa_reference.py` | Python reference implementation |
| `graphonomous.com/project_spec/kappa_theory_applied.md` | Theoretical foundations |
| `graphonomous.com/project_spec/kappa_integration_spec.md` | Product integration spec (v0.2.0 — canonical schema) |
| `graphonomous.com/project_spec/kappa_product_crosswalk.md` | Per-product mapping |

---

## 6. Success Criteria

### Gate A — Algorithm Correctness (MUST PASS)

1. Elixir SCC outputs match Python reference on shared fixtures
2. κ values match Python reference for all nontrivial SCC fixtures up to size 10
3. Self-loop behavior: self-loop-only → κ = 0
4. All output maps use canonical field names from §A.1

**Pass threshold:** 100% fixture parity.

### Gate B — Contract Correctness (MUST PASS)

1. `retrieve_context` MCP includes `topology` with stable schema matching §A.1
2. `analyze_topology` MCP tool schema and output are deterministic
3. Field naming consistency at boundaries: canonical snake_case (`routing`, `max_kappa`, `scc_count`, `fault_line_edges`, `approximate`) is enforced for MCP JSON; JS may use camelCase internally with a deterministic mapper

**Pass threshold:** Zero schema drift in contract tests.

### Gate C — Performance & UX (MUST PASS)

1. Graphonomous topology overhead:
   - p50 < 10ms
   - p95 < 25ms
   on typical retrieved subgraphs (< 50 nodes)
2. BendScript recompute time:
   - < 50ms at 100 nodes
3. Visual:
   - SCC halo, κ badge, mode toggle all update correctly after edge mutations

**Pass threshold:** All three met. Measured via `:telemetry` (Elixir) and `performance.now()` (JS).

### Gate D — Product Effect (SHOULD PASS)

1. Deliberation calls only when κ > 0
2. Reduced unnecessary deliberation on DAG-only queries
3. Better coherence on circular-topic eval set

**Pass threshold (v1):** Directional improvement with logged evidence.

---

## 7. Architectural Notes

### Why κ and not just "detect cycles"?

A simple cycle detector (DFS back-edge check) tells you *whether* cycles exist. κ tells you *how entangled* they are. A graph with κ = 1 has one irreducible feedback loop — one extra reasoning pass probably suffices. A graph with κ = 3 has three independent feedback paths — the agent needs more iterations and possibly parallel reasoning threads. The magnitude matters for budgeting inference compute.

### Why Tarjan and not Kosaraju?

Tarjan's runs in a single DFS pass. Kosaraju's requires two passes (one on G, one on G^T). For real-time computation on every query, the constant factor matters. Both are O(V+E).

### Why bipartition enumeration and not min-cut algorithms?

For small SCCs (≤ 20 nodes, which covers ~99% of real knowledge graph clusters), exhaustive bipartition is simpler to implement and verify. The exponential blowup only matters for large SCCs, which are rare in practice. For those, we fall back to SCC size as a proxy — good enough for routing decisions.

### Directed vs. undirected edges in BendScript

BendScript's data model stores edges as `{a, b}` pairs with a `kind`. For κ computation, **only `causal` and `temporal` edges are used** (see §A and Task 2.1). All other edge kinds are excluded. This is a hard design decision, not configurable:

- `causal` edges: directed (a → b = cause → effect)
- `temporal` edges: directed (a → b = before → after)
- `context`, `associative`, `user`: **excluded** from κ graph — symmetric relationships don't create feedback loops

### Performance budget

- **Graphonomous:** Topology adds to every `retrieve_context` call. Target: < 10ms for < 50 nodes. SCC is O(V+E) ≈ microseconds. κ bipartition is the bottleneck — but only runs on nontrivial SCCs, which are rare and small.
- **BendScript:** Topology recomputed only when `_topologyDirty` flag is set. Target: < 50ms for ≤ 100 nodes. Cache on `plane._topologyCache`.

### Tool naming rationale

- `analyze_topology` = standalone MCP tool for explicit topology queries
- `retrieve_context` = existing tool, augmented with `topology` field in response
- No `memory_recall_with_topology` — that would be a redundant parallel endpoint. The existing `retrieve_context` already does retrieval; adding topology to its response is cleaner than creating a second retrieval tool.

---

*Reference documents: `graphonomous.com/project_spec/kappa_reference.py`, `graphonomous.com/project_spec/kappa_theory_applied.md`, `graphonomous.com/project_spec/kappa_integration_spec.md` (v0.2.0), `graphonomous.com/project_spec/kappa_product_crosswalk.md`. Graphonomous spec: `graphonomous.com/project_spec/README.md`. BendScript prototype: `bendscript.com/index.html`. BendScript build plan: `bendscript.com/prompts/BUILD.md`.*
