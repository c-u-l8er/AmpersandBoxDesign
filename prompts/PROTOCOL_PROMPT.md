# [&] Protocol — Zed AI Coder Prompt

## Project Identity

You are building **the [&] Protocol ecosystem** — an open-source, language-agnostic specification for composing agent cognitive capabilities. The ampersand (`&`) is a composition operator, not a logo. The protocol sits at the **composition layer** of the agent protocol stack — above MCP (agent-to-tool, Anthropic/AAIF) and A2A (agent-to-agent, Google/AAIF), below UI protocols (AG-UI, A2UI).

**The core thesis**: MCP defines how agents call tools. A2A defines how agents call agents. Neither defines how cognitive capabilities compose into a coherent system — what memory, reasoning, temporal, and spatial capabilities an agent needs, whether they're compatible, and how context flows between them with provenance. [&] fills that gap.

**Organization**: Ampersand Box Design (ampersandboxdesign.com)
**GitHub**: github.com/c-u-l8er/AmpersandBoxDesign
**Author/Founder**: Travis (traaviis.com / c-u-l8er.link)
**License**: Apache 2.0
**Reference implementation language**: Elixir
**Planned bindings**: TypeScript (`@ampersand/sdk`), Rust (`ampersand-rs`)

---

## Protocol Architecture Summary

### The Four Capability Domains (Cognitive Primitives)

The protocol defines exactly four fundamental capability domains. These are framed as **engineering infrastructure primitives** in documentation aimed at developers, and as **cognitive primitives** when connecting to the theoretical foundations. Both framings are valid and should be used contextually:

| Primitive | Engineering Domain | Cognitive Mapping | Question | Color |
|-----------|-------------------|-------------------|----------|-------|
| `&memory` | State persistence | Knowledge / episodic recall | What the agent knows | Cyan `#4af5c6` |
| `&reason` | Decision logic | Deliberation / planning | How the agent decides | Blue `#7b8cff` |
| `&time` | Temporal modeling | Temporal awareness / forecasting | When things happen | Rose `#ff6b8a` |
| `&space` | Spatial modeling | Spatial awareness / navigation | Where things are | Amber `#ffc46b` |

**Cognitive architecture lineage**: These four primitives are not arbitrary. They map directly to established cognitive science models:

- **SOAR** (Newell, 1990; Laird, 2012): Integrates procedural memory, semantic memory, episodic memory, and a Spatial Visual System (SVS). SOAR's memory types map to `&memory` subtypes; its SVS maps to `&space`; its deliberation/impasse resolution maps to `&reason`.
- **ACT-R** (Anderson, CMU): Modular architecture with declarative memory, procedural memory, visual/spatial modules, and temporal constraints on retrieval. ACT-R's imaginal buffer (mental workspace) maps to `&reason`; its temporal dynamics map to `&time`.
- **CoALA** (Cognitive Architectures for Language Agents, 2023): Proposes that LLM agents need working memory, long-term memory (procedural, semantic, episodic), and structured action spaces. CoALA explicitly draws on SOAR and ACT-R. [&] formalizes these insights as composable, provider-agnostic primitives with a validation algebra.

When writing developer-facing content (README, CLI help, API docs), prefer the engineering framing: "capability domains" and "state persistence / decision logic / temporal modeling / spatial modeling." When writing the spec, positioning docs, or research-facing content, use the cognitive science framing to establish intellectual legitimacy.

### Namespaced Subtypes

Each primitive has subtypes:

- `&memory` → `.graph`, `.vector`, `.episodic`, `.semantic`
- `&reason` → `.argument`, `.vote`, `.plan`, `.chain`
- `&time` → `.anomaly`, `.forecast`, `.pattern`, `.baseline`
- `&space` → `.fleet`, `.geofence`, `.route`, `.region`

Custom subtypes are permitted if they satisfy the primitive's capability contract.

### Two Operators

- `&` — Composition: combines capabilities into a validated set
- `|>` — Pipeline: flows data through capability operations

### Formal Grammar (BNF)

