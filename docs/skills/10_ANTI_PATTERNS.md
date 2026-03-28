# Skill 10 — Anti-Patterns

> Common mistakes when writing [&] Protocol declarations and how to avoid
> them. Every anti-pattern here comes from real failure modes: broken
> compositions, unenforceable governance, unportable agents, and silent
> pipeline failures.

---

## Overview

Each anti-pattern follows this structure:

1. **The mistake** — what it looks like
2. **Why it's harmful** — the concrete damage
3. **The fix** — what to do instead

---

## Table of Anti-Patterns

| # | Name | Severity |
|---|------|----------|
| 1 | [Capabilities Without Providers](#1--capabilities-without-providers) | Critical |
| 2 | [Ignoring Composition Type Checks](#2--ignoring-composition-type-checks) | Critical |
| 3 | [Kitchen-Sink Declarations](#3--kitchen-sink-declarations) | High |
| 4 | [Missing Provenance on Critical Capabilities](#4--missing-provenance-on-critical-capabilities) | High |
| 5 | [Governance Gaps](#5--governance-gaps) | High |
| 6 | [Over-Specifying Providers](#6--over-specifying-providers) | Medium |
| 7 | [Ignoring Contract Versioning](#7--ignoring-contract-versioning) | Medium |
| 8 | [Pipeline Without Validation](#8--pipeline-without-validation) | Medium |
| 9 | [Bare Primitive References](#9--bare-primitive-references) | Low |
| 10 | [Copy-Paste Governance](#10--copy-paste-governance) | Low |

---

## Critical Anti-Patterns

---

### 1 — Capabilities Without Providers

**The mistake:** Declaring capabilities but omitting or leaving blank the
provider field.

```json
"capabilities": {
  "&memory.graph": { "config": { "instance": "ops" } },
  "&time.anomaly": { "provider": "", "config": {} }
}
```

**Why it's harmful:**
- The runtime cannot bind the capability to any service
- Generation produces empty MCP server entries
- The agent appears to have capabilities it cannot actually use
- Composition passes but generation fails silently or produces broken output

**The fix:** Always specify a provider. Use `"auto"` if you want the runtime
to resolve it from the registry:

```json
"&memory.graph": { "provider": "graphonomous", "config": { "instance": "ops" } }
"&time.anomaly": { "provider": "auto", "config": {} }
```

---

### 2 — Ignoring Composition Type Checks

**The mistake:** Building pipelines without verifying that step N's output
type matches step N+1's `accepts_from` list.

```json
"steps": [
  { "capability": "&time.forecast", "operation": "predict" },
  { "capability": "&memory.graph", "operation": "enrich" }
]
```

If `&time.forecast.predict()` outputs `forecast_set` but `&memory.graph.enrich()`
does not accept `forecast_set`, the pipeline breaks at runtime.

**Why it's harmful:**
- Runtime errors instead of compile-time errors
- Silent data loss or unexpected behavior
- Difficult to debug in production

**The fix:** Run `ampersand compose` before `ampersand generate`. Always
check the type flow:

```bash
ampersand compose agent.ampersand.json --verbose
```

The verbose output shows the type at each pipeline step, making mismatches
immediately visible.

---

## High-Severity Anti-Patterns

---

### 3 — Kitchen-Sink Declarations

**The mistake:** Declaring every available capability even when the agent
does not need most of them.

```json
"capabilities": {
  "&memory.graph": { ... },
  "&memory.vector": { ... },
  "&memory.episodic": { ... },
  "&memory.semantic": { ... },
  "&time.anomaly": { ... },
  "&time.forecast": { ... },
  "&time.pattern": { ... },
  "&time.baseline": { ... },
  "&space.fleet": { ... },
  "&space.geofence": { ... },
  "&reason.argument": { ... },
  "&reason.vote": { ... },
  "&reason.plan": { ... },
  "&reason.deliberate": { ... },
  "&reason.attend": { ... }
}
```

**Why it's harmful:**
- Generated MCP config starts 8+ servers, most unused
- A2A agent card advertises skills the agent cannot meaningfully perform
- More providers means more failure points
- Harder to reason about what the agent actually does

**The fix:** Start with the minimum set of capabilities your use case
requires. Add more only when a concrete need emerges:

```json
"capabilities": {
  "&memory.graph":    { "provider": "graphonomous", "config": {} },
  "&time.anomaly":    { "provider": "ticktickclock", "config": {} },
  "&reason.argument": { "provider": "deliberatic", "config": {} }
}
```

Three capabilities that work together is better than fifteen that sit idle.

---

### 4 — Missing Provenance on Critical Capabilities

**The mistake:** Omitting `"provenance": true` on agents that make
consequential decisions.

**Why it's harmful:**
- No audit trail for decisions
- Cannot trace which capability contributed to an outcome
- Compliance requirements cannot be verified
- Debugging production issues requires reproducing the full pipeline

**The fix:** Enable provenance on any agent that makes decisions affecting
users, infrastructure, or finances:

```json
"provenance": true
```

The overhead is minimal — a hash computation per operation. The value is
significant — a complete, verifiable decision trail.

---

### 5 — Governance Gaps

**The mistake:** Declaring autonomous agents without escalation rules or
hard constraints.

```json
"governance": {
  "autonomy": { "level": "act" }
}
```

**Why it's harmful:**
- The agent has full autonomy with no guardrails
- No mechanism to stop it from taking harmful actions
- No escalation path when confidence is low
- Violates the principle that autonomy requires governance

**The fix:** Every `act`-level agent needs hard constraints and escalation:

```json
"governance": {
  "hard": ["Never exceed budget allocation"],
  "escalate_when": { "confidence_below": 0.6 },
  "autonomy": {
    "level": "act",
    "budget": { "max_actions_per_hour": 10 }
  }
}
```

The higher the autonomy, the more governance is required.

---

## Medium-Severity Anti-Patterns

---

### 6 — Over-Specifying Providers

**The mistake:** Hardcoding specific provider names when the agent could
work with any conforming provider.

```json
"&memory.graph": { "provider": "graphonomous", "config": {} }
```

**Why it's harmful (when portability matters):**
- Locks the agent to a specific provider
- Cannot swap to an alternative without modifying the declaration
- Reduces adoption — users without access to that provider cannot use the agent

**The fix:** Use `"auto"` for capabilities where the specific provider does
not matter, and explicit providers only when provider-specific features are
required:

```json
"&memory.graph": { "provider": "auto", "config": { "index": "docs" } }
```

Note: This is only an anti-pattern when portability is a goal. For internal
agents with known infrastructure, explicit providers are fine.

---

### 7 — Ignoring Contract Versioning

**The mistake:** Never specifying which contract version a declaration was
built against.

**Why it's harmful:**
- A provider updates its contract, breaking your pipeline
- No way to pin to a known-working version
- Composition may pass today and fail tomorrow

**The fix:** Pin your declarations to specific contract versions and test
against them in CI:

```bash
ampersand validate agent.ampersand.json --schema protocol/schema/v0.1.0/
```

When upgrading, review the contract changelog for breaking changes.

---

### 8 — Pipeline Without Validation

**The mistake:** Defining pipelines in the declaration but only running
`validate` (schema check) and never `compose` (type check).

**Why it's harmful:**
- `validate` checks structure, not semantics
- A structurally valid pipeline can have type mismatches
- Errors surface at generation or runtime instead of composition time

**The fix:** Always run `compose` after `validate`:

```bash
ampersand validate agent.ampersand.json && ampersand compose agent.ampersand.json
```

Or just run `generate`, which includes both checks.

---

## Low-Severity Anti-Patterns

---

### 9 — Bare Primitive References

**The mistake:** Using `&memory` instead of `&memory.graph` in discussions,
documentation, or (attempted) declarations.

**Why it's harmful:**
- Declarations require subtypes — `&memory` alone is not valid
- Creates ambiguity about which specific capability is meant
- New users may think bare primitives work and get confused by errors

**The fix:** Always use the full `&primitive.subtype` form:

```
&memory.graph    (not &memory)
&reason.argument (not &reason)
&time.anomaly    (not &time)
&space.fleet     (not &space)
```

---

### 10 — Copy-Paste Governance

**The mistake:** Copying governance blocks from examples without adapting
them to the agent's actual requirements.

**Why it's harmful:**
- Constraints may be too loose or too strict for the use case
- Escalation thresholds may not match operational reality
- Budget limits may be inappropriate
- Creates a false sense of security

**The fix:** Write governance constraints specific to your agent's domain,
risk profile, and operational context. Use examples as templates, not
as final answers.

---

## Self-Audit Checklist

Run through this before deploying an agent declaration:

### Declaration
- [ ] Every capability has an explicit provider (or `"auto"`)
- [ ] Agent name and version are set
- [ ] Only needed capabilities are declared

### Composition
- [ ] `ampersand compose` passes with no errors
- [ ] Pipeline type flow is verified (use `--verbose`)
- [ ] No circular pipeline dependencies

### Governance
- [ ] Hard constraints cover critical boundaries
- [ ] Escalation triggers are set for autonomous agents
- [ ] Autonomy level matches operational trust level
- [ ] Budget limits are appropriate

### Provenance
- [ ] `provenance: true` for agents making consequential decisions
- [ ] Audit trail requirements are met

### Portability
- [ ] Providers are explicit only when provider-specific features are needed
- [ ] Contract versions are pinned for production agents
