# Skill 08 — Provider Implementation

> How to build a provider that satisfies a [&] Protocol capability contract.
> Registration, conformance testing, and MCP transport binding.

---

## Why This Matters

Capabilities are interfaces. Providers are implementations. The protocol is
only as useful as the providers that satisfy its contracts. This file teaches
you how to build one.

---

## The Provider Concept

A provider is a service that implements one or more capability contracts. The
[&] Protocol ecosystem includes default providers:

| Provider | Capabilities Provided |
|----------|----------------------|
| Graphonomous | `&memory.graph`, `&memory.episodic`, `&reason.deliberate`, `&reason.attend` |
| TickTickClock | `&time.anomaly`, `&time.forecast`, `&time.pattern`, `&time.baseline` |
| GeoFleetic | `&space.fleet`, `&space.geofence`, `&space.route`, `&space.region` |
| Deliberatic | `&reason.argument`, `&reason.vote` |

But any MCP-compatible service can be a provider. The protocol is
provider-agnostic by design.

---

## Contract Conformance Requirements

To satisfy a capability contract, a provider MUST:

### 1. Implement all declared operations

If the contract for `&time.anomaly` declares `detect`, `enrich`, and `learn`
operations, the provider must implement all three.

### 2. Accept the declared input types

Each operation specifies an `in` type. The provider must accept data
conforming to that type.

### 3. Produce the declared output types

Each operation specifies an `out` type. The provider must return data
conforming to that type.

### 4. Respect accepts_from / feeds_into

The provider must accept input from the types listed in `accepts_from` and
produce output consumable by the types in `feeds_into`.

### 5. Expose operations via MCP transport

Operations are invoked as MCP tools. The provider must respond to MCP
tool calls over stdio or HTTP transport.

---

## MCP Transport Binding

Providers expose their operations as MCP tools. The binding maps contract
operations to MCP tool names:

```
Contract operation    →    MCP tool name
─────────────────────────────────────────
detect                →    detect_anomaly
enrich                →    enrich_context
learn                 →    learn_observation
```

### Tool registration

When the provider starts as an MCP server, it registers tools that correspond
to its contract operations:

```json
{
  "tools": [
    {
      "name": "detect_anomaly",
      "description": "Detect anomalous events in temporal data streams.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "data": { "type": "array", "items": { "type": "number" } },
          "streams": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["data"]
      }
    }
  ]
}
```

### Resource registration (optional)

Providers can also expose MCP resources for read-only state inspection:

```json
{
  "resources": [
    {
      "uri": "provider://runtime/health",
      "name": "Provider Health",
      "description": "Runtime health status"
    }
  ]
}
```

---

## Provider Registration

To make a provider discoverable, register it in the capability registry.

### Registry entry format

```json
{
  "provider": "my-time-provider",
  "version": "0.1.0",
  "capabilities": ["&time.anomaly", "&time.forecast"],
  "transport": "stdio",
  "command": "my-time-provider",
  "contracts": [
    "contracts/v0.1.0/time.anomaly.contract.json",
    "contracts/v0.1.0/time.forecast.contract.json"
  ],
  "homepage": "https://github.com/org/my-time-provider"
}
```

The registry is used by `provider: "auto"` resolution and by the `compose`
command to verify that providers exist.

---

## Testing Provider Conformance

### Contract validation

Verify that your provider's MCP tool surface matches the declared contract:

```bash
# List your provider's tools
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | my-provider

# Compare against the contract
ampersand validate-provider \
  --provider my-time-provider \
  --contract contracts/v0.1.0/time.anomaly.contract.json
```

### Integration testing

Test that each operation accepts the declared input type and produces the
declared output type:

| Test | What to verify |
|------|---------------|
| Input acceptance | Send each `in` type; verify no error |
| Output shape | Verify output matches `out` type |
| Wildcard compatibility | Send output from `&memory.*` provider; verify acceptance |
| Error handling | Send invalid input; verify graceful error response |
| Side effects | Verify `side_effects: true` operations modify state |
| Idempotency | Verify `side_effects: false` operations are safe to retry |

---

## Common Implementation Patterns

### Pattern 1: Thin MCP wrapper

Wrap an existing service (database, API, ML model) in an MCP server that
maps contract operations to service calls:

```
MCP tool call → Provider → Existing service → Response → MCP result
```

This is the simplest approach. Graphonomous wraps an Elixir/OTP application.
A pgvector provider would wrap PostgreSQL.

### Pattern 2: Multi-capability provider

A single provider can satisfy multiple contracts. Graphonomous provides
`&memory.graph`, `&memory.episodic`, `&reason.deliberate`, and
`&reason.attend` — all from one MCP server.

Register each capability separately in the contract, but serve them from
one process.

### Pattern 3: Stateless operation provider

Some capabilities are stateless — they transform input without maintaining
state. These are simpler to implement and test:

```
Input → Transform → Output (no state)
```

The `deterministic: true` flag in the contract signals this pattern.

### Pattern 4: Provider with feedback loop

Providers with `learn` operations accept outcome feedback and improve over
time. This requires persistent state:

```
Input → Process → Output
                  ↓
          Feedback → State update
```

Mark these operations with `side_effects: true` in the contract.

---

## Checklist: Shipping a New Provider

1. Choose which capability contracts to satisfy
2. Implement all operations declared in each contract
3. Build an MCP server that exposes operations as tools
4. Write a registry entry for discoverability
5. Test conformance against the contract schemas
6. Publish the provider (npm, hex, crates.io, or standalone binary)
7. Submit a PR to add your provider to the registry