```
AgentSpec       := "agent" Identifier "{" CapabilityBlock GovernanceBlock? "}"
CapabilityBlock := "capabilities" "[" CapabilityList "]"
CapabilityList  := Capability ("," Capability)*
Capability      := "&" PrimitiveType ("." Subtype)? "(" ProviderExpr? ("," Config)? ")"
PrimitiveType   := "memory" | "reason" | "time" | "space"
Subtype         := Identifier
ProviderExpr    := ":" Identifier | ":" "auto"
Config          := KeyValue ("," KeyValue)*
CapabilitySet   := Capability ("&" Capability)*
Pipeline        := Expression ("|>" CapabilityOp)*
GovernanceBlock := "governance" "{" Constraint* "}"
Constraint      := HardConstraint | SoftConstraint | EscalationRule
```

### Three-Layer Architecture

| Layer | Name | Description | Artifact |
|-------|------|-------------|----------|
| 1 | Canonical Schema | JSON/YAML capability composition format. Language-agnostic. Normative. | `ampersand.schema.json` |
| 2 | Abstract Operations | compose, validate, bind, invoke, trace | This specification |
| 3 | Language Bindings | Concrete SDKs (Elixir macros, TypeScript, Rust) | hex / npm / crates.io |

### Canonical Agent Declaration (`ampersand.json`)

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "InfraOperator",
  "version": "1.0.0",
  "capabilities": {
    "&memory.graph":      { "provider": "graphonomous", "config": { "instance": "infra-ops" } },
    "&time.anomaly":      { "provider": "ticktickclock", "config": { "streams": ["cpu", "mem"] } },
    "&space.fleet":       { "provider": "geofleetic", "config": { "regions": ["us-east"] } },
    "&reason.argument":   { "provider": "deliberatic", "config": { "governance": "constitutional" } }
  },
  "governance": {
    "hard": ["Never scale beyond 3x in a single action"],
    "soft": ["Prefer gradual scaling over spikes"],
    "escalate_when": { "confidence_below": 0.7, "cost_exceeds_usd": 1000 }
  },
  "provenance": true
}
```

### Composition Algebra Properties

The `&` operator satisfies ACI (Abelian, Commutative, Idempotent) — the same properties CRDTs use for conflict-free convergence:

- **Commutative**: `&memory & &time ≡ &time & &memory`
- **Associative**: `(&memory & &time) & &space ≡ &memory & (&time & &space)`
- **Idempotent**: `&memory & &memory ≡ &memory`
- **Identity**: `&none & &memory ≡ &memory`

### Context Provenance

Every capability operation appends a hash-linked provenance record:

```json
{
  "source":       "&time.anomaly",
  "provider":     "ticktickclock",
  "operation":    "detect",
  "timestamp":    "2026-03-14T14:23:07Z",
  "input_hash":   "sha256:a3f8...",
  "output_hash":  "sha256:7b2c...",
  "parent_hash":  "sha256:0000...",
  "mcp_trace_id": "ttc-inv-9f3a..."
}
```

### Capability Contracts

Each provider declares typed contracts with `accepts_from` and `feeds_into` — validated at composition time to ensure pipeline type safety:

```json
{
  "capability": "&time.anomaly",
  "operations": {
    "detect":  { "in": "stream_data",  "out": "anomaly_set" },
    "enrich":  { "in": "context",      "out": "enriched_context" },
    "learn":   { "in": "observation",  "out": "ack" }
  },
  "accepts_from": ["&memory.*", "&space.*", "raw_data"],
  "feeds_into":   ["&memory.*", "&reason.*", "&space.*", "output"],
  "a2a_skills":   ["temporal-anomaly-detection"]
}
```

### Governance

Declarative constraints in the schema — not language-specific syntax:
- **Hard constraints**: Inviolable. Implementations MUST prevent violation.
- **Soft constraints**: Preferences passed to reasoning capabilities, MAY be overridden with evidence.
- **Escalation rules**: Define when the agent MUST defer to a human.

### Protocol Stack Position

```
┌─────────────────────────────────────────────────────┐
│  UI          Agent-to-user rendering     A2UI/AG-UI │
├─────────────────────────────────────────────────────┤
│  COMPOSITION Capability declaration,     [&]        │ ← THIS LAYER
│              validation, binding,        Protocol   │
│              provenance                             │
├─────────────────────────────────────────────────────┤
│  COORDINATION Agent-to-agent delegation  A2A        │
├─────────────────────────────────────────────────────┤
│  CONTEXT     Agent-to-tool connectivity  MCP        │
├─────────────────────────────────────────────────────┤
│  RUNTIME     Execution, metering, deploy Any host   │
└─────────────────────────────────────────────────────┘
```

---

## Portfolio Companies (Default Capability Providers)

| Company | Domain | Capability | URL |
|---------|--------|------------|-----|
| Graphonomous | Graph memory for agents | `&memory.graph`, `&memory.episodic` | graphonomous.com |
| Deliberatic | Multi-agent deliberation protocols | `&reason.argument`, `&reason.vote` | deliberatic.com |
| OpenSentience | Open consciousness/sentience research | Research layer | opensentience.org |
| FleetPrompt | Fleet-scale prompt orchestration | `&space.fleet` | fleetprompt.com |
| Delegatic | Delegation protocols | Agent delegation | delegatic.com |
| SpecPrompt | Specification-driven prompting | Spec tooling | specprompt.com |
| Agentelic | Agent lifecycle management | Agent infra | agentelic.com |
| AgenTroMatic | Agent automation | Automation | agentromatic.com |
| WebHost Systems | Hosting infrastructure | Runtime | webhost.systems |

---

## Competitive Landscape & Positioning

### What exists (as of March 2026)

The agent protocol space is dominated by three established layers:
- **MCP** (Anthropic, donated to Linux Foundation AAIF Dec 2025): Agent-to-tool connectivity via JSON-RPC 2.0. Primitives: tools, resources, prompts, sampling. 62k+ GitHub stars on anthropics/skills.
- **A2A** (Google): Agent-to-agent coordination. Agent Cards at `/.well-known/agent.json`. Task delegation, streaming, capability discovery.
- **ACP** (IBM, Linux Foundation): Lightweight REST-based agent communication.

Additional emerging protocols: ANP (Agent Network Protocol, DID-based discovery), AG-UI (agent-to-user interaction).

### The gap [&] fills

No existing protocol formally specifies **how cognitive capabilities compose within an agent**. The closest academic work is:

- **DALIA** (Rodriguez-Sanchez et al., Jan 2026, arXiv:2601.17435) — "Declarative Agentic Layer for Intelligent Agents." Argues MCP is structurally under-specified: tools lack semantic descriptions, dependencies, and compositional constraints. Proposes a declarative layer connecting goals, capabilities, and execution. **This paper validates [&]'s thesis from the academic side.**

- **CoALA** (Cognitive Architectures for Language Agents) — Distinguishes four memory types (working, episodic, semantic, procedural) drawing on the SOAR architecture from the 1980s. [&] formalizes this as composable primitives.

- **Agent Skills** (Anthropic, launched Oct 2025, open-standard Dec 2025) — Bundles of instructions, workflows, scripts, and metadata. Orthogonal to MCP. Skills provide procedural intelligence; MCP provides connectivity. [&] sits above both — declaring what capabilities an agent needs and how they compose, before any skill or tool is invoked.

### Key academic references

- Behrouz & Mirrokni (Google Research, NeurIPS 2025): "Nested Learning" — multi-timescale memory, HOPE architecture. Validates `&memory` primitive with fast/slow modules.
- Kaesberg et al. (ACL 2025): Multi-agent deliberation protocols outperform voting and single-agent approaches. Validates `&reason` primitive.
- Gartner 2025: 40% of enterprise apps will embed AI agents by end of 2026.
- VentureBeat (Jan 2026): "Continual learning shifts rigor toward memory provenance and retention."

### Memory landscape (relevant to Graphonomous / &memory)

Major players in agent memory: Mem0 (intelligent memory layer, Apache 2.0, vector+metadata), Zep (fact extraction, conversation memory), LangMem (LangGraph integration), Letta (self-editing memory, OS-inspired tiered architecture), Cognee (knowledge graphs + vector search). Graph memory is emerging as the next frontier beyond vector RAG — graphonomous.com's thesis.

---

## Design System

### Colors
```css
--bg: #08090c;
--surface: #0e1017;
--surface-2: #14161e;
--border: rgba(255, 255, 255, 0.06);
--text: #e2e0db;
--dim: #6b6980;
--muted: #3d3b4a;
--cyan: #4af5c6;    /* &memory, primary accent */
--blue: #7b8cff;    /* &reason */
--rose: #ff6b8a;    /* &time */
--amber: #ffc46b;   /* &space */
--purple: #b48cff;  /* protocol/meta */
```

### Typography
- Headlines: `Newsreader` (serif, weight 300, italic for emphasis)
- Body/code: `JetBrains Mono` (monospace)
- All caps section labels: 0.65rem, weight 700, letter-spacing 0.3em

### Visual Style
- Dark terminal aesthetic with subtle grain overlay (SVG noise filter)
- Particle system background (canvas, mouse-reactive, colored dots with connecting edges)
- Cards with left-colored borders (2px, primitive color)
- Grid layouts with 1px gap borders
- Callout boxes: `rgba(74,245,198,0.04)` bg, `3px solid var(--cyan)` left border
- Code blocks: `--code-bg: #0b0c12`, left border colored by primitive
- Scroll-triggered fade-up reveals (opacity 0 → 1, translateY 14px → 0)

