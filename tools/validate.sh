#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REFERENCE_DIR="$PROJECT_ROOT/reference/elixir/ampersand_core"
ESCRIPT_PATH="$REFERENCE_DIR/ampersand"

usage() {
  cat <<'EOF'
Usage:
  sh tools/validate.sh <agent.ampersand.json> [more files...]

Description:
  Validates one or more ampersand agent declarations against the canonical
  protocol schema using the Elixir reference implementation.

Examples:
  sh tools/validate.sh examples/infra-operator.ampersand.json
  sh tools/validate.sh examples/*.ampersand.json
EOF
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_reference_dir() {
  [ -d "$REFERENCE_DIR" ] || fail "Reference implementation not found: $REFERENCE_DIR"
}

build_escript_if_needed() {
  if [ -x "$ESCRIPT_PATH" ]; then
    return 0
  fi

  command -v mix >/dev/null 2>&1 || fail "mix is required to build the ampersand CLI"

  printf '%s\n' "Building ampersand CLI..." >&2
  (
    cd "$REFERENCE_DIR"
    mix escript.build >/dev/null
  ) || fail "Failed to build ampersand CLI"
}

absolute_path() {
  input_path=$1

  if [ -d "$input_path" ]; then
    fail "Expected a file, got directory: $input_path"
  fi

  if [ ! -f "$input_path" ]; then
    fail "File not found: $input_path"
  fi

  input_dir=$(CDPATH= cd -- "$(dirname -- "$input_path")" && pwd)
  input_file=$(basename -- "$input_path")
  printf '%s/%s\n' "$input_dir" "$input_file"
}

validate_one() {
  file_path=$1
  abs_file=$(absolute_path "$file_path")

  printf '%s\n' "==> Validating $file_path" >&2
  "$ESCRIPT_PATH" validate "$abs_file"
}

main() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  [ "$#" -gt 0 ] || {
    usage >&2
    exit 1
  }

  require_reference_dir
  build_escript_if_needed

  overall_status=0

  for file_path in "$@"; do
    if ! validate_one "$file_path"; then
      overall_status=1
    fi
  done

  exit "$overall_status"
}

main "$@"
