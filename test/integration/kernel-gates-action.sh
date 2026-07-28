#!/usr/bin/env bash
# kernel-gates-action.sh — exercises box-and-box kernel admission across a real
# OS process boundary: Process A (Node.js, box-and-box govern) decides, Process B
# (Elixir/BEAM, ampersand generate mcp) acts only on permission.
#
# Claim: "box-and-box kernel admission governs a real action executed by a
# different process."
# Old rung:  in_tree
# New rung:  live_local  (if both paths pass)
# Boundary:  OS process — Node.js (V8) → Elixir (BEAM), connected by exit code
#            and stdout capture, no stub or injected transport.
#
# Usage:
#   sh test/integration/kernel-gates-action.sh
#
# Requires: node, the Elixir escript at reference/elixir/ampersand_core/ampersand
# Run from the AmpersandBoxDesign repository root.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

COMPILE="box-and-box/bin/compile.mjs"
GOVERN="box-and-box/bin/govern.mjs"
AGENT="examples/infra-operator.ampersand.json"
ACTOR="./reference/elixir/ampersand_core/ampersand"
INTEGRATION_DIR="test/integration"
OUT_DIR="$INTEGRATION_DIR/out"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

PASS=0
FAIL=0

# ---------- helpers ----------------------------------------------------------

announce() { printf '\n==== %s ====\n' "$1"; }

assert_eq() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    printf '  PASS  %s (got %s)\n' "$label" "$got"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s (got %s, want %s)\n' "$label" "$got" "$want"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    printf '  PASS  %s exists (%d bytes)\n' "$label" "$(wc -c < "$path")"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s missing: %s\n' "$label" "$path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    printf '  PASS  %s absent (action was not performed)\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s should not exist but does: %s\n' "$label" "$path"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_field() {
  local label="$1" file="$2" field="$3" want="$4"
  local got
  got=$(node -e "const d=JSON.parse(require('fs').readFileSync('$file','utf8')); console.log(JSON.stringify(d.$field))")
  if [ "$got" = "$want" ]; then
    printf '  PASS  %s .%s == %s\n' "$label" "$field" "$got"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s .%s got %s, want %s\n' "$label" "$field" "$got" "$want"
    FAIL=$((FAIL + 1))
  fi
}

# ---------- PATH 1: kernel permits → action executes -------------------------

announce "PATH 1: kernel permits, action executes"

# Process A: compile governance + govern (two Node.js invocations, piped)
CERT_PERMIT="$OUT_DIR/certificate-permit.json"
MCP_OUTPUT="$OUT_DIR/mcp-output.json"

# Build the decision spec
SPEC_PERMIT="$OUT_DIR/spec-permit.json"
node "$COMPILE" "$AGENT" --options "$INTEGRATION_DIR/options-permit.json" > "$SPEC_PERMIT" 2>/dev/null

# Run the kernel (Process A)
EXIT_A=0
node "$GOVERN" "$SPEC_PERMIT" --quiet > "$CERT_PERMIT" 2>/dev/null || EXIT_A=$?

assert_eq "govern exit code" "$EXIT_A" "0"
assert_file_exists "certificate-permit.json" "$CERT_PERMIT"
assert_json_field "permit cert" "$CERT_PERMIT" "decision" '"generate-mcp"'

# Process B: the real action, only if kernel permitted
if [ "$EXIT_A" -eq 0 ]; then
  "$ACTOR" generate mcp "$AGENT" > "$MCP_OUTPUT" 2>/dev/null
  ACTOR_EXIT=$?
  assert_eq "actor exit code" "$ACTOR_EXIT" "0"
  assert_file_exists "mcp-output.json" "$MCP_OUTPUT"
  # Verify the output is valid JSON with context_servers
  HAS_SERVERS=$(node -e "const d=JSON.parse(require('fs').readFileSync('$MCP_OUTPUT','utf8')); console.log(typeof d.context_servers === 'object' && d.context_servers !== null ? 'yes' : 'no')")
  assert_eq "mcp output has context_servers" "$HAS_SERVERS" "yes"
else
  printf '  SKIP  actor not invoked (kernel did not permit)\n'
fi

# ---------- PATH 2: kernel refuses → action does NOT execute -----------------

announce "PATH 2: kernel refuses, action does NOT execute"

CERT_REFUSE="$OUT_DIR/certificate-refuse.json"
MCP_REFUSED="$OUT_DIR/mcp-output-refused.json"

# Build the decision spec (cost exceeds $1000 threshold)
SPEC_REFUSE="$OUT_DIR/spec-refuse.json"
node "$COMPILE" "$AGENT" --options "$INTEGRATION_DIR/options-refuse.json" > "$SPEC_REFUSE" 2>/dev/null

# Run the kernel (Process A) — expect exit 1 (no admissible option)
EXIT_B=0
node "$GOVERN" "$SPEC_REFUSE" --quiet > "$CERT_REFUSE" 2>/dev/null || EXIT_B=$?

assert_eq "govern exit code" "$EXIT_B" "1"
assert_file_exists "certificate-refuse.json" "$CERT_REFUSE"
assert_json_field "refuse cert" "$CERT_REFUSE" "decision" "null"

# Process B must NOT run
if [ "$EXIT_B" -eq 0 ]; then
  "$ACTOR" generate mcp "$AGENT" > "$MCP_REFUSED" 2>/dev/null
  printf '  UNEXPECTED  actor ran on a refusing verdict\n'
  FAIL=$((FAIL + 1))
else
  printf '  PASS  actor was NOT invoked (kernel refused)\n'
  PASS=$((PASS + 1))
  assert_file_not_exists "mcp-output-refused.json" "$MCP_REFUSED"
fi

# Verify the refusal certificate explains WHY
VETOED=$(node -e "const d=JSON.parse(require('fs').readFileSync('$CERT_REFUSE','utf8')); console.log(d.deonticallyVetoed.length)")
assert_eq "refuse cert has vetoed options" "$VETOED" "1"

VETOED_BY=$(node -e "const d=JSON.parse(require('fs').readFileSync('$CERT_REFUSE','utf8')); console.log(d.deonticallyVetoed[0].by[0])")
assert_eq "vetoed by cost norm" "$VETOED_BY" "escalate-cost_exceeds_usd"

# ---------- summary ----------------------------------------------------------

announce "SUMMARY"

printf '\n  Passed: %d\n  Failed: %d\n\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf 'RESULT: FAIL — %d assertion(s) failed\n' "$FAIL"
  exit 1
fi

printf 'RESULT: PASS — kernel admission governs a real action across a process boundary\n'
printf '\n  Claim:     box-and-box kernel admission governs a real action executed by a different process\n'
printf '  Old rung:  in_tree\n'
printf '  New rung:  live_local\n'
printf '  Boundary:  OS process (Node.js V8 → Elixir BEAM)\n'
printf '  Transport: exit code + stdout JSON, no stub or injection\n'
printf '  Evidence:  certificates retained in %s/\n' "$OUT_DIR"
exit 0
