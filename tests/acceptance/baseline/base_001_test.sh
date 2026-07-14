#!/usr/bin/env bash
# Story 1.1 / BASE-001 acceptance contract.
# ATDD RED PHASE: default is skipped; activate explicitly to prove RED.
set -u

if [ "${BASE001_ATDD_ACTIVATE:-0}" != "1" ]; then
  printf 'TAP version 13\n'
  printf '1..0 # SKIP ATDD RED scaffold; run with BASE001_ATDD_ACTIVATE=1\n'
  exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
FIXTURE_FACTORY="$SCRIPT_DIR/fixtures/base_001_fixture_factory.sh"
GATE="$PROJECT_ROOT/scripts/verify-ag-core-baseline.sh"
TMP_ROOT=$(mktemp -d "/tmp/base-001-atdd.XXXXXX")
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

record_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok - %s\n' "$1"
}

record_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'not ok - %s: %s\n' "$1" "$2" >&2
}

contains_text() {
  printf '%s\n' "$1" | grep -F -- "$2" >/dev/null 2>&1
}

prepare_case() {
  case_id=$1
  variant=$2
  case_dir="$TMP_ROOT/$case_id"
  mkdir -p "$case_dir"
  if [ ! -r "$FIXTURE_FACTORY" ]; then
    printf '%s\n' "fixture factory missing: $FIXTURE_FACTORY" >&2
    return 1
  fi
  bash "$FIXTURE_FACTORY" "$case_dir" "$variant"
}

invoke_gate() {
  case_dir=$1
  check_name=$2
  output_file="$case_dir/gate-output.log"

  if [ ! -r "$GATE" ]; then
    printf '%s\n' "authoritative gate missing: $GATE" >"$output_file"
    return 127
  fi

  (
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
    export PATH
    BASE001_TEST_MODE=1
    BASE001_FIXTURE_ROOT="$case_dir"
    GOWORK=off
    GOMODCACHE="$case_dir/cache/gomod"
    GOCACHE="$case_dir/cache/go-build"
    export BASE001_TEST_MODE BASE001_FIXTURE_ROOT GOWORK GOMODCACHE GOCACHE
    bash "$GATE" \
      --manifest "$case_dir/baseline-manifest.yaml" \
      --evidence-dir "$case_dir/evidence" \
      --remote-url "file://$case_dir/remote.git" \
      --check "$check_name"
  ) >"$output_file" 2>&1
}

run_positive() {
  case_id=$1
  check_name=$2
  expected_marker=$3
  case_dir="$TMP_ROOT/$case_id"

  if ! prepare_case "$case_id" valid; then
    record_fail "$case_id" "fixture setup failed"
    return
  fi

  invoke_gate "$case_dir" "$check_name"
  exit_status=$?
  output=$(cat "$case_dir/gate-output.log")

  if [ "$exit_status" -ne 0 ]; then
    record_fail "$case_id" "expected exit 0, got $exit_status; output: $output"
    return
  fi
  if ! contains_text "$output" "$expected_marker"; then
    record_fail "$case_id" "missing marker $expected_marker; output: $output"
    return
  fi
  record_pass "$case_id"
}

run_negative() {
  case_id=$1
  variant=$2
  expected_code=$3
  diagnostic_field=$4
  case_dir="$TMP_ROOT/$case_id"

  if ! prepare_case "$case_id" "$variant"; then
    record_fail "$case_id" "fixture setup failed"
    return
  fi

  invoke_gate "$case_dir" all
  exit_status=$?
  output=$(cat "$case_dir/gate-output.log")

  if [ "$exit_status" -eq 0 ]; then
    record_fail "$case_id" "expected non-zero exit for $variant"
    return
  fi
  if ! contains_text "$output" "$expected_code"; then
    record_fail "$case_id" "expected error $expected_code; output: $output"
    return
  fi
  if ! contains_text "$output" "$diagnostic_field"; then
    record_fail "$case_id" "missing diagnostic field $diagnostic_field; output: $output"
    return
  fi
  record_pass "$case_id"
}

printf 'TAP version 13\n'
printf '1..13\n'

run_positive BASE-001-P01 refs 'BASE-001-P01 PASS'
run_positive BASE-001-P02 build 'BASE-001-P02 PASS'
run_positive BASE-001-P03 metadata 'BASE-001-P03 PASS'
run_positive BASE-001-P04 evidence 'BASE-001-P04 PASS'

run_negative BASE-001-N01 missing_ref B001-E01 tool_source_ref
run_negative BASE-001-N02 sha_mismatch B001-E02 actual_sha
run_negative BASE-001-N03 legacy_gitlab B001-E03 gitlab.allinfinance.com/aifgo/ag-core
run_negative BASE-001-N04 local_masking B001-E04 go.work
run_negative BASE-001-N05 missing_gendb B001-E05 gendb
run_negative BASE-001-N06 provenance_mismatch B001-E06 root_dep_sha
run_negative BASE-001-N07 invalid_vcs B001-E07 vcs.modified
run_negative BASE-001-N08 unfrozen_environment B001-E08 image_digest
run_negative BASE-001-N09 unprotected_release B001-E09 release_approved

printf '# pass=%s fail=%s expected_to_fail=true tdd_phase=RED\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
exit 0
