# `&body.os`

## Definition

`&body.os` is the operating-system-embodiment capability of the [&] Protocol. It declares that an agent has a computer operating system as its body — a typed interface for perceiving OS state (screen, windows, filesystem, processes), executing OS actions (shell commands, file I/O, keyboard/mouse input, screen capture), enumerating currently-available OS operations, and encoding OS state so agent workflows can be deterministically replayed across machines.

## Why it exists

The most consequential emerging agent category is the "computer-use agent" — systems that operate a real OS the way a human would. OpenClaw ships this as a shipping product; Claude Computer Use and Pi.dev-based agents approach it from the platform side; myriad Playwright + Bash scripts approximate it. None have a typed capability contract. Each reinvents: "what is the agent looking at right now," "what actions are available," "did the action succeed," and "can this trace replay on another machine."

`&body.os` closes that gap. It gives every OS-driving agent a single capability contract to satisfy — enabling continual-learning memory (via `&memory.episodic`), benchmarking (via PRISM + PULSE), skill crystallization (via FleetPrompt), and governance (via `&govern.*`) without bespoke glue.

This is the direct path to **dark factories**: machine-hosted agents that learn OS workflows, ship them to other machines as `SkillCandidate` payloads, and operate autonomously under Delegatic governance with PRISM-measured reliability.

## Position in the primitive family

`&body.os` is a subtype of `&body` (sensorimotor primitive, introduced in protocol draft v0.1.0). It is the companion subtype to `&body.browser`:

- `&body.browser` — agents that live in a web browser
- `&body.os` — agents that live on a machine
- `&body.vision`, `&body.voice`, `&body.motor` — future expansion

