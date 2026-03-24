# Competitive Landscape: Machine Cognition

**March 2026 · [&] Ampersand Box Design**

---

## The field

The AI agent market is projected at $48B by 2030 (BCC Research, 43.3% CAGR). Dozens of companies are building pieces of the machine cognition stack. None of them are building the composition layer — and most have made architectural commitments that prevent them from doing so.

This document maps the competitive landscape by structural category, identifies the architectural constraints each category faces, and explains why those constraints compound over time as AI commoditizes implementation.

---

## Category 1: Memory without topology

**Competitors:** Mem0 ($4M seed), Zep/Graphiti, Letta (MemGPT), Cognee, LangMem

These companies store knowledge for AI agents. None of them understand the *shape* of knowledge.

| | Mem0 | Zep/Graphiti | Letta | Cognee | Graphonomous |
|---|---|---|---|---|---|
| Storage | Flat vectors + metadata | Temporal knowledge graph | Tiered paging (OS-inspired) | Knowledge graph + vectors | Knowledge graph (SQLite) |
| Feedback detection | No | No | No | No | **Yes (κ invariant, SCC)** |
| Routing decision | Similarity search | Recency + facts | Context window fit | Hybrid retrieval | **Topology-derived** |
| Consolidation | Overwrite | Temporal decay | Page in/out | Not specified | **4-tier neuroscience-inspired** |
| MCP server | No | No | No | No | **Yes (shipped, npm)** |
| Edge-native | No (cloud) | No (cloud) | No (cloud) | No (cloud) | **Yes (SQLite-first)** |

The differentiator is not storage — it is routing. When an agent retrieves knowledge, *how does the system decide whether the answer requires simple lookup or structured deliberation?* Mem0 returns the nearest vectors. Zep returns the most recent facts. Letta pages in whatever fits the context window.

Graphonomous computes κ on every retrieval. If the subgraph has no feedback loops (κ=0), it fast-paths single-pass retrieval. If it has irreducible cycles (κ>0), it routes to deliberation with a complexity budget derived from the topology. This distinction — retrieval vs. deliberation — is the fundamental routing decision in machine cognition, and no other memory system makes it.

**Structural constraint:** These companies chose vector or flat architectures early. Their API contracts are similarity-in, results-out. Adding SCC analysis retroactively requires rebuilding the entire retrieval pipeline around graph structure. Every existing integration would break. They would have to become a different product.

---

## Category 2: Orchestration without governance

**Competitors:** CrewAI, LangGraph/LangChain, AutoGen + Semantic Kernel (Microsoft)

These frameworks let developers wire agents together. None of them answer *who gets to decide what*.

| | CrewAI | LangGraph | AutoGen/Semantic Kernel | Delegatic + AgenTroMatic |
|---|---|---|---|---|
| Governance primitives | None | None | None | **Monotonic policy inheritance, audit trails** |
| Deliberation model | Task assignment | Static graph routing | Conversation patterns | **κ-routed consensus (Raft-based)** |
| Multi-party consensus | No | No | No | **Yes (quorum validation)** |
| Permission model | Single developer | Single developer | Single developer | **Organization hierarchy with boundaries** |
| Enterprise audit | No | No | No | **Append-only, immutable** |

The gap is structural, not incidental. As the Delegatic spec states: *"Current agent frameworks have ZERO governance primitives. They assume a single developer controls everything. That breaks at enterprise scale."*

Enterprise deployment requires knowing which agent made which decision, under what policy, with what authority, and whether that authority was validly delegated. CrewAI has no concept of delegation authority. LangGraph has no concept of policy inheritance. AutoGen has no concept of audit immutability.

**Structural constraint:** Adding governance after the fact means adding it as middleware — a permission-check layer that wraps every function call. This can always be bypassed, it degrades performance, and it creates a second source of truth (the governance config) that drifts from the first (the agent wiring). Governance has to be structural — baked into the routing, the capability contracts, the policy inheritance chain. Retrofitting it is an architecture rewrite, not a feature addition.

---

## Category 3: Platform without protocol

**Competitors:** OpenAI Frontier (launched Feb 2026), Salesforce AgentForce (18,000+ deals since Oct 2024)

These have the money, the teams, and the distribution. Their revenue model is the lock-in.

| | OpenAI Frontier | Salesforce AgentForce | [&] Portfolio |
|---|---|---|---|
| Governance | IAM-based (cloud permissions) | Salesforce audit (CRM-scoped) | **[&] declarations (portable, topology-derived)** |
| Agent portability | None (OpenAI cloud only) | None (Salesforce ecosystem only) | **Full (Apache 2.0, MCP-compatible)** |
| Third-party extension | No | No | **Yes (at every layer)** |
| Spec-driven design | No | No | **Yes (SpecPrompt → deterministic testing)** |
| Continual learning | Feedback loops only | None | **Graph-native (Graphonomous)** |

