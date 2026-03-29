# `&govern.identity` — Agent Identity, Verification, and Trust

`&govern.identity` is the [&] Protocol capability for **cross-runtime agent identity and trust verification**.

It describes an agent's ability to:

- establish a portable, verifiable identity
- prove that identity to other agents and governance systems
- register and update identity in a shared registry
- carry trust metadata that informs collaboration and delegation decisions
- maintain identity continuity across runtimes, sessions, and deployments

In the protocol's five-primitive model:

- `&memory` answers **what** the agent knows
- `&reason` answers **how** the agent decides
- `&time` answers **when** things change
- `&space` answers **where** things are
- `&govern` answers **who approves, what limits apply, and how decisions are audited**

`&govern.identity` is the subtype that answers the foundational question: **who is this agent, and can it be trusted?**

---

## 1. Definition

`&govern.identity` is the capability interface for **agent identity resolution, verification, and registration**.

It is used when a system must:

- resolve an agent's identity from its ID, returning manifest, capabilities, and trust metadata
- verify that an agent's claimed identity matches its registered manifest
- register or update an agent's identity in the shared registry
- link identity to governance policy, org membership, and runtime bindings
- provide trust scores that inform delegation and collaboration decisions

Without portable identity, multi-agent systems cannot answer basic questions:

- Is this agent who it claims to be?
- What capabilities does it actually have?
- Which organization published it?
- What governance constraints apply to it?
- Should I trust its outputs?

`&govern.identity` makes these answers explicit, verifiable, and protocol-native.

---

## 2. Why this capability exists

Many agent systems assume trust implicitly.

That works in single-agent demos, but it breaks down in production multi-agent workflows:

- An agent receives a task delegation from another agent, but cannot verify the sender's identity or authority.
- A governance system needs to audit which agent produced a decision, but agent identity is tied to a specific runtime and not portable.
- A marketplace lists agents for hire, but has no standard way to verify that an agent's declared capabilities match its actual manifest.
- Two agents from different organizations need to collaborate, but neither can verify the other's governance policy or trust level.

In all of these cases, the missing layer is **verifiable, portable agent identity**.

The OpenSentience OS-007 threat model identifies agent impersonation as a critical risk in multi-agent systems. `&govern.identity` is the protocol's answer to that threat.

---

## 3. What problems `&govern.identity` solves

`&govern.identity` is useful when an agent or system needs to answer questions like:

- Who is this agent, and what is its manifest hash?
- Does this agent's claimed identity match its registered manifest?
- Which organization published this agent?
- What capabilities does this agent declare?
- What autonomy level and governance constraints apply?
- What is this agent's trust score, and who computed it?
- Which runtimes is this agent currently bound to?
- Has this agent's manifest changed since registration?

Without this capability, identity management tends to get buried inside:

- runtime-specific authentication systems
- custom API key and token exchanges
- implicit trust assumptions in orchestration code
- vendor-specific agent directories with no interoperability

The protocol makes it explicit instead.

---

## 4. Capability role in the `&govern` namespace

The `&govern` primitive supports multiple subtypes, including:

- `&govern.escalation`
- `&govern.identity`
- `&govern.telemetry`

A helpful distinction is:

- `&govern.escalation` = decision handoff when thresholds are crossed
- `&govern.identity` = agent authentication and trust verification
- `&govern.telemetry` = observability, cost tracking, and budget enforcement

`&govern.identity` is the right subtype when the main problem is **establishing and verifying who an agent is** before trusting its actions, delegations, or outputs.

---

## 5. Typical use cases

### A2A handshake verification
Before two agents collaborate, each verifies the other's identity and governance policy via `&govern.identity.verify()`.

### Agent registration
A newly deployed agent registers its identity, linking its `ampersand.json` declaration, SpecPrompt spec, and Delegatic org membership.

### Marketplace trust evaluation
FleetPrompt computes trust scores based on registered identity metadata. Consumers use `resolve` to inspect an agent's trust profile before delegation.

### Provenance attribution
Every capability operation records the agent's identity in its provenance chain. `&govern.identity` provides the authoritative source for that attribution.

### Governance audit
Auditors query identity records to verify that agents operating within an org match their registered manifests and governance constraints.

### Cross-runtime continuity
An agent migrates between runtimes (e.g., from local development to cloud deployment). Identity persists across the transition because it is bound to the manifest, not the runtime.

---

## 6. Example capability contract

The authoritative contract is at `contracts/v0.1.0/govern.identity.contract.json`.

