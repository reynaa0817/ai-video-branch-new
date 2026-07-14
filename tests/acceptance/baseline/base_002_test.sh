#!/usr/bin/env bash
# Story 1.2 / BASE-002 + NFR-DR-001 acceptance contract.
# test.skip() equivalent: activate explicitly during the ATDD RED phase.
set -u

if [ "${BASE002_ATDD_ACTIVATE:-0}" != "1" ]; then
  printf 'TAP version 13\n'
  printf '1..0 # SKIP ATDD RED scaffold; run with BASE002_ATDD_ACTIVATE=1\n'
  exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
FIXTURE_FACTORY="$SCRIPT_DIR/fixtures/base_002_fixture_factory.sh"
GATE="$PROJECT_ROOT/scripts/verify-full-stack-baseline.sh"
TMP_ROOT=$(mktemp -d "/tmp/base-002-atdd.XXXXXX")
PASS_COUNT=0
FAIL_COUNT=0

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT HUP INT TERM

record_pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'ok - %s\n' "$1"; }
record_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'not ok - %s: %s\n' "$1" "$2" >&2; }
contains_text() { printf '%s\n' "$1" | grep -F -- "$2" >/dev/null 2>&1; }

prepare_case() {
  case_id=$1
  variant=$2
  case_dir="$TMP_ROOT/$case_id"
  mkdir -p "$case_dir"
  [ -r "$FIXTURE_FACTORY" ] || { printf 'fixture factory missing: %s\n' "$FIXTURE_FACTORY" >&2; return 1; }
  bash "$FIXTURE_FACTORY" "$case_dir" "$variant"
}

invoke_gate() {
  case_dir=$1
  check_name=$2
  output_file="$case_dir/gate-output.log"
  if [ ! -r "$GATE" ]; then
    printf 'authoritative gate missing: %s\n' "$GATE" >"$output_file"
    return 127
  fi
  (
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
    export PATH
    BASE002_TEST_MODE=1
    BASE002_FIXTURE_ROOT="$case_dir"
    export BASE002_TEST_MODE BASE002_FIXTURE_ROOT
    bash "$GATE" --manifest "$case_dir/baseline-manifest.yaml" --evidence-dir "$case_dir/evidence" --check "$check_name"
  ) >"$output_file" 2>&1
}

run_positive() {
  case_id=$1
  check_name=$2
  expected_marker=$3
  case_dir="$TMP_ROOT/$case_id"
  if ! prepare_case "$case_id" valid; then record_fail "$case_id" 'fixture setup failed'; return; fi
  invoke_gate "$case_dir" "$check_name"
  exit_status=$?
  output=$(cat "$case_dir/gate-output.log")
  if [ "$exit_status" -ne 0 ]; then record_fail "$case_id" "expected exit 0, got $exit_status; output: $output"; return; fi
  if ! contains_text "$output" "$expected_marker"; then record_fail "$case_id" "missing marker $expected_marker; output: $output"; return; fi
  record_pass "$case_id"
}

run_negative() {
  case_id=$1
  variant=$2
  expected_code=$3
  diagnostic_field=$4
  case_dir="$TMP_ROOT/$case_id"
  if ! prepare_case "$case_id" "$variant"; then record_fail "$case_id" 'fixture setup failed'; return; fi
  invoke_gate "$case_dir" all
  exit_status=$?
  output=$(cat "$case_dir/gate-output.log")
  if [ "$exit_status" -eq 0 ]; then record_fail "$case_id" "expected non-zero exit for $variant"; return; fi
  if ! contains_text "$output" "$expected_code"; then record_fail "$case_id" "expected error $expected_code; output: $output"; return; fi
  if ! contains_text "$output" "$diagnostic_field"; then record_fail "$case_id" "missing diagnostic field $diagnostic_field; output: $output"; return; fi
  record_pass "$case_id"
}

printf 'TAP version 13\n'
printf '1..15\n'

run_positive BASE-002-P01 manifest 'BASE-002-P01 PASS'
run_positive BASE-002-P02 isolation 'BASE-002-P02 PASS'
run_positive BASE-002-P03 compatibility 'BASE-002-P03 PASS'
run_positive BASE-002-P04 web 'BASE-002-P04 PASS'
run_positive BASE-002-P05 media 'BASE-002-P05 PASS'
run_positive BASE-002-P06 resilience 'BASE-002-P06 PASS'
run_positive NFR-DR-001-S01 dr 'NFR-DR-001-S01 PASS'

run_negative BASE-002-N01 missing_field B002-E01 component
run_negative BASE-002-N02 floating_ref B002-E02 image_digest
run_negative BASE-002-N03 incompatible_stack B002-E03 temporal
run_negative BASE-002-N04 shared_environment B002-E04 namespace
run_negative BASE-002-N05 unsafe_progress B002-E05 paid_progress
run_negative BASE-002-N06 invalid_media B002-E06 media
run_negative BASE-002-N07 dr_threshold B002-E07 rpo_minutes
run_negative BASE-002-N08 premature_release B002-E08 g0_2

printf '# pass=%s fail=%s expected_to_fail=true tdd_phase=RED\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