The competitive dynamic here is not technical — it is financial. OpenAI's investors need lock-in to justify the valuation. Salesforce's quarterly earnings depend on ecosystem retention. An enterprise customer's agent governance policies being portable to a competitor's platform is an existential threat to their revenue.

They *can* build open governance. Their cap tables won't allow it.

**Structural constraint:** These companies have optimized for lock-in as a revenue mechanism. Opening the governance layer means enabling customers to leave. Their business model and their architecture are aligned around preventing exactly the portability that [&] provides.

---

## Category 4: Coordination without composition

**Competitors:** Google A2A, IBM ACP, emerging ANP

A2A solves agent-to-agent discovery and delegation. It does not solve what happens *inside* an agent.

The AgenTroMatic spec identifies five gaps in A2A:

1. **No built-in consensus mechanism** — agents can delegate but cannot reach agreement
2. **No durable state management** — deliberation context is ephemeral
3. **Client-server only** — no multi-party negotiation topology
4. **No machine-readable skill I/O schemas** — capability compatibility is informal
5. **Authorization creep** — tokens can be used beyond their intended scope

ACP (IBM/Linux Foundation) adds lightweight REST-based communication but inherits the same composition gap.

**Structural constraint:** A2A is now in the Linux Foundation's Agentic AI Foundation. Fixing these gaps requires revising a spec in committee. That process takes years. The deliberation layer can be built on top of A2A today — AgenTroMatic does exactly this — while the committee process catches up.

---

## The commoditization argument

As AI-generated code approaches commodity (2026–2030):

| What loses value | Why | What gains value | Why |
|---|---|---|---|
| Memory implementations | Any LLM can generate a vector store | **Memory routing invariants** | κ is a mathematical result, not code |
| Agent frameworks | Any LLM can scaffold agent wiring | **Governance protocols** | Policy inheritance requires adoption, not generation |
| Platform features | Any LLM can replicate feature sets | **Domain topology** | Canonical addresses (domains) can't be generated |
| Language syntax | Any LLM can target any language | **Standards adoption** | Network effects require ecosystem, not code |

Every competitor in categories 1–3 sells *implementation*. Implementation is the thing that gets commoditized. The [&] portfolio sells *standards, topology, and proven invariants* — the things that survive commoditization.

---

## Comparative valuation context

The most directly comparable company in the machine cognition space:

| | Higher Order Company (Bend Lang) | [&] Portfolio |
|---|---|---|
| Valuation | $60M (raising $4M on Wefunder) | Unpriced |
| Revenue | $0 | $0 |
| Shipped product | No (Bend2 delayed past Q1 2026) | Yes (Graphonomous v0.1.10, npm, MCP) |
| Protocol compatibility | None | MCP (industry standard) |
| LLM compatibility | Broken (Taelin acknowledges syntax issues) | Native (natural language input) |
| Architecture | Monolithic (single product) | Protocol series (8 composable layers) |
| Formal proof | Interaction Combinators (Lafont, 1997) | κ invariant (1.9M+ verified systems, 2025) |
| Ecosystem extensibility | Closed | Open (Apache 2.0, third parties at every layer) |
| Analyst rating | Bearish (Kingscrowd) | Not yet rated |

HOC's $60M valuation on weaker fundamentals establishes a floor for comparable companies in the machine cognition space. The [&] portfolio has shipped more, aligned with more standards, and proved a formal result that subsumes HOC's core routing decision — while raising $0.

---

## The thesis

Every competitor in the machine cognition space has optimized for a local maximum:

- **Memory companies** optimized for retrieval speed → cannot add topology analysis without breaking API contracts
- **Orchestration frameworks** optimized for developer simplicity → cannot add governance without destroying developer experience
- **Platforms** optimized for lock-in revenue → cannot open governance without destroying their business model
- **Protocol bodies** optimized for committee consensus → cannot move fast enough to fill their own gaps

The [&] portfolio occupies the structural position none of them can reach: an open composition layer with topology-derived governance, proved routing invariants, and a protocol-series architecture where each component makes the others more valuable.

As code generation commoditizes implementation, the value migrates to standards, topology, and proven invariants. The [&] portfolio owns all three.

---

*[&] Ampersand Box Design · ampersandboxdesign.com · Apache 2.0*