---

## Current Site Structure

```
ampersandboxdesign.com/
├── index.html                              # Main landing page (hero, thesis, market convergence, protocol preview, ecosystem, architecture, philosophy)
├── protocol.html                           # Full protocol specification (RFC-style, 14 sections across 3 parts)
├── portfolio_company_complete_research.html # Research & valuation page for all portfolio domains
```

---

## What Needs To Be Built (Priority Order)

### Priority 1: Machine-Readable Schema Artifact

Create `ampersand.schema.json` — a real, downloadable JSON Schema (draft 2020-12) that validates `ampersand.json` agent declarations. This is the single most important artifact for protocol adoption. Developers need something they can `$ref` in their own schemas and validate against.

The schema must validate:
- Agent name and version
- Capability declarations with primitive type, optional subtype, provider, and config
- Governance blocks (hard constraints, soft constraints, escalation rules)
- Provenance flag
- Capability contracts (operations, accepts_from, feeds_into, a2a_skills)

Host at: `protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json`

### Priority 2: CLI Tool (`ampersand`)

A CLI is how infrastructure protocols spread. Terraform, Kubernetes, Docker — all grew through CLI tooling. Build a minimal CLI (Node.js or Elixir escript) that does three things:

```bash
# Validate an agent declaration against the schema
ampersand validate agent.ampersand.json

# Compose capabilities and check pipeline type safety
ampersand compose agent.ampersand.json

# Generate MCP server config and A2A agent card from declaration
ampersand generate mcp agent.ampersand.json
ampersand generate a2a agent.ampersand.json
```

