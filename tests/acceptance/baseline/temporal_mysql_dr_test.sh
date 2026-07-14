#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d /tmp/base002-temporal-dr-test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

bash "$ROOT/scripts/verify-temporal-mysql-baseline.sh" "$TMP"

report="$TMP/temporal-mysql-smoke.tsv"
[ -s "$report" ]

assert_pass() {
  component=$1
  grep -F "${component}"$'\tPASS\t' "$report" >/dev/null 2>&1 || {
    printf 'expected PASS evidence for %s\n' "$component" >&2
    sed -n '1,120p' "$report" >&2
    exit 1
  }
}

assert_pass mysql_8_4_10
assert_pass temporal_schema_1_19_1_14
assert_pass namespace_isolation
assert_pass workflow_sdk_compatibility
assert_pass server_upgrade_1_30_2_to_1_31_2
assert_pass server_rollback_1_31_2_to_1_30_2
assert_pass worker_interruption_recovery
assert_pass mysql_logical_restore

dr="$TMP/temporal-dr-report.tsv"
[ -s "$dr" ]
rpo=$(awk -F '\t' '$1 == "rpo_minutes" { print $2 }' "$dr")
rto=$(awk -F '\t' '$1 == "rto_minutes" { print $2 }' "$dr")
[ -n "$rpo" ] && [ "$rpo" -le 5 ]
[ -n "$rto" ] && [ "$rto" -le 120 ]
grep -F $'workflow_after_restore\tPASS' "$dr" >/dev/null

printf 'Temporal/MySQL upgrade, rollback and timed restore PASS\n'
