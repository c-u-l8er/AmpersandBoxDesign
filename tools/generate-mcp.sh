#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CLI_DIR="$REPO_ROOT/reference/elixir/ampersand_core"
CLI_BIN="$CLI_DIR/ampersand"

print_usage() {
  cat <<'EOF'
Usage:
  sh tools/generate-mcp.sh <agent.ampersand.json> [output.json]

Description:
  Generates MCP client configuration JSON from an ampersand declaration.

Examples:
  sh tools/generate-mcp.sh examples/infra-operator.ampersand.json
  sh tools/generate-mcp.sh examples/infra-operator.ampersand.json mcp-config.json
EOF
}

fail() {
  echo "generate-mcp.sh: $*" >&2
  exit 1
}

ensure_cli() {
  [ -d "$CLI_DIR" ] || fail "reference CLI directory not found: $CLI_DIR"

  if [ -x "$CLI_BIN" ]; then
    return 0
  fi

  command -v mix >/dev/null 2>&1 || fail "mix is required to build the ampersand CLI"

  echo "generate-mcp.sh: building ampersand CLI..." >&2
  (
    cd "$CLI_DIR"
    mix escript.build >/dev/null
  ) || fail "failed to build ampersand CLI"

  [ -x "$CLI_BIN" ] || fail "ampersand CLI was not created at $CLI_BIN"
}

resolve_input_path() {
  input_path=$1

  if [ -f "$input_path" ]; then
    (
      cd -- "$(dirname -- "$input_path")"
      pwd
    )/$(basename -- "$input_path")
    return 0
  fi

  if [ -f "$REPO_ROOT/$input_path" ]; then
    echo "$REPO_ROOT/$input_path"
    return 0
  fi

  return 1
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  print_usage
  exit 0
fi

[ $# -ge 1 ] || {
  print_usage >&2
  exit 1
}

[ $# -le 2 ] || fail "too many arguments"

INPUT_ARG=$1
OUTPUT_ARG=${2:-}

INPUT_PATH=$(resolve_input_path "$INPUT_ARG") || fail "input declaration not found: $INPUT_ARG"

ensure_cli

if [ -n "$OUTPUT_ARG" ]; then
  OUTPUT_DIR=$(dirname -- "$OUTPUT_ARG")
  [ -d "$OUTPUT_DIR" ] || fail "output directory does not exist: $OUTPUT_DIR"

  "$CLI_BIN" generate mcp "$INPUT_PATH" >"$OUTPUT_ARG" || fail "MCP generation failed"
  echo "generate-mcp.sh: wrote MCP config to $OUTPUT_ARG" >&2
else
  exec "$CLI_BIN" generate mcp "$INPUT_PATH"
fi