The validate command is the MVP — it just wraps JSON Schema validation (ajv for Node, ex_json_schema for Elixir). The compose command checks ACI properties and validates capability contracts. The generate commands are Priority 4's demo, wrapped in a CLI.

Publish as: `npm install -g @ampersand/cli` and/or `mix escript.install hex ampersand`

### Priority 3: GitHub Repository Restructure

The repo at `github.com/c-u-l8er/AmpersandBoxDesign` needs to become the canonical protocol home, not just a website repo. Structure:

```
AmpersandBoxDesign/
├── README.md                    # Protocol overview, quick example, link to spec
├── SPEC.md                      # Full protocol specification (markdown version of protocol.html)
├── schema/
│   └── v0.1.0/
│       ├── ampersand.schema.json      # JSON Schema for agent declarations
│       ├── capability-contract.schema.json  # Schema for capability contracts
│       └── registry.schema.json       # Schema for the capability registry
├── examples/
│   ├── infra-operator.ampersand.json  # The InfraOperator example from the spec
│   ├── research-agent.ampersand.json  # A research/analysis agent
│   ├── customer-support.ampersand.json # Customer support agent
│   └── README.md                      # Explains each example
├── reference/
│   └── elixir/                        # Elixir reference implementation
│       ├── mix.exs
│       ├── lib/
│       │   ├── ampersand.ex           # Core composition module
│       │   ├── ampersand/
│       │   │   ├── schema.ex          # Schema validation
│       │   │   ├── compose.ex         # Capability composition (& operator)
│       │   │   ├── pipeline.ex        # Pipeline execution (|> operator)
│       │   │   ├── provenance.ex      # Hash-linked provenance chain
│       │   │   ├── governance.ex      # Constraint enforcement
│       │   │   ├── registry.ex        # Capability registry
│       │   │   ├── mcp.ex             # MCP configuration generation
│       │   │   └── a2a.ex             # A2A agent card generation
│       │   └── ampersand/
│       │       └── primitives/
│       │           ├── memory.ex
│       │           ├── reason.ex
│       │           ├── time.ex
│       │           └── space.ex
│       └── test/
├── tools/
│   ├── validate.sh                    # CLI: validate an ampersand.json against schema
│   └── generate-mcp.sh               # CLI: generate MCP config from ampersand.json
├── docs/
│   ├── positioning.md                 # "The Missing Layer" positioning document
│   ├── faq.md
│   └── comparison-table.md            # [&] vs MCP vs A2A vs DALIA vs ACP
├── site/                              # Website source files
│   ├── index.html
│   ├── protocol.html
│   └── portfolio_company_complete_research.html
├── LICENSE                            # Apache 2.0
└── CONTRIBUTING.md
```