A representative summary:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/capability-contract.schema.json",
  "capability": "&govern.identity",
  "provider": "opensentience",
  "version": "0.1.0",
  "description": "Cross-runtime agent identity contract for resolution, verification, and registration.",
  "operations": {
    "resolve": {
      "in": "identity_query",
      "out": "agent_identity",
      "description": "Resolve an agent's identity by ID, returning manifest, capabilities, and trust metadata."
    },
    "verify": {
      "in": "verification_request",
      "out": "verification_result",
      "description": "Verify that an agent's claimed identity matches its registered manifest."
    },
    "register": {
      "in": "agent_manifest",
      "out": "registration_ack",
      "description": "Register or update an agent's identity in the shared registry."
    }
  },
  "accepts_from": [
    "&govern.*",
    "identity_query",
    "identity_claim",
    "agent_manifest"
  ],
  "feeds_into": [
    "&govern.escalation",
    "&govern.telemetry",
    "output"
  ],
  "a2a_skills": [
    "agent-identity-verification",
    "manifest-attestation"
  ]
}
```

### What this contract means

This contract says that `&govern.identity` can:

- resolve agent identities from queries
- verify claimed identities against registered manifests
- register new agents or update existing registrations

It also says that this capability composes well with:

- `&govern.escalation` downstream, where escalation requests must be attributed to verified identities
- `&govern.telemetry` downstream, where telemetry events must be attributed to known agents
- `&govern.*` upstream, where other governance capabilities may trigger identity checks

---

## 7. Core operations

### `resolve`

Purpose:
- look up an agent's full identity record by ID

Typical input:
- `identity_query`

Typical output:
- `agent_identity`

Use when:
- another agent or system needs to inspect an agent's capabilities, governance policy, trust score, or runtime bindings before interacting with it

### `verify`

Purpose:
- confirm that an agent's claimed identity matches its registered manifest

Typical input:
- `verification_request`

Typical output:
- `verification_result`

Use when:
- an A2A handshake requires mutual identity verification
- an escalation request must be attributed to a verified agent
- a governance audit checks that operating agents match their registrations

### `register`

Purpose:
- create or update an agent's identity in the registry

Typical input:
- `agent_manifest`

Typical output:
- `registration_ack`

Use when:
- a new agent is deployed and needs to establish its identity
- an agent's manifest, capabilities, or governance policy has changed
- an agent is linking to a new SpecPrompt spec or Delegatic org

---

## 8. Identity fields

The identity record contains the following fields:

### Core identity
- `agent_id` — globally unique identifier (UUIDv7)
- `agent_name` — human-readable name from `ampersand.json`
- `version` — semver from `ampersand.json`

### Integrity hashes
- `manifest_hash` — SHA-256 of the `ampersand.json` declaration at registration time
- `spec_hash` — SHA-256 of the linked SpecPrompt `SPEC.md` (if applicable)

### Organizational binding
- `org_id` — Delegatic org reference
- `publisher_id` — FleetPrompt publisher reference

### Capability declaration
- `capabilities` — list of declared `&`-prefixed capability keys

### Governance summary
- `autonomy_level` — observe, advise, or act
- `model_tier` — local_small, local_large, or cloud_frontier
- `hard_constraints_count` — number of hard governance constraints
- `escalation_configured` — whether `&govern.escalation` is declared

### Runtime bindings
- `runtime` — runtime provider (cloudflare, agentcore, opensentience, custom)
- `deployment_ref` — deployment reference within the runtime
- `status` — active, inactive, or deploying

### Trust metadata
- `trust_score` — FleetPrompt-computed trust score (0.0 to 1.0)
- `registered_at` — ISO 8601 registration timestamp
- `updated_at` — ISO 8601 last update timestamp

---

## 9. Architecture patterns

### Pattern A: A2A handshake with mutual verification

```text
agent_a
|> &govern.identity.resolve(agent_b_id)
|> &govern.identity.verify(agent_b_claim)
|> proceed_if_verified()
```

Use this when:
- two agents need to establish mutual trust before collaborating

### Pattern B: identity-gated escalation

```text
escalation_request
|> &govern.identity.verify(requester)
|> &govern.escalation.escalate()
|> &govern.telemetry.emit()
```

Use this when:
- an escalation request must be attributed to a verified agent before it is surfaced to a human operator

### Pattern C: registration at deployment

```text
ampersand_json
|> &govern.identity.register()
|> &govern.telemetry.emit()
|> deploy_to_runtime()
```

Use this when:
- a new agent is being deployed and needs to establish its registry identity before becoming operational

### Pattern D: trust-aware delegation

```text
task_request
|> &govern.identity.resolve(candidate_agent)
|> check_trust_score()
|> delegate_if_trusted()
```

Use this when:
- a task needs to be delegated to another agent and the trust score should inform the delegation decision

---

## 10. Example declaration

A concrete `ampersand.json` fragment:

```json
{
  "&govern.identity": {
    "provider": "opensentience",
    "config": {
      "registry": "fleetprompt",
      "verify_on_a2a": true
    }
  }
}
```

A fuller declaration:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/schema/v0.1.0/ampersand.schema.json",
  "agent": "DataAnalyst",
  "version": "0.1.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "graphonomous",
      "config": {
        "mode": "continual-learning"
      }
    },
    "&reason.plan": {
      "provider": "auto",
      "need": "data analysis planning with policy-aware access controls"
    },
    "&govern.identity": {
      "provider": "opensentience",
      "config": {
        "registry": "fleetprompt",
        "verify_on_a2a": true
      }
    },
    "&govern.escalation": {
      "provider": "opensentience",
      "config": {
        "timeout_seconds": 1800
      }
    }
  },
  "governance": {
    "hard": [
      "Never access data outside the agent's authorized scope",
      "Always verify collaborating agent identity before sharing results"
    ],
    "soft": [
      "Prefer agents with trust_score above 0.8 for delegation"
    ],
    "escalate_when": {
      "confidence_below": 0.7,
      "collaborator_trust_below": 0.6
    }
  },
  "provenance": true
}
```

