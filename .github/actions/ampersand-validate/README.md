# Ampersand Validate GitHub Action

This action validates [`ampersand.json`](../../../protocol/schema/v0.1.0/ampersand.schema.json) declarations in CI, composes capability maps, and can optionally run a lightweight pipeline check.

It is intended for pull-request and main-branch gating where declaration correctness must be enforced.

---

## What it does

1. Validates declaration file(s) against the canonical Ampersand schema.
2. Composes declaration capability sets and detects conflicts.
3. Optionally checks a pipeline expression or named pipeline reference.

All results are emitted as structured JSON so you can parse or archive them in CI.

---

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `declaration_path` | yes | — | Path to the declaration file to validate (for example `examples/infra-operator.ampersand.json`). |
| `pipeline` | no | `""` | Optional inline pipeline expression to check. |
| `pipeline_name` | no | `""` | Optional named pipeline to resolve from `declaration_path` (for declarations with `pipelines`). |
| `working_directory` | no | `"."` | Working directory to run CLI commands from. |
| `node_version` | no | `"20"` | Node.js version used for the action runtime. |

---

## Outputs

| Output | Description |
|---|---|
| `validation_result` | JSON output from validation step. |
| `compose_result` | JSON output from compose step. |
| `check_result` | JSON output from optional pipeline check step. |

---

## Usage (same repository)

If this action lives in the same repo, use it via relative path:

```yaml
name: Validate Ampersand Declaration

on:
  pull_request:
    paths:
      - "**/*.ampersand.json"
      - "schema/**"
      - ".github/actions/ampersand-validate/**"

jobs:
  validate-ampersand:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Validate declaration
        id: ampersand
        uses: ./.github/actions/ampersand-validate
        with:
          declaration_path: examples/infra-operator.ampersand.json
          pipeline_name: incident_triage
          working_directory: .
          node_version: "20"

      - name: Print action outputs
        run: |
          echo '${{ steps.ampersand.outputs.validation_result }}'
          echo '${{ steps.ampersand.outputs.compose_result }}'
          echo '${{ steps.ampersand.outputs.check_result }}'
```

---

## Usage (cross-repository)

If published from another repository, reference it by `owner/repo/path@ref`:

```yaml
uses: your-org/AmpersandBoxDesign/.github/actions/ampersand-validate@main
with:
  declaration_path: examples/infra-operator.ampersand.json
```

---

## Example: validate + check an inline pipeline in CI

```yaml
- name: Validate declaration and check inline pipeline
  id: ampersand
  uses: ./.github/actions/ampersand-validate
  with:
    declaration_path: examples/infra-operator.ampersand.json
    pipeline: stream_data |> &time.anomaly.detect() |> &memory.graph.enrich() |> &reason.argument.evaluate()
```

---

## Notes

- This action is designed to produce machine-readable JSON outputs for downstream CI steps.
- For full contract-backed runtime planning/execution, use the Elixir reference implementation in:
  - `reference/elixir/ampersand_core/`
