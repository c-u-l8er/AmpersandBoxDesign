# Report: kernel admission across a real process boundary

## Task

Inspect box-and-box and identify the smallest existing real action that can be
gated by the kernel across an actual process or transport boundary. Report the
exact claim, current evidence, proposed boundary, action, certificate form,
existing commands, and any kernel gap. Do not change protocol surface.

## The claim

**"box-and-box kernel admission governs a real action executed by a different
process."**

- **Old rung:** `in_tree` — the kernel decides and certifies, but only
  in-process (against its own tests, in a single Node.js process).
- **Target rung:** `live_local` — the deciding process (Node.js, `box-and-box
  govern`) and the acting process (Elixir escript, `ampersand validate` or
  `ampersand generate mcp`) are separate OS processes, connected by a shell
  pipeline or script, with the certificate retained to disk.

## Smallest existing real action

**`ampersand generate mcp <agent.json>`** — the Elixir reference CLI generating
an MCP server configuration file from an ampersand declaration. This is a real
action with a real side effect (file creation), performed by a real existing
executable in the repository (`reference/elixir/ampersand_core/ampersand`),
written in a different language (Elixir) running in a different VM (BEAM).

Alternative (even simpler, no side effect): **`ampersand validate <agent.json>`**
— validates the declaration against the canonical schema. This is a read-only
action but it is still a real action by a different process.

## Proposed boundary

```
Process A (decider):  node bin/govern.mjs  (box-and-box, Node.js)
    │  exit code: 0 = decision, 1 = no admissible option, 3 = escalation
    │  stdout: JSON certificate
    ▼
Process B (actor):    ./ampersand generate mcp <agent.json>  (Elixir/BEAM)
    │  runs ONLY if Process A exits 0
    │  does NOT run if Process A exits 1 or 3
```

The boundary is an OS process boundary. The transport is stdin/stdout + exit
codes via shell. No stub, no injected transport, no single-process round-trip.

## Existing commands (all present in the repository today)

1. **Compile governance → govern spec:**
   ```sh
   node box-and-box/bin/compile.mjs examples/infra-operator.ampersand.json \
     --options options.json
   ```
   Translates the `governance` block of an ampersand.json into a box-and-box
   govern-ready spec (req + norms + options).

2. **Decide (emit certificate):**
   ```sh
   node box-and-box/bin/govern.mjs decision-spec.json
   ```
   Runs the full alethic → deontic → axiological bridge. Exit 0 with certificate
   on stdout if a decision is made.

3. **Act (real action by different process):**
   ```sh
   ./reference/elixir/ampersand_core/ampersand generate mcp examples/infra-operator.ampersand.json
   ```
   Elixir escript, separate OS process, produces MCP configuration JSON.

4. **Gated composition (the integration):**
   ```sh
   # Decide, retain certificate, conditionally act
   cert=$(node box-and-box/bin/govern.mjs decision-spec.json 2>/dev/null)
   if [ $? -eq 0 ]; then
     echo "$cert" > certificate.json
     ./reference/elixir/ampersand_core/ampersand generate mcp examples/infra-operator.ampersand.json
   else
     echo "Kernel refused — action not performed"
     echo "$cert" > certificate-refused.json
   fi
   ```

## Certificate form

The certificate is the JSON object emitted by `box-and-box govern` on stdout.
It includes:

```json
{
  "decision": "generate-mcp",
  "forcedByObligation": false,
  "escalation": null,
  "margin": null,
  "semiring": "tropical",
  "ranking": [{"id": "generate-mcp", "score": 5, "status": "optional"}],
  "deonticallyVetoed": [],
  "alethicallyVetoed": [],
  "layers": ["alethic", "deontic", "axiological"],
  "note": "..."
}
```

For a refusing verdict (exit 1 or 3), the certificate still contains the full
reasoning: which options were alethically vetoed, which were deontically
forbidden, whether escalation is required and why.

The certificate is retained outside the deciding process by redirecting stdout to
a file. It is traceable to the attempted action because the decision spec names
the action and the certificate names the decision.

## What already works (verified)

- `node box-and-box/bin/govern.mjs` reads a decision spec, runs the full
  eight-rung bridge, emits a certificate, exits with the correct code. **Tested.**
- `node box-and-box/bin/compile.mjs` translates an ampersand.json governance
  block into a govern-ready spec. **Tested.**
- `./reference/elixir/ampersand_core/ampersand validate` and `generate mcp`
  are working executables. **Tested.**
- All 129 laws pass: 103 core + 13 compose + 13 coalition. **Tested.**
- Exit codes are correct: 0 for decision, 1 for no admissible option, 2 for
  usage error, 3 for escalation.

## Kernel gaps (findings, not features)

1. **No built-in action-gating harness.** The kernel emits a certificate and an
   exit code, but has no concept of "then run this other process." The
   composition must be done by the caller (a shell script, a CI step, an
   orchestrator). This is arguably correct — the kernel's job is to decide, not
   to execute — but it means the `live_local` evidence requires a thin
   integration script that is not part of the kernel package.

2. **Certificate does not name the gated action.** The certificate's `decision`
   field names the winning option ID (e.g., `"generate-mcp"`), which is chosen
   by the caller in the decision spec. There is no structured field for "the
   process that will be invoked if this verdict permits." The traceability
   between certificate and action depends on the caller's naming convention,
   not on a schema-enforced link. This is a gap in auditability but NOT a
   missing protocol field — adding one would be new protocol surface.

3. **No certificate signing or tamper-evidence.** The certificate is plain JSON.
   Nothing prevents the acting process (or a man-in-the-middle) from fabricating
   a permitting certificate. The `evolution.mjs` module has hash-linked
   provenance chains, but `govern` does not produce one. The coalition runtime
   (`coalition.mjs`) does produce provenance records when `provenance: true` is
   set. This is an existing gap between the `govern` and `coalition` code paths,
   not a missing feature to add.

4. **`compile --options` is the only way to build a complete govern spec from
   an ampersand.json.** The options (the candidate actions with their values and
   utilities) must be supplied separately. There is no mechanism to derive
   options from the ampersand.json itself — the governance block says what
   constraints apply, not what actions are available. This is by design (the
   kernel does not enumerate actions), but it means the integration script must
   construct the options array.

## What remains to advance from `in_tree` to `live_local`

A single shell script (or test) that:
1. Constructs a decision spec with at least two options (one that should be
   permitted, one that should be refused).
2. Calls `box-and-box govern` as Process A.
3. Captures the certificate and exit code.
4. Calls `ampersand generate mcp` (or `validate`) as Process B only on exit 0.
5. Demonstrates that Process B does NOT run on a refusing verdict.
6. Retains both certificates (permit and refuse) to files.

This script does not exist yet. Building it is the next worker's task.

DOCTRINE:

**proposed** — The claim "box-and-box kernel admission governs a real action
executed by a different process" can be advanced from `in_tree` to `live_local`
using existing commands (`box-and-box govern` + `ampersand generate mcp`) across
an OS process boundary, with certificate retention via stdout capture. The
integration requires a thin shell script that is not yet written. The kernel has
no gap that blocks this; the four findings above are auditability improvements,
not blockers. What would test this: a shell script that runs both the permit and
refuse paths, retains both certificates, and is repeatable by `sh
test/integration/kernel-gates-action.sh`.
