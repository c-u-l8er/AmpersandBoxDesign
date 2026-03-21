# κ-Aware Routing — Build Prompt for Graphonomous + BendScript

> **Purpose:** Implementation prompt for adding the cyclicity invariant κ as the routing primitive that tells an LLM agent *when to think* vs. *when to retrieve*. Two parallel workstreams, one integration.
>
> **Target agent:** ChatGPT-5.3-Codex (or any coding agent with file access)
>
> **Author:** Travis / [&] Ampersand Box Design
>
> **Date:** 2026-03-21

---

## 0. The One-Sentence Idea

**κ detects irreducible feedback loops in a knowledge graph. When κ = 0, the subgraph is a DAG — retrieve context in one pass. When κ > 0, the subgraph has circular dependencies — iterate/deliberate before answering.**

This is proved (1,926,351 finite systems, zero counterexamples). The proof and reference implementation live at `graphonomous.com/project_spec/kappa_reference.py`. The full theory is at `graphonomous.com/project_spec/kappa_theory_applied.md`. The product integration spec is at `graphonomous.com/project_spec/kappa_integration_spec.md`.

---

## 1. What Exists Today

### 1.1 Graphonomous (Elixir/OTP) — `graphonomous/`

A continual learning knowledge graph engine with an MCP server. Ships as an escript binary + npm package.

**Stack:** Elixir 1.17+, OTP 27, SQLite via exqlite, Bumblebee embeddings, ETS cache, vendored `anubis_mcp` for MCP stdio transport.

**Key modules and their roles:**

| Module | File | Role |
|--------|------|------|
| `Store` | `lib/graphonomous/store.ex` (1293 lines) | SQLite persistence + ETS cache. DDL for `nodes`, `edges`, `outcomes`, `goals` tables. Dual-write pattern. |
| `Graph` | `lib/graphonomous/graph.ex` (493 lines) | GenServer. Node/edge CRUD, embedding generation, cosine similarity search, polymorphic `query/1`. |
| `Retriever` | `lib/graphonomous/retriever.ex` | Semantic similarity → BFS neighborhood expansion → confidence-weighted ranking. Returns `{results, causal_context, stats}`. |
| `Learner` | `lib/graphonomous/learner.ex` | Outcome → confidence updates on causal parent nodes. |
| `Consolidator` | `lib/graphonomous/consolidator.ex` | Periodic decay/prune/merge (sleep-cycle inspired). |
| `GoalGraph` | `lib/graphonomous/goal_graph.ex` | Durable intent nodes with status, priority, parent-child hierarchy. |
| `Embedder` | `lib/graphonomous/embedder.ex` | Bumblebee sentence-transformers, ONNX models. |
| `MCP.Server` | `lib/graphonomous/mcp/server.ex` | Anubis.Server with 7 tool components + 2 resource components. |

**Data types:**