An agent may declare both `&body.browser` and `&body.os` if it operates across both embodiments (common for computer-use agents that drive browsers via the OS's screen API). The two subtypes share the same five standard operations but differ in action surface and state encoding.

## Capability contract summary

```json
{
  "capability": "&body.os",
  "operations": {
    "perceive":      { "in": "perception_query",  "out": "os_observation"     },
    "act":           { "in": "typed_action",      "out": "action_outcome"     },
    "affordances":   { "in": "scope_query",       "out": "affordance_set"     },
    "encode_state":  { "in": "perception_query",  "out": "state_hash"         },
    "replay":        { "in": "interaction_trace", "out": "replay_result"      }
  },
  "accepts_from": ["&memory.episodic", "&reason.plan", "&govern.telemetry", "&govern.identity", "&govern.escalation", "context", "typed_action", "interaction_trace"],
  "feeds_into":   ["&memory.episodic", "&reason.*",    "&govern.telemetry", "&govern.escalation", "output"]
}
```

Full contract: `contracts/v0.1.0/body.os.contract.json`.

## Operations

### `perceive(perception_query) → os_observation`

Capture current OS state. Query modes: `screen` (screenshot + focused window title + pointer position), `filesystem` (cwd + tree under a scope), `process` (process list with key names), `shell` (shell env + recent history), `git` (repo state for the cwd), `full`. Observations are sensitive — they may include file contents, open windows, environment variables. Providers MUST honor `&govern.identity` workspace scoping; observations outside the agent's authorized scope MUST NOT be returned.

### `act(typed_action) → action_outcome`

Execute a single typed OS action. Action types (closed set for v0.1): `shell_exec`, `file_read`, `file_write`, `file_edit`, `file_delete`, `keyboard_input`, `mouse_click`, `mouse_drag`, `screen_capture`, `process_spawn`, `process_signal`. Destructive actions (write/delete/spawn/signal, and `shell_exec` by default) require `&govern.*` authorization; unauthorized attempts emit an escalation and return a typed error without execution. Authorization does NOT carry across replays — each replay re-authorizes.

### `affordances(scope_query?) → affordance_set`

Enumerate the typed OS actions currently available. Affordances are **policy-filtered**: actions the agent is not authorized to take under current `&govern.identity` + Delegatic policy do not appear in the set. A read-only agent sees no `file_write` affordances, even on writable paths. This is a safety-critical difference from `&body.browser` — OS blast radius is wider, so affordance enumeration is the enforcement boundary.

### `encode_state(perception_query?) → state_hash`

Produce a deterministic hash of current OS state. Canonical encoding: `sha256(canonical_json({cwd, focused_window_title, git_head, key_process_names, env_fingerprint}))`. Excludes volatile fields (timestamps, pids, full process list) by design — the goal is replay determinism across machines, not snapshot fidelity. Two machines with the same repo at the same git HEAD and same focused window MUST produce equal hashes.

### `replay(interaction_trace) → replay_result`

Execute a stored `InteractionTrace` against the current OS. OS replay is stricter than browser replay because OS environments drift more (installed tools, file layout, process state). Fails fast on state-hash divergence. **Destructive operations in a trace require re-authorization at replay time** — this is normative; the trace itself does not grant authority. See OS-011 for replay semantics and provenance requirements.

## Architecture patterns

### Pattern 1: Dark-factory autonomous operation

```
&body.os.perceive → &body.os.affordances → &reason.plan (bounded by affordances)
                                                      ↓
                                           &govern.identity.check (authorize)
                                                      ↓
                                              &body.os.act (loop)
                                                      ↓
                                            &memory.episodic.store
                                                      ↓
                                           &govern.telemetry.emit
```

The critical observation: every OS action is **bounded by the current affordance set**, which is **policy-filtered** by Delegatic. An agent cannot plan an action outside its authorization because the affordance never appears. This is the OS-008 harness enforcement boundary realized at the body layer.

### Pattern 2: Skill crystallization (dark factory → dark factory)

```
Machine A: successful InteractionTrace → consolidation → SkillCandidate
                                                              ↓
                                                    FleetPrompt trust-review
                                                              ↓
Machine B: SkillCandidate install → &body.os.replay (with re-authorization per destructive action)
```

This closes the cross-machine loop: one machine learns a deploy workflow, another replays it on its own environment, PRISM benchmarks both to certify the transfer succeeded.

## Example declaration

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "DarkFactoryWorker",
  "version": "0.1.0",
  "capabilities": {
    "&body.os":          { "provider": "openclaw" },
    "&memory.episodic":  { "provider": "graphonomous" },
    "&reason.plan":      { "provider": "graphonomous" },
    "&govern.identity":  { "provider": "delegatic", "config": { "workspace": "factory_42" } },
    "&govern.escalation": { "provider": "delegatic" },
    "&govern.telemetry": { "provider": "opensentience" }
  },
  "governance": {
    "hard": [
      "Never write to paths outside the workspace sandbox",
      "Never spawn processes requiring sudo",
      "Never transmit files to unauthorized endpoints"
    ],
    "escalate_when": {
      "confidence_below": 0.75,
      "hard_boundary_approached": true
    },
    "autonomy": {
      "level": "act",
      "model_tier": "local_large",
      "heartbeat_seconds": 60,
      "budget": {
        "max_actions_per_hour": 100,
        "require_approval_for": ["process_spawn", "file_delete"]
      }
    }
  }
}
```

## Example payload shape

A single destructive-action `InteractionTrace` edge:

```json
{
  "trace_id": "01HX...",
  "body_subtype": "os",
  "state_before": "sha256:abc123...",
  "typed_action": {
    "type": "shell_exec",
    "command": "git commit -m 'deploy: v1.4.2'",
    "cwd": "/workspace/factory_42/repo"
  },
  "state_after": "sha256:def456...",
  "latency_ms": 187,
  "outcome_status": "success",
  "authorization": {
    "policy_id": "delegatic://factory_42/deploy-policy",
    "approved_by": "agent_supervisor@factory_42",
    "approved_at": "2026-04-21T14:22:00Z",
    "expires_at": "2026-04-21T14:32:00Z"
  },
  "provenance": {
    "provider": "openclaw",
    "capability": "&body.os",
    "operation": "act",
    "timestamp": "2026-04-21T14:22:05.187Z",
    "agent_id": "DarkFactoryWorker@factory_42"
  }
}
```

Note the `authorization` block: destructive actions carry their authorization artifact inline so replay can verify it was valid at original execution and re-authorize at replay time.

## Compatible providers

- **OpenClaw** — local, open-source; shipping product; positions at `&body.os` layer cleanly
- **Claude Computer Use** — coordinate-based OS interaction; satisfies `act` with `mouse_click`/`keyboard_input`/`screen_capture`
- **Pi.dev** — extension-based harness; `&body.os` provider via extension
- **Claude Code Bash + Read + Write + Edit tools** — bounded subset; satisfies read-only + scoped-write variants
- **Custom shell/filesystem wrappers** — any wrapper implementing the five operations with policy-filtered affordance enumeration

## Governance implications

`&body.os` is the single most governance-critical capability in the protocol. OS blast radius is unbounded by default; conforming implementations MUST:

1. **Default-deny destructive operations** without explicit `&govern.*` authorization
2. **Policy-filter affordances** — unauthorized actions do not appear in the affordance set at all
3. **Re-authorize at replay** — destructive actions in a stored trace do not carry authorization to re-execution
4. **Emit escalation** on unauthorized attempts rather than silent failure
5. **Honor workspace scoping** from `&govern.identity` — observations outside scope MUST NOT be returned

Violating any of these is a protocol-conformance failure. OS-007 (Adversarial Robustness) treats `&body.os` attacks as the highest-severity threat class.

## Provenance implications

Every `action_outcome` MUST carry full provenance: provider, capability, operation, timestamp, agent_id, trace_id, authorization block (for destructive actions). OS actions are irreversible by default; provenance is the audit floor. `&govern.telemetry.emit` consumes these records; they are retained per Delegatic retention policy.

## A2A and MCP implications

- **MCP compilation**: `&body.os` operations compile to MCP tool calls against the provider's OS-capable MCP server. OpenClaw, Pi.dev, and Claude Computer Use each expose different tool surfaces; the [&] contract normalizes them.
- **A2A skills**: `shell-automation`, `filesystem-read`, `filesystem-mutation`, `screen-capture`, `coordinate-input`, `git-operations`, `embodied-os-replay`.
- **Cross-machine skills**: A2A advertisement of `embodied-os-replay` means "this agent can replay OS InteractionTraces matching these affordance requirements." FleetPrompt uses this for cross-machine skill transfer.

## Research grounding

- **Situated cognition** (Suchman, 1987): OS actions are inherently situated — the same command in different OS states produces different outcomes. Affordance-bounded action spaces formalize this.
- **Ecological interface design** (Vicente & Rasmussen, 1992): policy-filtered affordance enumeration is the mechanism that makes the OS action space **agent-legible** instead of unboundedly dangerous.
- **Capability-based security** (Miller, 2006): `&body.os.affordances` is a capability-ring boundary — the agent cannot conceive of actions outside its authorization.

## Anti-patterns

- **Returning affordances the agent isn't authorized for**: this defeats the safety story. Unauthorized actions MUST NOT appear in the affordance set.
- **Reusing replay authorization**: destructive actions in a trace require fresh authorization at replay. Implementations that skip re-authorization are protocol violations.
- **Encoding volatile state in state_hash**: pids, timestamps, full process lists make cross-machine replay impossible. Hash only stable fields.
- **Using `&body.os` where `&body.browser` fits**: for browser-only tasks, use `&body.browser` — it is lower-blast-radius and has cleaner semantics. Only reach for `&body.os` when the agent genuinely needs shell, filesystem, or screen-level access.
- **Treating OS traces as universally portable**: an OS InteractionTrace from Linux will not replay on Windows. The `metadata` field SHOULD declare target OS family; replay SHOULD fail fast on mismatch.

## Summary

`&body.os` is the typed operating-system body for [&] Protocol agents. It is the protocol's answer to OpenClaw and the computer-use category: a capability contract that makes OS perception, action, affordance enumeration, state encoding, and replay first-class operations with built-in governance boundaries. Combined with OS-011 (Embodiment Protocol) for behavioral semantics and OS-008 (Harness) for runtime enforcement, `&body.os` is the foundation for dark-factory autonomous operation — agents that learn OS workflows, ship them to other machines, and operate under measurable, auditable authorization.