---

## 11. Governance and provenance implications

Agent identity is foundational to the entire governance stack. Every other governance capability depends on knowing who the agent is.

### Cross-references

- **OpenSentience OS-006**: defines autonomy levels that are part of the identity governance summary
- **OpenSentience OS-007**: identifies agent impersonation as a critical threat — `&govern.identity` is the primary defense against this threat
- **Delegatic org policies**: org_id in the identity record links the agent to Delegatic budget and governance constraints
- **FleetPrompt trust scores**: publisher_id and trust_score connect the agent to FleetPrompt's trust computation system

### Representative provenance record

```json
{
  "source": "&govern.identity",
  "provider": "opensentience",
  "operation": "verify",
  "timestamp": "2026-03-15T12:00:00Z",
  "agent_id": "agt-01JQ7...",
  "manifest_hash": "sha256:ab3f...",
  "verification_result": "verified",
  "trust_score": 0.91,
  "mcp_trace_id": "os-id-422"
}
```

Provenance should help answer questions like:

- Which agent produced this output?
- Was the agent's identity verified at the time of the operation?
- What was the agent's trust score when it was delegated this task?
- Has the agent's manifest changed since this operation was recorded?
- Which organization was the agent registered under?

---

## 12. Compatible providers

Representative compatible providers include:

- `opensentience` (primary runtime verification provider)
- `fleetprompt` (registry and trust score computation)
- custom identity and authentication services exposed behind MCP-compatible surfaces
- enterprise agent directory systems with structured manifest verification

### Default ecosystem fit

The most natural default ecosystem pairing is:

- `opensentience` for runtime identity verification
- `fleetprompt` for the agent registry and trust scoring

Why they fit together:
- OpenSentience provides the verification runtime that checks claims against registered manifests
- FleetPrompt maintains the registry and computes trust scores from agent history and attestations
- Together they form the complete identity and trust stack

The protocol stance remains:

> `&govern.identity` is the capability.
> `opensentience` and `fleetprompt` are providers that may satisfy it.

---

## 13. A2A-facing skills

A `&govern.identity` capability may advertise skills such as:

- `agent-identity-verification`
- `manifest-attestation`

These are useful when generating A2A-style agent cards, because they let an external coordination surface say more than "has identity support."

Instead, it can say the agent can:

- verify other agents' identities before collaboration
- attest its own manifest for mutual trust establishment

---

## 14. Anti-patterns

### Anti-pattern 1: assume trust without verification
In multi-agent systems, implicit trust is a security vulnerability. Always verify identity before accepting delegated tasks or sharing results. OS-007 documents the agent impersonation threat this prevents.

### Anti-pattern 2: bind identity to a single runtime
Agent identity should be portable across runtimes and deployments. Tying identity to a specific runtime creates fragile trust relationships that break during migration.

### Anti-pattern 3: skip manifest hashing
The manifest hash is the integrity anchor. Without it, there is no way to detect if an agent's declaration has been modified after registration.

### Anti-pattern 4: ignore trust scores in delegation
Trust scores exist to inform delegation decisions. Delegating sensitive tasks to agents with low or missing trust scores undermines the purpose of the identity system.

### Anti-pattern 5: register once and never update
Agent capabilities and governance policies evolve. Stale identity records create a gap between what the registry says and what the agent actually does.

---

## 15. Summary

`&govern.identity` is the [&] Protocol capability for **cross-runtime agent identity and trust verification**.

It is the right capability when a system needs to:

- establish verifiable agent identity that persists across runtimes
- verify that agents are who they claim to be before collaboration
- link agents to organizations, publishers, and governance policies
- carry trust metadata that informs delegation and escalation decisions
- maintain an auditable registry of all agent identities

In one sentence:

> `&govern.identity` gives agents a protocol-native way to prove who they are and verify who they are working with.

---