```elixir
# lib/graphonomous/types/node.ex
@type node_type :: :episodic | :semantic | :procedural

%Node{
  id: binary(),
  content: binary(),
  node_type: node_type(),       # default :semantic
  confidence: float(),           # default 0.5, clamped 0-1
  embedding: binary(),           # f32 little-endian blob
  metadata: map(),
  source: binary(),
  access_count: non_neg_integer(),
  created_at: DateTime.t(),
  updated_at: DateTime.t(),
  last_accessed_at: DateTime.t()
}

# lib/graphonomous/types/edge.ex
@type edge_type :: :causal | :related | :contradicts | :supports | :derived_from

%Edge{
  id: binary(),
  source_id: binary(),
  target_id: binary(),
  edge_type: edge_type(),       # default :related
  weight: float(),               # default 0.5, clamped 0-1
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

**What does NOT exist:**
- No SCC decomposition (no Tarjan, no Kosaraju)
- No cycle detection
- No topological sorting
- No κ computation
- No topology annotations on retrieval results
- No routing decision based on graph structure

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

A 4,068-line single-file HTML/CSS/JS canvas-based graph editor. Vanilla JavaScript, no framework.

**Graph data model (JavaScript):**

```javascript
// Node
{
  id: "uid-string",
  text: "node content (markdown)",
  type: "normal" | "stargate",
  x: 0.0, y: 0.0,             // world coordinates
  vx: 0.0, vy: 0.0,           // velocity (physics)
  fx: 0.0, fy: 0.0,           // force accumulator
  pinned: false,
  portalPlaneId: "uid" | null, // for stargates
  pulse: 0.0,                  // animation state
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

// Plane (multi-level graph — Stargates open into sub-planes)
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

**Key functions in index.html (by line):**
- `seedState()` (~L1375) — initial graph with seed nodes
- `addNode(plane, text, x, y, type)` (~L1510) — creates node object
- `addEdge(plane, a, b, props)` (~L1559) — creates edge object
- `activePlane()` (~L1590) — returns current plane
- `projectToScreen(wx, wy)` (~L1707) — world → screen coords
- `screenToWorld(sx, sy)` (~L1714) — screen → world coords
- `nodeAtPoint(px, py)` (~L1755) — hit testing
- `edgeAtPoint(px, py)` (~L1827) — edge hit testing
- `saveState()` (~L1880) — serialize to localStorage
- `loadState()` (~L1909) — deserialize from localStorage
- `simulate(dt)` (~L3142) — physics step (repulsion/spring/damping)
- `tick()` (~L3903) — main render loop (rAF)

**Physics constants:**
```javascript
REPEL = 8200    // node-node repulsion
SPRING = 0.018  // edge spring constant
DAMPING = 0.74  // velocity damping
REST = 210      // rest length
```

**HUD (existing):** Displays node count, edge count, depth (plane nesting level), zoom level. Bottom-left overlay.

**What does NOT exist:**
- No SCC computation
- No κ computation
- No topology visualization (no cluster halos, no κ badges)
- No routing indicator in HUD
- No "bend/unbend" actions
- No edge impact preview

**Edge types recognized:** `context`, `causal`, `temporal`, `associative`, `user`

**Important:** BendScript edges have a `kind` property, not `edge_type`. And edges use `a`/`b` (not `source_id`/`target_id`). These are undirected in the data model but `causal` and `temporal` edges are semantically directed (a → b = cause → effect, before → after).

### 1.3 κ Reference Implementation — `graphonomous.com/project_spec/kappa_reference.py`

Python reference code (629 lines). Contains:
- `DirectedGraph` class
- `tarjan_scc_matrix(adj, n)` → list of SCCs
- `compute_kappa_matrix(adj, n, scc_nodes)` → `{kappa, min_cut_partition, ...}`
- `analyze_topology(graph)` → full routing analysis
- `deliberation_budget(kappa)` → `{max_iterations, agent_count, timeout_multiplier, confidence_threshold}`
- `preview_edge_impact(graph, src, dst)` → topology change preview
- Exhaustive verification functions (1,926,351 objects)

**Algorithm summary:**

```
1. Run Tarjan's SCC on the directed graph → O(V+E)
2. For each nontrivial SCC (size > 1):
   a. Enumerate all bipartitions (A, B) of the SCC
   b. For each bipartition, compute:
      - edges_A_to_B = count of edges from A to B
      - edges_B_to_A = count of edges from B to A
      - bidirectional_cut = min(edges_A_to_B, edges_B_to_A)
   c. κ = minimum bidirectional_cut across all bipartitions
3. κ = 0 → DAG (no cycles) → fast retrieval
   κ > 0 → has irreducible feedback → needs deliberation
```

**Complexity:** SCC is O(V+E). κ per SCC is O(2^|SCC| × |SCC|²) worst case. Practical for SCCs ≤ 20 nodes. For larger SCCs, approximate using SCC size as proxy.

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
   - Output: `%{kappa: integer, min_cut_partition: {list, list} | nil, fault_line_edges: [{src, dst}]}`
   - Enumerate bipartitions via bitmask (for SCC size ≤ 20)
   - For SCC size > 20: return `%{kappa: :approximate, estimate: scc_size, ...}` (use SCC size as proxy)
   - Early exit when κ = 0 found

3. **`analyze/1`** — Full topology analysis.
   - Input: `Graphonomous.DirectedGraph.t()` or list of `{source_id, target_id}` edge tuples
   - Output:
     ```elixir
     %{
       sccs: [
         %{
           id: "scc-0",
           nodes: ["node-a", "node-b", ...],
           kappa: 2,
           fault_line_edges: [{"node-a", "node-b"}],
           routing: :deliberate,  # or :retrieve
           deliberation_budget: %{
             max_iterations: 3,
             agent_count: 2,
             timeout_multiplier: 2.0,
             confidence_threshold: 0.80
           }
         }
       ],
       dag_nodes: ["node-x", "node-y"],
       routing: :fast | :deliberate,
       max_kappa: 2,
       scc_count: 1
     }
     ```

4. **`deliberation_budget/1`** — Map κ to inference parameters.
   - `max_iterations: kappa + 1`
   - `agent_count: min(kappa, 3)`
   - `timeout_multiplier: 1.0 + 0.5 * kappa`
   - `confidence_threshold: 0.7 + 0.05 * kappa`

**Style:** Follow `mix format` conventions. Use `@moduledoc`, `@doc`, `@spec` on public functions. Pattern match aggressively. Use `Enum` and `MapSet` — no mutable state.

**Helper:** You'll need to build the directed adjacency map from the edges in the store. Add a helper:

```elixir
@spec build_adjacency(edges :: [Edge.t()]) :: %{binary() => MapSet.t(binary())}
def build_adjacency(edges) do
  Enum.reduce(edges, %{}, fn edge, acc ->
    Map.update(acc, edge.source_id, MapSet.new([edge.target_id]), &MapSet.put(&1, edge.target_id))
  end)
end
```

#### Task 1.2: Wire topology into `Retriever`

**File:** `lib/graphonomous/retriever.ex`

After the existing retrieval flow (similarity search → BFS expansion → ranking), add a topology analysis step:

1. Collect all unique node IDs from the retrieval results
2. Fetch all edges between those nodes from `Store` (you may need `Store.list_edges_between(node_ids)` — add it if it doesn't exist)
3. Build adjacency map from those edges
4. Call `Topology.analyze/1`
5. Merge the topology result into the return value

**Updated return shape:**

```elixir
%{
  query: "...",
  results: [...],              # existing
  causal_context: [...],       # existing
  stats: %{...},               # existing
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
@spec list_edges_between(node_ids :: [binary()]) :: [Edge.t()]
def list_edges_between(node_ids) when is_list(node_ids) do
  # Query SQLite: SELECT * FROM edges
  # WHERE source_id IN (?, ?, ...) AND target_id IN (?, ?, ...)
  # Use parameterized query with the node_ids list
end
```

If the ETS cache has all edges loaded, filter from ETS instead of hitting SQLite.

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

**Response shape:**
```json
{
  "routing": "fast",
  "max_kappa": 0,
  "scc_count": 0,
  "sccs": [],
  "dag_nodes": ["node-1", "node-2"],
  "recommendation": "This knowledge region is a DAG. Single-pass retrieval is sufficient."
}
```

Or when κ > 0:
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
      "fault_line_edges": [["market-share", "r-and-d"], ["product-quality", "revenue"]],
      "deliberation_budget": {
        "max_iterations": 3,
        "agent_count": 2,
        "confidence_threshold": 0.80
      }
    }
  ],
  "dag_nodes": ["founding-date", "ceo-name"],
  "recommendation": "This knowledge region contains 1 strongly connected component with κ=2. The concepts [market-share, revenue, r-and-d, product-quality] are mutually dependent. Deliberate on the fault lines before answering: market-share↔r-and-d, product-quality↔revenue."
}
```

Register the new tool in `lib/graphonomous/mcp/server.ex`:
```elixir
component(Graphonomous.MCP.TopologyAnalyze)
```

#### Task 1.5: Update `RetrieveContext` MCP tool response

**File:** `lib/graphonomous/mcp/retrieve_context.ex`

The existing `RetrieveContext` tool should include topology annotations in its response. After retrieving context, run topology analysis on the retrieved nodes and append:

```json
{
  "context": { ... },
  "topology": {
    "routing": "fast" | "deliberate",
    "max_kappa": 0,
    "scc_count": 0,
    "sccs": [...]
  }
}
```

This is the key integration: **every retrieval call now tells the LLM agent whether to think or just answer.**

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
8. **Self-loop only → κ = 0 (self-loops don't count)**
9. **Bipartite complete graph K₂,₂ with both directions → κ = 2**
10. **Large SCC (> 20 nodes) → returns approximate result**

**File:** `test/graphonomous/retriever_topology_test.exs`

Integration test:
1. Store nodes and edges forming a mixed DAG+cycle graph
2. Call `Retriever.retrieve/2`
3. Assert response includes `topology` key with correct routing decision

---

### Path 2: κ Visualization in BendScript (JavaScript) — Visual Demo

**Goal:** Users build graphs on the canvas and see κ in real time — SCC clusters glow, κ badges appear, HUD shows routing mode.

**All changes go in `bendscript.com/index.html`** (the existing prototype). Do not create a new file or refactor to SvelteKit — that's Path 3.

#### Task 2.1: Port Tarjan + κ to JavaScript

Add these functions to the `<script>` section of `index.html`, grouped together with a comment banner:

```javascript
// ═══════════════════════════════════════════════════════════════
// κ TOPOLOGY ENGINE
// ═══════════════════════════════════════════════════════════════
```

**Functions to implement:**

1. **`tarjanSCC(nodes, edges)`**
   - Input: arrays of node objects and edge objects (from `activePlane().nodes` / `.edges`)
   - Output: array of arrays (each inner array = node IDs in one SCC)
   - Only consider edges with `kind === 'causal'` or `kind === 'temporal'` as directed. `context`, `associative`, and `user` edges are undirected (treat as bidirectional for SCC purposes, or skip — see design note below).
   - **Design decision:** For κ routing, only `causal` and `temporal` edges create meaningful directed dependencies. `context` and `associative` edges are symmetric and don't create feedback loops. Implement this as a configurable filter: `const DIRECTED_KINDS = ['causal', 'temporal'];`

2. **`computeKappa(nodes, edges, sccNodeIds)`**
   - Input: full graph arrays + array of node IDs in one SCC
   - Output: `{ kappa: number, minCutPartition: [arrayA, arrayB] | null, faultLineEdges: [{a, b}] }`
   - Bipartition enumeration via bitmask (SCC size ≤ 20)
   - For SCC > 20: return `{ kappa: -1, approximate: true, estimate: sccNodeIds.length }`

3. **`analyzeTopology(plane)`**
   - Input: a plane object (has `.nodes` and `.edges`)
   - Output:
     ```javascript
     {
       sccs: [{ id, nodeIds, kappa, faultLineEdges, routing }],
       dagNodeIds: [...],
       routing: 'fast' | 'deliberate',
       maxKappa: number,
       sccCount: number
     }
     ```
   - Cache result per plane. Invalidate when edges are added/removed (set a dirty flag in `addEdge` and `removeEdge`).

4. **`previewEdgeImpact(plane, srcId, dstId)`**
   - Temporarily add the edge, recompute topology, diff against cached result
   - Return `{ createsNewSCC, kappaBefore, kappaAfter, description: string }`

#### Task 2.2: SCC Visualization on Canvas

In the existing render loop (`tick()` function, around line 3903), add SCC cluster rendering **before** node/edge drawing (so clusters appear as background regions):

1. **Cluster halos:** For each SCC with κ > 0, compute the bounding box of its member nodes (with padding). Draw a rounded-rect background fill with a translucent color:
   - κ = 1: `rgba(0, 255, 200, 0.06)` (subtle cyan-green)
   - κ = 2: `rgba(0, 200, 255, 0.08)` (cyan)
   - κ ≥ 3: `rgba(180, 100, 255, 0.10)` (purple)
   - Use the existing design system's dark aesthetic. These should be subtle, not garish.

2. **κ badge:** Draw a small label at the top-right corner of each SCC bounding box: `κ=2` in monospace font, `10px`, white text on a dark pill background (`rgba(0,0,0,0.6)` with `border-radius`). Use `ctx.roundRect` or manual path.

3. **Fault-line edge highlight:** Edges that are fault lines (part of the minimum cut) get a dashed stroke style (`ctx.setLineDash([6, 4])`) and a brighter color than normal edges.

4. **Pulse animation for SCC nodes:** Nodes inside an SCC with κ > 0 get a subtle pulse on their border (the `node.pulse` property already exists — modulate it based on SCC membership). Use `Math.sin(Date.now() / 1000) * 0.3 + 0.7` for a gentle throb.

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
- Color the mode label: green for RETRIEVAL, cyan for DELIBERATION

#### Task 2.4: Edge Creation Preview (Topology Impact)

When the user is dragging to create a new edge (the drag-to-connect interaction), show a tooltip near the cursor with the topology impact:

- "κ: 0 → 0 (no change)" — gray text
- "κ: 0 → 1 — creates feedback loop!" — cyan text, slightly larger
- "κ: 1 → 2 — strengthens feedback" — brighter cyan

This uses `previewEdgeImpact()` computed on mousemove during edge creation. Throttle to every 200ms to avoid performance issues.

#### Task 2.5: Context Menu — Bend / Unbend

Add to the existing right-click context menu (which already has fork/merge/pin/stargate/delete):

**On DAG nodes (nodes NOT in any SCC):**
- **"Bend — Create Feedback Loop"** — When clicked, finds the nearest node that would create a cycle if connected, and adds that edge. Uses `previewEdgeImpact` to find the best candidate among nearby nodes.

**On SCC nodes (nodes IN an SCC with κ > 0):**
- **"Unbend — Break Feedback Loop"** — When clicked, identifies the fault-line edge (minimum cut) in this node's SCC and removes it, reducing κ. Confirm with a small tooltip: "Remove edge X→Y? This breaks the feedback loop."

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

**JavaScript note:** Recursive is fine for graphs under ~1000 nodes (BendScript's typical scale). If you hit stack limits, convert to iterative.

### 3.2 κ Computation

**Input:** Adjacency data + list of node IDs forming one SCC.
**Output:** κ value (integer ≥ 0) + minimum-cut partition + fault-line edges.

```
function compute_kappa(adjacency, scc_node_ids):
    n = len(scc_node_ids)
    if n <= 1: return { kappa: 0 }

    min_kappa = infinity
    best_partition = null

    # Enumerate all nontrivial bipartitions via bitmask
    for mask in 1 to (2^n - 2):  # skip 0 (empty A) and 2^n-1 (empty B)
        A = [scc_node_ids[i] for i where bit i of mask is set]
        B = [scc_node_ids[i] for i where bit i of mask is unset]

        edges_A_to_B = count edges from any node in A to any node in B
        edges_B_to_A = count edges from any node in B to any node in A
        cut = min(edges_A_to_B, edges_B_to_A)

        if cut < min_kappa:
            min_kappa = cut
            best_partition = (A, B)
            if min_kappa == 0: break  # can't go lower

    # Identify fault-line edges (edges on the minimum-cut side)
    fault_lines = edges in the direction with fewer crossings

    return { kappa: min_kappa, partition: best_partition, fault_lines: fault_lines }
