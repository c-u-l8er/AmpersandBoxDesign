# [&] Portfolio Ingestion Prompt for Graphonomous

Paste this into Zed with Graphonomous MCP connected and all [&] project repos accessible via Zed context.

---

## Prompt

```
You have access to Graphonomous MCP tools (store_node, link_nodes, manage_goal, query_knowledge, learn_from_outcome). You also have access to all 11 [&] project repos via Zed MCP/ACP context.

Below is the complete [&] Ampersand Box Design portfolio topology as JSON — 12 nodes (1 org + 11 products), 32 edges, 5 goals, and an 11-layer stack diagram. Ingest all of it into Graphonomous.

## Phase 1: Store All Nodes

For each object in "nodes", call store_node:
- name → the "label" value
- node_type → the "type" value
- description → the "description" value
- metadata → JSON string of all remaining fields (url, repo, status, layer, stack_order, tags, etc.)

Do them in stack_order (bottom-up: WebHost → Delegatic), org node first.

## Phase 2: Link All Edges

For each object in "edges", call link_nodes:
- source → look up the "from" id's label from the nodes array
- target → look up the "to" id's label from the nodes array
- relation → the "relation" value
- description → the "description" value if present

Do ownership edges first, then functional edges.

## Phase 3: Create Goals

For each object in "goals", call manage_goal:
- action: "create"
- title: the "title" value
- description: combine "description" + "\n\nSuccess criteria: " + "success_criteria"

Then link each goal to its linked_nodes using link_nodes.

## Phase 4: Verify the Graph

Run these queries to confirm connectivity:
1. query_knowledge: "What products does [&] Ampersand Box Design own?"
2. query_knowledge: "What does Delegatic govern?"
3. query_knowledge: "What depends on OpenSentience?"
4. query_knowledge: "What is the only shipped product?"
5. query_knowledge: "Show the stack from hosting to governance"

Report results. Flag anything missing or disconnected.

## Phase 5: Enrich from Live Repos

Now use Zed's file context to scan the actual repos. For each project that has a repo accessible:
- Check if the JSON description is accurate — update the node if the code reveals something the description missed
- For Graphonomous specifically (the shipped product), add nodes for key modules if they reveal architecture worth tracking
- Note any cross-project imports or dependencies not captured in the edges

## Phase 6: Record the Outcome

Call learn_from_outcome:
- outcome: "Ingested full [&] portfolio topology into Graphonomous"
- details: Summary of what worked, what failed, total nodes/edges/goals created
- confidence_delta: positive if everything ingested cleanly, negative if there were failures

## Rules
- Ingest EVERYTHING — don't skip nodes or edges
- If a call fails, log it and continue
- Preserve exact relation names (governs, feeds_into, runs_on, etc.)
- After all phases, give a final summary: nodes stored, edges linked, goals created, failures
```

---

## After Ingestion

Once the graph is loaded, you can use Graphonomous naturally in daily work:

**Query it:**
- "What should I build next?"
- "What depends on Graphonomous?"
- "What's the current status of each product?"
- "Which products are still concepts?"

**Teach it:**
Every time you ship, change direction, or learn something:
```
learn_from_outcome: "Shipped Graphonomous v0.2.0 with ingest CLI.
Took 3 days not the estimated week. FTS5 was the right call."
```

**Track goals:**
```
manage_goal: action=update, title="Dogfood Graphonomous on [&]", state=completed
```

The graph gets smarter the more you use it. That's the whole point.