### Priority 4: "The Missing Layer" Positioning Document

A focused 1500-2000 word document (`docs/positioning.md`) titled:

**"The Missing Layer: Capability Composition in the Agent Protocol Stack"**

Structure:
1. **The current stack** — MCP (context/tools), A2A (coordination), ACP (communication). What each does well.
2. **The gap** — No protocol defines how cognitive capabilities compose. Cite DALIA (arXiv:2601.17435) as independent academic validation. Cite the CoALA taxonomy. Note that MCP's own extensions (ScaleMCP, MCPEval) improve operational dimensions but don't address composition.
3. **What composition means** — Not just "agent has memory and reasoning." Formal grammar. Algebraic properties (ACI). Type-safe pipelines. Hash-linked provenance. Declarative governance.
4. **The [&] Protocol** — Stack position diagram. The four primitives mapped to cognitive science. How ampersand.json works. How it generates MCP/A2A configurations (not replaces them).
5. **Try it** — Link to schema, example agent declarations, validation tool.

Tone: Technical but accessible. No marketing language. Write it like an RFC introduction or a Stripe engineering blog post.

### Priority 5: Working MCP/A2A Generation Demo

The killer demo: take an `ampersand.json` and produce:
1. An MCP server configuration that wires up the declared capability providers
2. An A2A agent card (`/.well-known/agent.json`) that advertises the agent's composed capabilities as A2A skills

This proves [&] is complementary to MCP/A2A, not competitive. It's the "from spec to running agent" path described in Part B §13 of the protocol spec.

### Priority 6: Documentation Hub

Break the monolithic research page into standalone pages:

```
/docs/protocol           → The spec (already exists as protocol.html)
/docs/capabilities/memory → Deep dive on &memory, subtypes, providers, research
/docs/capabilities/reason → Deep dive on &reason, deliberation protocols, research
/docs/capabilities/time   → Deep dive on &time, temporal intelligence, research
/docs/capabilities/space  → Deep dive on &space, spatial intelligence, research
/docs/architecture        → Reference architecture guide
/docs/research            → Market convergence research (refactored from portfolio page)
```

Each capability page should include: theory, research citations, architecture patterns, protocol schema for that primitive, example providers, and an example pipeline using that capability.

### Priority 7: Capability Registry Pages (Programmatic SEO)

Only after the above exists. Generate structured pages like:

```
/capabilities/memory.graph
/capabilities/memory.episodic
/capabilities/reason.argument
/capabilities/time.forecast
/capabilities/space.fleet
```

Each page includes: definition, capability contract JSON, architecture diagram, example API, research references, compatible providers. These are programmatic but high-quality — not thin SEO pages.

