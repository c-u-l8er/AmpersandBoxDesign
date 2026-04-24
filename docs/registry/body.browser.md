# `&body.browser`

## Definition

`&body.browser` is the browser-embodiment capability of the [&] Protocol. It declares that an agent has a web browser as its body — a typed interface for perceiving web pages, acting on DOM elements, enumerating what is currently interactable, and encoding page state so prior interactions can be deterministically replayed.

## Why it exists

Before `&body.browser`, agents that drove web pages did so through ungrounded MCP tool calls. There was no typed schema for "what the agent sees in the browser right now," no canonical way to enumerate "what actions are currently available to take," and no deterministic state identity that two agents could agree on for replay. Recording a successful workflow and shipping it to another agent was possible only as bespoke glue code — every integration had to be reinvented.

`&body.browser` closes that gap. It gives every browser-driving agent (OpenClaw, Claude Computer Use, Pi.dev-based agents, agent-browser users, Playwright wrappers, custom Puppeteer scripts) a single capability contract to satisfy. Once satisfied, any upstream capability consumer — `&memory.episodic.store` for recording, `&reason.plan` for generating action sequences, `&govern.telemetry` for observability — can consume the output without knowing which browser driver produced it.

## Position in the primitive family

`&body.browser` is a subtype of `&body` (sensorimotor primitive, introduced in protocol draft v0.1.0). It sits alongside:

- `&body.os` — operating-system embodiment (shell, filesystem, screen)
- `&body.vision` — reserved for audio/visual perception providers
- `&body.voice` — reserved for audio input/output
- `&body.motor` — reserved for physical-actuation providers (robotics)

`&body.browser` is distinct from `&space.*` (external spatial data about fleets and regions), from `&reason.plan` (abstract plan generation), and from `&memory.episodic` (retrospective trace recall). Those primitives consume or produce browser traces but do not themselves constitute a browser body.

## Capability contract summary

```json
{
  "capability": "&body.browser",
  "operations": {
    "perceive":      { "in": "perception_query",  "out": "browser_observation" },
    "act":           { "in": "typed_action",      "out": "action_outcome"      },
    "affordances":   { "in": "scope_query",       "out": "affordance_set"      },
    "encode_state":  { "in": "perception_query",  "out": "state_hash"          },
    "replay":        { "in": "interaction_trace", "out": "replay_result"       }
  },
  "accepts_from": ["&memory.episodic", "&reason.plan", "&govern.telemetry", "&govern.identity", "context", "typed_action", "interaction_trace"],
  "feeds_into":   ["&memory.episodic", "&reason.*",    "&govern.telemetry", "output"]
}
```

Full contract: `contracts/v0.1.0/body.browser.contract.json`.

## Operations

### `perceive(perception_query) → browser_observation`

Capture current browser state. Observation includes URL, a11y tree structure, interactive element refs (e.g. `@e1`, `@e2`), viewport dimensions, document metadata. Refs assigned by a perceive call become stale on any navigation or DOM re-render; callers MUST re-perceive before re-acting on a ref. The observation is deterministic for a given page state.

### `act(typed_action) → action_outcome`

Execute a single typed action. Action types (closed set for v0.1): `click`, `dblclick`, `hover`, `focus`, `fill`, `type`, `press`, `check`, `uncheck`, `select`, `upload`, `scroll`, `scrollintoview`, `drag`, `navigate`, `wait`, `screenshot`. The outcome carries state hashes from before and after the action, which are what `&memory.episodic.store` consumes to build an `InteractionTrace` edge.

### `affordances(scope_query?) → affordance_set`