```

**Complexity:** O(2^n × n²) where n = SCC size. Practical for n ≤ 20.

**Optimization (both languages):** Use bitwise operations for the mask loop. Pre-compute edge counts in a matrix for O(1) lookup during bipartition evaluation.

### 3.3 Deliberation Budget

```
function deliberation_budget(kappa):
    return {
        max_iterations: kappa + 1,
        agent_count: min(kappa, 3),
        timeout_multiplier: 1.0 + 0.5 * kappa,
        confidence_threshold: 0.7 + 0.05 * kappa
    }
```

This is an engineering heuristic, not proved. Tune empirically.

### 3.4 Routing Decision

```
function route(topology_result):
    if topology_result.max_kappa == 0:
        return "fast"     # all DAG — single-pass retrieval sufficient
    else:
        return "deliberate"  # has SCCs — iterate on feedback loops
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
[ ] Retriever returns topology key in results
[ ] MCP tool analyze_topology returns valid JSON
[ ] MCP tool retrieve_context includes topology annotations
[ ] mix test passes
[ ] mix format --check-formatted passes
[ ] mix compile --warnings-as-errors passes
```

### JavaScript (Path 2)

```
[ ] tarjanSCC on simple cycle → correct SCC
[ ] computeKappa on 3-cycle → 1
[ ] analyzeTopology on active plane → correct routing
[ ] SCC clusters render as background halos
[ ] κ badges appear on SCC clusters
[ ] Fault-line edges render dashed
[ ] HUD shows κ, SCC count, routing mode
[ ] Edge creation preview shows κ impact
[ ] Bend context menu creates feedback loop
[ ] Unbend context menu breaks feedback loop
[ ] Performance: topology computation < 50ms on 100-node graph
[ ] No visual regression on existing graph rendering
```

---

## 5. File Manifest

### New files to create:

| File | Language | Purpose |
|------|----------|---------|
| `graphonomous/lib/graphonomous/topology.ex` | Elixir | SCC + κ computation |
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
| `bendscript.com/index.html` | Add κ engine, SCC visualization, HUD, context menu, edge preview |

### Reference files (read-only, do not modify):

| File | Purpose |
|------|---------|
| `graphonomous.com/project_spec/kappa_reference.py` | Python reference implementation |
| `graphonomous.com/project_spec/kappa_theory_applied.md` | Theoretical foundations |
| `graphonomous.com/project_spec/kappa_integration_spec.md` | Product integration spec |
| `graphonomous.com/project_spec/kappa_product_crosswalk.md` | Per-product mapping |

---

## 6. Success Criteria

**Path 1 is done when:**
- An LLM agent calls `retrieve_context` via MCP and receives `topology.routing = "deliberate"` for knowledge regions with circular dependencies
- The agent can use this signal to decide whether to reason step-by-step or answer directly
- All Elixir tests pass, code compiles without warnings, formatted

**Path 2 is done when:**
- A user builds a graph with causal feedback loops and sees the SCC highlighted with a colored halo and κ badge
- The HUD shows `mode: DELIBERATION` when feedback loops exist
- Edge creation previews the topological impact
- Bend/unbend context menu actions work

**The "when to think" demo is complete when:**
- A user builds a knowledge graph in BendScript with some DAG regions and some cyclic regions
- They can visually see which regions are "retrieval" vs "deliberation"
- An LLM agent connected to Graphonomous via MCP automatically receives topology annotations on every retrieval call
- The agent's behavior changes based on whether κ = 0 or κ > 0 — answering directly for simple topics, reasoning iteratively for mutually dependent topics

---

## 7. Architectural Notes

### Why κ and not just "detect cycles"?

A simple cycle detector (DFS back-edge check) tells you *whether* cycles exist. κ tells you *how entangled* they are. A graph with κ = 1 has one irreducible feedback loop — one extra reasoning pass probably suffices. A graph with κ = 3 has three independent feedback paths that can't be decomposed — the agent needs more iterations and possibly parallel reasoning threads. The magnitude matters for budgeting inference compute.

### Why Tarjan and not Kosaraju?

Tarjan's runs in a single DFS pass. Kosaraju's requires two passes (one on G, one on G^T). For real-time computation on every query, the constant factor matters. Both are O(V+E).

### Why bipartition enumeration and not min-cut algorithms?

For small SCCs (≤ 20 nodes, which covers ~99% of real knowledge graph clusters), exhaustive bipartition is simpler to implement and verify. The exponential blowup only matters for large SCCs, which are rare in practice. For those, we fall back to SCC size as a proxy — good enough for routing decisions.

### Directed vs. undirected edges in BendScript

BendScript's data model stores edges as `{a, b}` pairs with a `kind`. For κ computation:
- `causal` edges: directed (a → b)
- `temporal` edges: directed (a → b means "before")
- `context`, `associative`, `user`: treated as undirected (both directions) or skipped

This is a design choice. The conservative default: only use `causal` and `temporal` for κ. This prevents false positives where two nodes with a symmetric "context" relationship get flagged as a feedback loop.

### Performance budget

- **Graphonomous:** Topology computation adds to every `retrieve_context` call. Target: < 10ms for typical retrieved subgraphs (< 50 nodes). SCC decomposition is O(V+E) ≈ microseconds. κ bipartition is the bottleneck — but only runs on nontrivial SCCs, which are rare and small.
- **BendScript:** Topology recomputed on every edge add/remove. Target: < 50ms for graphs up to 100 nodes. Cache aggressively. Run in `requestAnimationFrame` only when dirty flag is set.

---

*Reference documents: `graphonomous.com/project_spec/kappa_reference.py`, `graphonomous.com/project_spec/kappa_theory_applied.md`, `graphonomous.com/project_spec/kappa_integration_spec.md`, `graphonomous.com/project_spec/kappa_product_crosswalk.md`. Graphonomous spec: `graphonomous.com/project_spec/README.md`. BendScript prototype: `bendscript.com/index.html`. BendScript build plan: `bendscript.com/prompts/BUILD.md`.*
