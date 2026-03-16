# Runtime Walkthrough

This page shows what happens when a runtime processes an [`ampersand.json`](architecture.md#declaration-architecture) declaration from start to finish.

The goal is to make the protocol operational, not just conceptual.

It answers practical questions such as:

- what gets validated first
- what gets normalized during composition
- when providers are resolved
- how governance and provenance are preserved
- what generation into MCP and A2A artifacts looks like
- what a failure looks like in CLI output

---

## 1. What this walkthrough is

This is a **reference workflow** for an implementation of the [&] Protocol.

It is not a requirement that every runtime use the same CLI syntax or internal module layout.  
It **is** the intended lifecycle of the protocol:

1. declaration
2. validation
3. composition
4. contract checking
5. provider resolution
6. generation
7. execution-time provenance emission

In short:

> declaration → validation → composition → resolution → generation

---

## 2. A minimal declaration

Consider an infrastructure operations agent that needs:

- graph-backed recall of prior incidents
- anomaly detection over telemetry
- fleet localization
- argument-based reasoning under governance constraints

A declaration may look like this:

```json
{
  "$schema": "https://protocol.ampersandboxdesign.com/v0.1/ampersand.schema.json",
  "agent": "infra-ops",
  "version": "0.1.0",
  "capabilities": {
    "&memory.graph": {
      "provider": "graphonomous",
      "config": {
        "instance": "infra-ops"
      }
    },
    "&time.anomaly": {
      "provider": "ticktickclock",
      "config": {
        "streams": ["cpu", "mem", "latency"]
      }
    },
    "&space.fleet": {
      "provider": "geofleetic",
      "config": {
        "regions": ["us-east-1", "us-west-2", "eu-central-1"]
      }
    },
    "&reason.argument": {
      "provider": "deliberatic",
      "config": {
        "governance": "constitutional"
      }
    }
  },
  "governance": {
    "hard": [
      "do_not_recommend_destructive_action_without_human_review"
    ],
    "soft": [
      "prefer_reversible_remediation"
    ],
    "escalate_when": [
      "confidence_below:0.75",
      "cross_region_impact=true"
    ]
  },
  "provenance": {
    "mode": "hash-linked"
  }
}
```

### What the runtime sees immediately

Before doing any execution, a runtime can already infer:

- the declaration targets one agent: `infra-ops`
- four capability bindings are requested
- provider identity is explicit rather than automatic
- governance must survive the rest of the lifecycle
- provenance is expected to be preserved in a hash-linked form

---

## 3. Step 1: schema validation

The first step is structural validation.

A CLI might expose that as:

```text
$ ampersand validate examples/infra-ops.ampersand.json
✔ schema valid
✔ agent id present
✔ version present
✔ capabilities object valid
✔ governance object valid
✔ provenance object valid
```

At this stage the runtime is checking things like:

- required top-level fields exist
- the capabilities object is well-formed
- each capability entry matches the declaration schema
- governance and provenance fields have valid shapes

### What validation does not do yet

Schema validation alone does **not** answer:

- whether the chosen provider really supports the capability
- whether capability combinations are semantically compatible
- whether a pipeline between operations is type-safe
- whether a provider can actually be launched in a target runtime

It only establishes that the declaration is structurally well-formed.

---

## 4. Step 2: normalization and composition

After schema validation, the runtime normalizes the capability set.

This is where the protocol’s set-like semantics matter.

### What normalization typically does

A runtime may:

- canonicalize capability keys
- normalize provider binding objects
- sort capabilities into a stable internal order
- collapse exact duplicates
- surface incompatible duplicate bindings as conflicts

For the declaration above, the normalized internal shape may be represented like this:

```json
{
  "agent": "infra-ops",
  "version": "0.1.0",
  "capabilities": [
    {
      "id": "&memory.graph",
      "provider": "graphonomous",
      "config": {
        "instance": "infra-ops"
      }
    },
    {
      "id": "&reason.argument",
      "provider": "deliberatic",
      "config": {
        "governance": "constitutional"
      }
    },
    {
      "id": "&space.fleet",
      "provider": "geofleetic",
      "config": {
        "regions": ["us-east-1", "us-west-2", "eu-central-1"]
      }
    },
    {
      "id": "&time.anomaly",
      "provider": "ticktickclock",
      "config": {
        "streams": ["cpu", "mem", "latency"]
      }
    }
  ],
  "governance": {
    "hard": [
      "do_not_recommend_destructive_action_without_human_review"
    ],
    "soft": [
      "prefer_reversible_remediation"
    ],
    "escalate_when": [
      "confidence_below:0.75",
      "cross_region_impact=true"
    ]
  },
  "provenance": {
    "mode": "hash-linked"
  }
}
```

The exact representation is runtime-specific.  
The important point is that composition produces a **deterministic, normalized capability graph**.

### Example CLI output

```text
$ ampersand compose examples/infra-ops.ampersand.json
✔ normalized 4 capabilities
✔ no duplicate bindings
✔ no provider conflicts
✔ governance preserved
✔ provenance mode preserved
```

---

## 5. Step 3: contract checking

Once the declaration is normalized, the runtime can check capability contracts.

This is where the protocol moves from “well-shaped JSON” to “valid composition.”

A runtime may verify:

- the capability subtype exists in a known registry
- the bound provider claims support for that subtype
- required operations are available
- declared or inferred pipelines are type-compatible
- adjacency rules such as `accepts_from` and `feeds_into` are satisfied

### Conceptual pipeline

A common operational path for this agent might be:

```text
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &space.fleet.enrich()
|> &reason.argument.evaluate()
```

Important: `|>` is used in the docs as a **conceptual pipeline notation**.  
It expresses ordered flow between capability operations.  
It is not, by itself, a required wire format for the protocol and it is not required to be literal CLI syntax.

### What the runtime checks

For that pipeline, the runtime asks:

1. does `&time.anomaly` support `detect`
2. does `detect` emit a type that `&memory.graph.enrich` accepts
3. does `&memory.graph.enrich` emit a type that `&space.fleet.enrich` accepts
4. does `&space.fleet.enrich` emit a type that `&reason.argument.evaluate` accepts
5. do the adjacency rules permit each transition

### Example success output

```text
$ ampersand check examples/infra-ops.ampersand.json --pipeline infra_ops
✔ capability contracts loaded
✔ provider support metadata loaded
✔ &time.anomaly.detect -> &memory.graph.enrich valid
✔ &memory.graph.enrich -> &space.fleet.enrich valid
✔ &space.fleet.enrich -> &reason.argument.evaluate valid
✔ pipeline infra_ops is contract-safe
```

At this point the runtime knows that the declaration is not only valid in shape, but also meaningful as a composed system.

---

## 6. Step 4: provider resolution

Provider resolution answers:

> Which implementation actually satisfies each declared capability?

There are two common cases.

### Explicit provider binding

In the example declaration, every capability names a provider directly:

- `&memory.graph` → `graphonomous`
- `&time.anomaly` → `ticktickclock`
- `&space.fleet` → `geofleetic`
- `&reason.argument` → `deliberatic`

In that case, resolution is mostly verification:

- is the provider known
- does the provider advertise support for this subtype
- are launch details or integration details available

### Automatic provider resolution

If a declaration uses `provider: "auto"`, a runtime would consult a registry and select a provider that satisfies the requested capability and constraints.

For example:

```json
{
  "&memory.graph": {
    "provider": "auto",
    "need": "relationship-aware incident recall"
  }
}
```

A runtime might then produce:

```text
$ ampersand resolve examples/infra-ops-auto.ampersand.json
✔ found 2 candidate providers for &memory.graph
✔ selected graphonomous
  reason: supports &memory.graph, mcp_v1 transport metadata present, graph recall operations available
```

### About provider names in the docs

Provider names such as `graphonomous`, `deliberatic`, `ticktickclock`, and `geofleetic` are used throughout this documentation as **illustrative example providers unless explicitly stated otherwise**.

Their purpose is to make capability/provider separation concrete in examples.  
They should not be read as a guarantee that those providers currently exist as public implementations.

---

## 7. Step 5: generation into downstream artifacts

After validation, composition, and provider resolution, the runtime can compile the declaration into downstream artifacts.

This is where the protocol becomes operational.

## 7.1 MCP generation

A generator may emit an MCP-oriented configuration that groups capability bindings by provider and preserves enough provider information for a tool-facing runtime.

An illustrative generated artifact might look like this:

```json
{
  "mcpServers": {
    "graphonomous": {
      "transport": "stdio",
      "command": "graphonomous-mcp",
      "args": ["serve", "--instance", "infra-ops"]
    },
    "ticktickclock": {
      "transport": "stdio",
      "command": "ticktickclock-mcp",
      "args": ["serve", "--streams", "cpu,mem,latency"]
    },
    "geofleetic": {
      "transport": "stdio",
      "command": "geofleetic-mcp",
      "args": ["serve", "--regions", "us-east-1,us-west-2,eu-central-1"]
    },
    "deliberatic": {
      "transport": "stdio",
      "command": "deliberatic-mcp",
      "args": ["serve", "--governance", "constitutional"]
    }
  }
}
```

A CLI could report:

```text
$ ampersand generate mcp examples/infra-ops.ampersand.json -o build/mcp.json
✔ generated MCP configuration
✔ 4 provider entries emitted
✔ unresolved providers: 0
```

### Important constraint

A generator should only emit details that are actually known from the runtime or registry metadata.  
If launch details are unknown, the artifact should preserve that explicitly instead of inventing them.

For example:

```json
{
  "mcpServers": {
    "graphonomous": {
      "transport": "unknown",
      "status": "unresolved-launch-details"
    }
  }
}
```

## 7.2 A2A generation

A generator may also emit an A2A-style coordination artifact or agent card.

An illustrative output could look like this:

```json
{
  "agent": {
    "id": "infra-ops",
    "version": "0.1.0",
    "skills": [
      "memory.graph.recall",
      "memory.graph.enrich",
      "time.anomaly.detect",
      "space.fleet.enrich",
      "reason.argument.evaluate"
    ],
    "capabilities": [
      "&memory.graph",
      "&time.anomaly",
      "&space.fleet",
      "&reason.argument"
    ],
    "governance": {
      "hard": [
        "do_not_recommend_destructive_action_without_human_review"
      ],
      "soft": [
        "prefer_reversible_remediation"
      ],
      "escalate_when": [
        "confidence_below:0.75",
        "cross_region_impact=true"
      ]
    },
    "provenance": {
      "mode": "hash-linked"
    }
  }
}
```

And the CLI might show:

```text
$ ampersand generate a2a examples/infra-ops.ampersand.json -o build/agent-card.json
✔ generated A2A artifact
✔ 5 skills published
✔ governance metadata preserved
✔ provenance metadata preserved
```

---

## 8. Step 6: runtime execution and provenance emission

The protocol compiles declarations into downstream artifacts, but provenance becomes visible during execution.

Suppose telemetry enters the system and the runtime executes the conceptual pipeline:

```text
stream_data
|> &time.anomaly.detect()
|> &memory.graph.enrich()
|> &space.fleet.enrich()
|> &reason.argument.evaluate()
```

A provenance-aware runtime may emit records like:

```json
[
  {
    "source": "&time.anomaly",
    "provider": "ticktickclock",
    "operation": "detect",
    "timestamp": "2026-03-14T14:23:07Z",
    "input_hash": "sha256:1111aaaa",
    "output_hash": "sha256:2222bbbb",
    "parent_hash": null
  },
  {
    "source": "&memory.graph",
    "provider": "graphonomous",
    "operation": "enrich",
    "timestamp": "2026-03-14T14:23:08Z",
    "input_hash": "sha256:2222bbbb",
    "output_hash": "sha256:3333cccc",
    "parent_hash": "sha256:2222bbbb"
  },
  {
    "source": "&space.fleet",
    "provider": "geofleetic",
    "operation": "enrich",
    "timestamp": "2026-03-14T14:23:09Z",
    "input_hash": "sha256:3333cccc",
    "output_hash": "sha256:4444dddd",
    "parent_hash": "sha256:3333cccc"
  },
  {
    "source": "&reason.argument",
    "provider": "deliberatic",
    "operation": "evaluate",
    "timestamp": "2026-03-14T14:23:10Z",
    "input_hash": "sha256:4444dddd",
    "output_hash": "sha256:5555eeee",
    "parent_hash": "sha256:4444dddd"
  }
]
```

This is why provenance is treated as a protocol concern rather than as optional logging.

The declaration asked for provenance preservation.  
The runtime is now honoring that requirement at execution time.

---

## 9. What failure looks like

A useful walkthrough needs at least one failing example.

Consider this invalid pipeline:

```text
stream_data
|> &time.anomaly.detect()
|> &reason.argument.evaluate()
|> &memory.graph.enrich()
```

Assume:

- `&time.anomaly.detect` outputs `anomaly_event`
- `&reason.argument.evaluate` outputs `decision_record`
- `&memory.graph.enrich` expects `incident_context` or `memory_context`

The transition from `&reason.argument.evaluate` to `&memory.graph.enrich` may then be invalid.

### Example failure output

```text
$ ampersand check examples/infra-ops-bad.ampersand.json --pipeline infra_ops_bad
✔ capability contracts loaded
✔ &time.anomaly.detect -> &reason.argument.evaluate valid
✖ &reason.argument.evaluate -> &memory.graph.enrich invalid

reason:
  output type "decision_record" is not accepted by &memory.graph.enrich
  allowed input types: ["incident_context", "memory_context"]

exit status: 1
```

That kind of failure is exactly why the composition layer exists.  
The protocol allows the runtime to reject bad compositions before they become runtime bugs.

---

## 10. What governance does during runtime processing

Governance is declared early, but it influences more than one stage.

### During validation

The runtime checks that governance fields are well-formed.

### During generation

The runtime preserves governance metadata in generated artifacts so that downstream systems know what constraints travel with the agent.

### During execution

The runtime or provider may enforce the declared constraints.

For the example declaration, a decision flow might produce:

```text
$ ampersnad run examples/infra-ops.ampersand.json --input sample-event.json
…
! escalation triggered
  reason: cross_region_impact=true
  action: require_human_review
```

The protocol does not require one universal enforcement engine.  
It requires governance intent to be **declared portably** so runtimes can preserve and apply it consistently.

---

## 11. Reference lifecycle summary

A compliant implementation should be understandable in terms of the following lifecycle:

### Phase A: parse and validate
- read `ampersand.json`
- validate against the declaration schema
- reject malformed declarations

### Phase B: normalize and compose
- canonicalize capability bindings
- collapse exact duplicates
- surface conflicts explicitly
- preserve governance and provenance metadata

### Phase C: check semantics
- load contracts
- load registry or provider support metadata
- verify subtype support
- verify pipeline compatibility when applicable

### Phase D: resolve providers
- confirm explicit providers
- or select providers for `provider: "auto"`

### Phase E: generate artifacts
- emit MCP configuration
- emit A2A coordination artifacts
- preserve unresolved details explicitly when they are unknown

### Phase F: execute with lineage
- run capability operations in the target runtime
- emit provenance records according to the declaration
- enforce or surface governance constraints

---

## 12. What is normative and what is illustrative

This page includes both protocol expectations and implementation examples.

### Normative at the protocol level
These ideas are central to the protocol model:

- declarations are validated before generation
- capability composition is distinct from execution
- provider identity is separate from capability identity
- contracts make composition checkable
- governance and provenance travel with the declaration
- downstream artifacts can be generated from a validated declaration

### Illustrative in this page
These details are examples rather than mandatory:

- the exact CLI command names
- the exact terminal output format
- the internal normalized JSON shape
- the specific provider names used in examples
- the exact generated MCP command lines

That distinction matters.  
The protocol defines the lifecycle and artifact roles, not one single implementation UX.

---

## 13. Why this walkthrough matters

The most important idea in the protocol is not just that an agent can *declare* capabilities.

It is that a declaration can be:

- validated
- normalized
- checked
- resolved
- compiled
- executed with lineage preserved

Without that lifecycle, `ampersand.json` would be only documentation.  
With that lifecycle, it becomes an operational source of truth for agent composition.

---

## 14. Short summary

A runtime processing the [&] Protocol should be understandable as:

1. **validate the declaration**
2. **normalize the capability set**
3. **check contracts and pipeline compatibility**
4. **resolve providers**
5. **generate MCP and A2A artifacts**
6. **emit provenance and apply governance during execution**

That is how the protocol moves from architecture description to runtime behavior.
