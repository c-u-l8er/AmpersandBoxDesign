# [&] Ecosystem — Codex Prompt Guide
Version: 1.0
Date: March 28, 2026

> How to use the existing prompts for Codex-driven development, and what new prompts are needed.

---

## 1) Existing Prompt Inventory

### AmpersandBoxDesign/prompts/ (5,063 lines)

| Prompt | Lines | Purpose | Dependency |
|---|---|---|---|
| `PROTOCOL_PROMPT.md` | 679 | Project identity, architecture, formal grammar, design system | None (read first) |
| `KAPPA_BUILD_PROMPT.md` | 1,053 | κ cyclicity detection implementation (v2). Canonical schema, field rules. | PROTOCOL_PROMPT |
| `KAPPA_DELIBERATOR_PROMPT.md` | 946 | Deliberation loop: decompose → focus → reconcile pipeline. | KAPPA_BUILD |
| `ATTENTION_ENGINE_PROMPT.md` | 1,335 | Proactive attention: survey → triage → dispatch → execute → reflect. | KAPPA_DELIBERATOR |
| `MODEL_TIER_PROMPT.md` | 860 | Hardware-adaptive tier budgets (8B / 70B+ / cloud frontier). | ATTENTION_ENGINE |
| `GRAPHONOMOUS_PROMPT.md` | 190 | Autonomous codebase traversal using Graphonomous MCP. | PROTOCOL_PROMPT |

### bendscript.com/prompts/ (3,461 lines)

| Prompt | Lines | Purpose |
|---|---|---|
| `BUILD.md` | 1,738 | Full SvelteKit + Supabase architecture and migration spec |
| `MIGRATION_PROMPT.md` | 842 | Engine extraction from prototype to production |
| `CODEX_COMPLETION_PROMPT.md` | 881 | Current-state completion guide written specifically for Codex |

### Dependency Order (read in this sequence)

```
PROTOCOL_PROMPT          ← architecture + identity
    ↓
KAPPA_BUILD_PROMPT       ← topology detection
    ↓
KAPPA_DELIBERATOR_PROMPT ← reasoning loop
    ↓
ATTENTION_ENGINE_PROMPT  ← autonomous ignition
    ↓
MODEL_TIER_PROMPT        ← hardware adaptation
```

---

## 2) How to Use with Codex

### For Graphonomous tasks
1. Load `PROTOCOL_PROMPT.md` for ecosystem context
2. Load `GRAPHONOMOUS_PROMPT.md` for traversal protocol
3. Load the relevant numbered prompt (KAPPA_BUILD, DELIBERATOR, ATTENTION, or MODEL_TIER)
4. Reference `graphonomous.com/project_spec/README.md` as the implementation spec
5. Run Codex with task-specific instructions

### For BendScript tasks
1. Load `bendscript.com/prompts/CODEX_COMPLETION_PROMPT.md` (already Codex-formatted)
2. Reference `bendscript.com/project_spec/README.md` as the spec
3. Optionally load `BUILD.md` for architecture decisions

### For WebHost.Systems tasks
1. Load `PROTOCOL_PROMPT.md` for [&] context
2. Reference `WebHost.Systems/project_spec/spec_v1/70_AMPERSAND_PROTOCOL_INTEGRATION.md`
3. Generate task-specific Codex prompts from the §70 spec phases

---

## 3) New Codex Prompts Needed

Once project_specs are finalized (all 5 new specs now exist), generate implementation prompts for each ecosystem app. Priority order based on implementation readiness:

### High priority (reference impl exists, specs complete)

| App | Spec | Prompt to Create | Implementation Stack |
|---|---|---|---|
| **Delegatic** | `delegatic.com/project_spec/README.md` | `DELEGATIC_BUILD_PROMPT.md` | Elixir/OTP, Phoenix, Ecto |
| **Deliberatic** | `deliberatic.com/project_spec/README.md` | `DELIBERATIC_BUILD_PROMPT.md` | Elixir/OTP |
| **AgenTroMatic** | `agentromatic.com/project_spec/README.md` | `AGENTROMATIC_BUILD_PROMPT.md` | Elixir/OTP |

### Medium priority (specs complete, no impl yet)

| App | Spec | Prompt to Create | Implementation Stack |
|---|---|---|---|
| **TickTickClock** | `ticktickclock.com/project_spec/README.md` | `TICKTICKCLOCK_BUILD_PROMPT.md` | Elixir/OTP, Mamba SSM |
| **GeoFleetic** | `geofleetic.com/project_spec/README.md` | `GEOFLEETIC_BUILD_PROMPT.md` | Elixir/OTP, CRDTs |
| **Agentelic** | `agentelic.com/project_spec/README.md` | `AGENTELIC_BUILD_PROMPT.md` | Elixir/OTP |

### Lower priority (marketplace/tooling, depends on others)

| App | Spec | Prompt to Create | Implementation Stack |
|---|---|---|---|
| **FleetPrompt** | `fleetprompt.com/project_spec/README.md` | `FLEETPROMPT_BUILD_PROMPT.md` | Web app (TBD) |
| **SpecPrompt** | `specprompt.com/project_spec/README.md` | `SPECPROMPT_BUILD_PROMPT.md` | CLI + web (TBD) |
| **OpenSentience** | `opensentience.org/project_spec/README.md` | Research publication, not a codebase | N/A |

---

## 4) Codex Prompt Template

Each new prompt should follow this structure (based on what works in the existing prompts):

```markdown
# [App Name] — Codex Build Prompt
Version: 1.0
Date: [date]

## Identity
[What this app IS in 2-3 sentences. Role in [&] ecosystem.]

## Architecture
[ASCII diagram from project_spec. Key components and their responsibilities.]

## [&] Capabilities
[What capabilities this app provides/consumes. Contract references.]

## Implementation Spec Reference
[Point to project_spec/README.md sections]

## Build Order
[Phased task list, ~500-1000 lines per phase]

### Phase 1: [Name]
- Task 1: [description, inputs, outputs, acceptance criteria]
- Task 2: ...

### Phase 2: [Name]
...

## API Surface
[Key endpoints, MCP tools, or CLI commands to implement]

## Field Naming Conventions
[From KAPPA_BUILD_PROMPT pattern — explicit field name rules]

## Testing Requirements
[What constitutes "done" for each phase]

## Dependencies
[Other [&] apps this depends on, and mock strategies when they're not available]
```

---

## 5) Cleanup Notes

The existing prompts are **not stale** — they are current (March 2026) and technically precise. No cleanup needed on content. What would help:

1. **Add frontmatter** to each prompt (version, date, dependencies, target-app)
2. **Cross-link** prompts to their corresponding project_spec
3. **Add milestone gates** ("what constitutes done" per section)
4. **Break ATTENTION_ENGINE_PROMPT** (1,335 lines) into Codex-sized chunks if Codex context windows are a constraint

---

## 6) Generation Workflow

When ready to generate a new Codex prompt:

1. Read the target app's `project_spec/README.md`
2. Read the relevant [&] capability contracts in `AmpersandBoxDesign/contracts/v0.1.0/`
3. Read `PROTOCOL_PROMPT.md` for ecosystem context
4. Use the template from §4 above
5. Save to `AmpersandBoxDesign/prompts/[APP]_BUILD_PROMPT.md`
6. Update this guide's inventory (§1)