Enumerate the typed actions currently available in the present browser state. This is the Gibson-style affordance interface: not every action is valid in every state. A `<form>` with no submit button has no `submit` affordance. A disabled button has no `click` affordance. Consumers use this for plan validation (`&reason.plan`) and for state-encoded replay (matching a trace's required affordances against current state).

### `encode_state(perception_query?) → state_hash`

Produce a deterministic hash of current browser state. Canonical encoding: `sha256(canonical_json({url, a11y_tree_structure, viewport_hash}))`. Two agents with the same browser at the same page state MUST produce equal hashes. This is the FSM state-identity primitive — if two perceptions hash equal, a trace recorded from that state is replayable.

### `replay(interaction_trace) → replay_result`

Execute a stored `InteractionTrace` against the current browser. Fails fast if the starting state hash does not match the trace's recorded start, or if any intermediate hash diverges (indicating environment drift). See OS-011 for trace schema and replay semantics.

## Architecture patterns

The canonical flow for browser-embodied continual learning:

```
perceive → affordances → &reason.plan.generate → act (loop) → &memory.episodic.store
                                                                   ↓
                                                           &reason.learn_from_outcome
                                                                   ↓
                                                    &memory.episodic (procedural crystallization)
                                                                   ↓
                                                   FleetPrompt SkillCandidate
```

A website FSM emerges naturally from repeated `perceive → act → perceive` cycles. States are the set of distinct `state_hash` values observed; transitions are the stored `InteractionTrace` edges between them.

## Example declaration

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "WebOperator",
  "version": "0.1.0",
  "capabilities": {
    "&body.browser":   { "provider": "agent-browser" },
    "&memory.episodic": { "provider": "graphonomous" },
    "&reason.plan":    { "provider": "graphonomous" },
    "&govern.telemetry": { "provider": "opensentience" }
  },
  "governance": {
    "hard": [
      "Never submit forms containing credentials without explicit authorization",
      "Never navigate to URLs outside the authorized domain set"
    ],
    "escalate_when": { "confidence_below": 0.7 }
  }
}
```

## Example payload shape

A single `InteractionTrace` edge emitted by `&body.browser.act`:

```json
{
  "trace_id": "01HX...",
  "body_subtype": "browser",
  "state_before": "sha256:abc123...",
  "typed_action": {
    "type": "click",
    "target_ref": "@e5",
    "semantic_locator": { "role": "button", "name": "Submit order" }
  },
  "state_after": "sha256:def456...",
  "latency_ms": 243,
  "outcome_status": "success",
  "provenance": {
    "provider": "agent-browser",
    "capability": "&body.browser",
    "operation": "act",
    "timestamp": "2026-04-21T14:22:05.123Z",
    "agent_id": "WebOperator@workspace_42"
  }
}
```

## Compatible providers

- **agent-browser** (npm) — CLI-first, snapshot-and-ref model; ProjectAmp2 default
- **mcp__Claude_in_Chrome__*** — Chrome extension MCP
- **mcp__plugin_chrome-devtools-mcp__*** — Chrome DevTools MCP (for performance/a11y audit flows)
- **Playwright wrappers** — any Playwright-based driver can satisfy `&body.browser` by adapting the API
- **Pi.dev browser extensions** — see pi.dev for extension authoring

Providers satisfy the contract by implementing the five operations with the declared type signatures and state-hash determinism. Implementations MAY add provider-specific metadata fields (e.g., `playback_speed`, `mobile_emulation`) so long as the standard operations remain compatible.

## Governance implications

- **Hard constraints**: declarations SHOULD restrict browser actions to authorized domains, forbid navigation to external URLs, and deny submission of forms containing credentials unless explicitly authorized. See `&govern.identity` + `&govern.escalation`.
- **Soft constraints**: prefer semantic locators (role/text/label) over positional coordinates for replay robustness.
- **Escalation**: unexpected `action_outcome.status == "failure"` SHOULD emit a `SurpriseSignal` (OS-010 PULSE token) for learning, and optionally an escalation when confidence in the plan drops below threshold.

## Provenance implications

Every `action_outcome` MUST carry provenance: provider, capability, operation, timestamp, agent_id, trace_id. Browser actions are externally observable (they produce HTTP requests, DOM mutations) so provenance is an accountability floor, not a nicety. `&govern.telemetry.emit` consumes these records.

## A2A and MCP implications

- **MCP compilation**: `&body.browser` operations compile to MCP tool calls against the chosen provider's MCP server (e.g., `agent_browser_perceive`, `agent_browser_act`). Tool names are provider-specific; the [&] contract abstracts over them.
- **A2A skills**: `browser-automation`, `web-form-completion`, `data-extraction`, `web-screenshot`, `embodied-browser-replay`. Agents advertising these skills at the A2A layer MUST back them with a conforming `&body.browser` provider.

## Research grounding

- **Gibson's affordances** (1977): the `affordances` operation makes environmental action-availability a first-class protocol concept, not an emergent property of tool calls.
- **Sensorimotor grounding** (Smith & Gasser, 2005): the `perceive`/`act` loop is the minimal interface for grounding cognition in an environment.
- **Ecological interface design** (Vicente & Rasmussen, 1992): affordance enumeration is the cognitive-engineering move that turns a closed action space into an agent-legible one.

## Anti-patterns

- **Recording raw screenshots as state**: screenshots are not deterministic across browsers or viewports. Use `encode_state` + a11y-tree hashing instead. Screenshots belong in `action_outcome` evidence, not in `state_hash`.
- **Replaying without re-perceiving**: refs become stale on navigation. Implementations MUST re-perceive before dereferencing a ref. Callers that bypass this will see stochastic replay failures and incorrectly blame the schema.
- **Stuffing provider-specific actions into `typed_action.type`**: the action-type set is closed for v0.1. If you need a new action type (e.g., `record_audio`), propose it in the next protocol version rather than using `custom:foo` workarounds.
- **Treating `&body.browser` as "just MCP"**: MCP is the transport; `&body.browser` is the capability contract. An MCP browser server that doesn't implement all five operations does not satisfy `&body.browser`.

## Summary

`&body.browser` is the typed browser body for [&] Protocol agents. It makes perception, action, affordance enumeration, and state encoding first-class capability operations rather than implementation conventions. Any browser-driving agent — OpenClaw, Claude Computer Use, agent-browser, Pi.dev plugins — can satisfy the contract and immediately compose with every other [&] capability: episodic memory for recording, planning for generating action sequences, telemetry for observability, governance for authorization. Combined with OS-011 (Embodiment Protocol), `&body.browser` is what makes website FSMs recordable, replayable, and shareable across machines.