---

## Elixir Reference Implementation Notes

The DSL syntax in Elixir uses macros. The `&` is literally Elixir's capture operator repurposed as a composition operator:

```elixir
defmodule InfraOperator do
  use Ampersand.Agent

  capabilities do
    &memory.graph(:graphonomous, instance: "infra-ops")
    &time.anomaly(:ticktickclock, streams: [:cpu, :mem])
    &space.fleet(:geofleetic, regions: ["us-east"])
    &reason.argument(:deliberatic, governance: :constitutional)
  end

  governance do
    hard "Never scale beyond 3x current capacity in a single action"
    soft "Prefer gradual scaling over sudden spikes"
    escalate_when confidence_below: 0.7, cost_exceeds_usd: 1000
  end
end
```

Pipeline usage:

```elixir
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &space.fleet.locate()
|> &reason.argument.evaluate()
```

Each step appends a provenance record. The full chain is queryable after execution.

---

## Key Technical Decisions

- **JSON Schema (draft 2020-12)** for the canonical schema — widest tooling support
- **Hash-linked provenance** (SHA-256) — same pattern as git commits and blockchain, but for capability operation chains
- **ACI algebra** — borrowed from CRDT theory. Ensures capability sets converge regardless of declaration order, enabling distributed composition
- **Capability contracts** with `accepts_from`/`feeds_into` — enables compile-time pipeline validation
- **Provider-agnostic** — capabilities are interfaces. `&memory.graph` can be satisfied by Graphonomous, Neo4j, or any MCP-compatible graph service
- **Governance as data** — constraints live in the schema, not in code. Portable across implementations

---

## SEO & Discovery Goals

Target search terms the project should own:
- "agent capability composition protocol"
- "agent cognitive capability specification"
- "AI agent capability registry"
- "agent protocol composition layer"
- "MCP capability composition"
- "agent memory reasoning time space"

The site should be discoverable by AI crawlers and training datasets. Protocol specs, formal grammars, and JSON schemas get disproportionately crawled because they're structured, technical, and novel.

---

## Strategic Positioning (Critical)

**Never say "[&] sits above MCP and A2A."** Ecosystem politics matter. Instead, always frame it as:

> "[&] compiles into MCP + A2A configurations."

The mental model for developers should be:

```
ampersand.json  →  ampersand compose  →  mcp-config.json + agent-card.json
```

[&] is the **source of truth** that generates the wiring for existing protocols. This makes adoption frictionless — developers don't need to abandon MCP or A2A, they gain a higher-level declaration language that outputs configurations for both.

The protocol + ecosystem model is analogous to:
- **Terraform** (HCL → cloud provider API calls)
- **Kubernetes** (YAML manifests → container orchestration)
- **Stripe** (API + marketplace of payment methods)

The [&] portfolio companies (Graphonomous, Deliberatic, etc.) function as **default capability providers** — the "Stripe-native payment methods" equivalent. But any MCP-compatible service can be a provider.

---

## Single-Line Composition Expressions

The protocol supports a compact, memeable composition syntax:

```
&memory.graph & &time.anomaly & &reason.argument
```

And a pipeline form:

```
(&memory.graph & &time.anomaly) |> &reason.argument
```

This is intentionally reminiscent of Unix pipes, Elixir pipelines, and Haskell function composition. It should appear prominently in README headers, social media, and anywhere the protocol needs to be instantly recognizable. The syntax IS the brand.

---

## Voice & Tone Guidelines

- **Technical precision**: Use RFC-style language (MUST, SHOULD, MAY) in spec documents
- **No hype**: Never say "revolutionary" or "game-changing." The protocol's value is self-evident from the gap it fills
- **Infrastructure voice**: Write like you're documenting something that already exists and works, not pitching something aspirational
- **Compositional thinking**: Every explanation should come back to the core metaphor — capabilities compose like functions, the ampersand is an operator
- **Respect for the ecosystem**: [&] complements MCP and A2A. Never position against them. The protocol generates configurations for them.

---

## Cognitive Science & Neuroscience Grounding

