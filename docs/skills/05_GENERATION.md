# Skill 05 — Generation

> Compiling agent declarations into MCP server configurations and A2A agent
> cards. The "from spec to running agent" path.

---

## Why This Matters

Generation is the payoff. A validated, composed `ampersand.json` compiles
into runtime artifacts that existing protocols understand. This is how [&]
complements MCP and A2A without replacing either.

```
ampersand.json → ampersand generate → mcp-config.json + agent-card.json
```

---

## Generating MCP Configuration

### Command

```bash
./ampersand generate mcp agent.ampersand.json
```

### What It Produces

An MCP server configuration that wires up the declared capability providers
as MCP tools and resources:

```json
{
  "mcpServers": {
    "graphonomous": {
      "command": "graphonomous",
      "args": ["--instance", "infra-ops"],
      "transport": "stdio",
      "tools": [
        "store_node", "store_edge", "retrieve_context",
        "topology_analyze", "deliberate"
      ],
      "resources": ["graphonomous://runtime/health"]
    },
    "ticktickclock": {
      "command": "ticktickclock",
      "args": ["--streams", "cpu,mem"],
      "transport": "stdio",
      "tools": ["detect_anomaly", "enrich_context", "learn_observation"]
    },
    "deliberatic": {
      "command": "deliberatic",
      "args": ["--governance", "constitutional"],
      "transport": "stdio",
      "tools": ["evaluate_argument", "structured_vote"]
    }
  }
}
```

### How Capabilities Map to MCP Tools

Each capability's operations become MCP tools:

| Capability | Operations | MCP Tools |
|-----------|-----------|-----------|
| `&memory.graph` | `recall`, `store`, `enrich`, `topology` | `retrieve_context`, `store_node`, `store_edge`, `topology_analyze` |
| `&time.anomaly` | `detect`, `enrich`, `learn` | `detect_anomaly`, `enrich_context`, `learn_observation` |
| `&reason.argument` | `evaluate`, `vote` | `evaluate_argument`, `structured_vote` |
| `&reason.deliberate` | `deliberate`, `decompose`, `reconcile` | `deliberate`, `decompose_topology`, `reconcile_conclusions` |
| `&reason.attend` | `survey`, `triage`, `dispatch` | `attention_survey`, `attention_triage`, `attention_run_cycle` |

The mapping is defined in each capability's contract. The generator reads
the contract and emits the corresponding MCP tool registrations.

---

## Generating A2A Agent Cards

### Command

```bash
./ampersand generate a2a agent.ampersand.json
```

### What It Produces

An A2A agent card suitable for `/.well-known/agent.json`:

```json
{
  "name": "InfraOperator",
  "version": "1.0.0",
  "description": "Infrastructure operations agent with graph memory, temporal anomaly detection, fleet awareness, and deliberative reasoning.",
  "skills": [
    {
      "id": "temporal-anomaly-detection",
      "name": "Temporal Anomaly Detection",
      "description": "Detect anomalous events in temporal data streams.",
      "inputModes": ["application/json"],
      "outputModes": ["application/json"]
    },
    {
      "id": "topology-aware-deliberation",
      "name": "Topology-Aware Deliberation",
      "description": "Focused reasoning through knowledge graph cycles.",
      "inputModes": ["application/json"],
      "outputModes": ["application/json"]
    },
    {
      "id": "fleet-spatial-awareness",
      "name": "Fleet Spatial Awareness",
      "description": "Geospatial fleet tracking and geofence management.",
      "inputModes": ["application/json"],
      "outputModes": ["application/json"]
    }
  ],
  "capabilities": {
    "streaming": false,
    "pushNotifications": false
  }
}
```

### How Capabilities Map to A2A Skills

Each capability contract includes an `a2a_skills` field that defines the
skill identifiers exposed via A2A:

| Capability | `a2a_skills` | A2A Skill Entry |
|-----------|-------------|----------------|
| `&time.anomaly` | `["temporal-anomaly-detection"]` | Temporal anomaly detection skill |
| `&reason.deliberate` | `["topology-aware-deliberation"]` | Deliberation skill |
| `&space.fleet` | `["fleet-spatial-awareness"]` | Fleet tracking skill |

---

## Output Options

### Write to file

```bash
./ampersand generate mcp agent.ampersand.json --output mcp-config.json
./ampersand generate a2a agent.ampersand.json --output agent-card.json
```

### Write to stdout (default)

```bash
./ampersand generate mcp agent.ampersand.json | jq .
```

### Compact output

```bash
./ampersand generate mcp agent.ampersand.json --compact
```

---

## Generation Pipeline

Generation runs after validation and composition. The full sequence:

```
1. Parse ampersand.json
2. Validate against schema (same as `validate`)
3. Compose and check type safety (same as `compose`)
4. Resolve providers from registry
5. Load capability contracts for each provider
6. Map operations → MCP tools or A2A skills
7. Emit output artifact
```

If validation or composition fails, generation aborts with the relevant
errors. You do not need to run `validate` and `compose` separately before
`generate` — the command includes both checks.

---

## Custom Generation

### Provider overrides

Override providers at generation time without modifying the declaration:

```bash
./ampersand generate mcp agent.ampersand.json \
  --provider "&memory.graph=custom-graph-service"
```

### Transport selection

Force a specific MCP transport:

```bash
./ampersand generate mcp agent.ampersand.json --transport http
```

Default is `stdio`.

---

## What Generation Does NOT Do

- It does not start MCP servers or deploy agents
- It does not install provider binaries
- It does not modify the source declaration
- It does not create network connections

Generation produces **configuration artifacts**. Deployment is a separate
concern handled by your runtime infrastructure.