The four primitives have deep roots in how biological intelligence is modeled. This connection should be referenced in the positioning document and spec, but never over-emphasized in developer docs.

### The mapping

| [&] Primitive | Brain Region / System | Cognitive Science Model |
|---------------|----------------------|------------------------|
| `&memory` | Hippocampus (episodic), Neocortex (semantic), Basal ganglia (procedural) | Atkinson-Shiffrin model; SOAR's semantic + episodic memory; ACT-R's declarative memory |
| `&reason` | Prefrontal cortex (planning, deliberation), Anterior cingulate (conflict monitoring) | BDI (Belief-Desire-Intention) model; SOAR's impasse resolution; ACT-R's production system |
| `&time` | Cerebellum (timing), Hippocampus (temporal sequence), Basal ganglia (interval timing) | Temporal difference learning; ACT-R's temporal constraints on retrieval |
| `&space` | Hippocampus (cognitive maps), Parietal cortex (spatial reasoning), Entorhinal cortex (grid cells) | Cognitive Map Theory (O'Keefe & Nadel); SOAR's Spatial Visual System; ACT-R/E's embodied spatial module |

### Key references for the neuroscience connection

- **O'Keefe & Nadel (1978)**: "The Hippocampus as a Cognitive Map" — established that the hippocampus encodes spatial relationships. The discovery of place cells (O'Keefe) and grid cells (Moser & Moser, Nobel 2014) confirmed this. Maps to `&space`.
- **Tulving (1972, 1983)**: Distinction between episodic and semantic memory. Maps directly to `&memory.episodic` vs `&memory.semantic`.
- **Baddeley & Hitch (1974)**: Working memory model with central executive. The central executive maps to `&reason`; the phonological loop and visuospatial sketchpad map to `&time` and `&space` processing.
- **Cognitive Map Theory (Burgess et al., 2002)**: Broader hippocampal function including temporal and spatial-associative retrievals — connecting `&memory`, `&time`, and `&space` at the neural level.

### How to use this

The neuroscience grounding serves two purposes: (1) it explains **why** four primitives and not three or five — these are the fundamental axes along which biological cognition organizes information, and (2) it provides academic legitimacy when the protocol is discussed in research contexts. The positioning document should include a brief section connecting [&]'s primitives to cognitive architectures (SOAR, ACT-R, CoALA) and note the neuroscience parallels without over-claiming.

---

## Key Academic References (Complete List)

### Cognitive Architectures
- Newell, A. (1990). *Unified Theories of Cognition*. Harvard University Press.
- Laird, J.E. (2012). *The Soar Cognitive Architecture*. MIT Press.
- Anderson, J.R. (2007). *How Can the Human Mind Occur in the Physical Universe?* Oxford University Press. (ACT-R)
- Sumers et al. (2023). "Cognitive Architectures for Language Agents (CoALA)." arXiv:2309.02427.

### Agent Protocols & Composition
- Rodriguez-Sanchez et al. (Jan 2026). "DALIA: Declarative Agentic Layer for Intelligent Agents." arXiv:2601.17435.
- Anthropic (2024-2025). Model Context Protocol specification. modelcontextprotocol.io.
- Google (2025). Agent-to-Agent Protocol (A2A). github.com/google/A2A.
- IBM / Linux Foundation (2025). Agent Communication Protocol (ACP).

### Memory & Reasoning
- Behrouz & Mirrokni (Google Research, NeurIPS 2025). "Nested Learning" — HOPE architecture for multi-timescale memory.
- Kaesberg et al. (ACL 2025). Multi-agent deliberation protocols outperforming voting approaches.
- VentureBeat (Jan 2026). "Continual learning shifts rigor toward memory provenance and retention."

### Agent Skills & Frameworks
- Anthropic (Oct 2025). Agent Skills launch; open standard Dec 2025. 62k+ GitHub stars.
- Survey papers: arXiv:2508.10146v1 (Agentic AI Frameworks), arXiv:2601.12560v1 (Agentic AI taxonomies).

### Industry
- Gartner (2025). 40% of enterprise apps will embed AI agents by end of 2026.
- Linux Foundation AAIF: MCP donated Dec 2025; ACP and related protocols under governance.
