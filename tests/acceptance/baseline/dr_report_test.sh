#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d /tmp/base002-dr-report.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
EVIDENCE="$TMP/evidence"
NFR="$TMP/nfr"
mkdir -p "$EVIDENCE"

for file in temporal-dr-report.tsv temporal-mysql-smoke.tsv mysql-pitr.tsv kafka-rf3-smoke.tsv \
  mysql-pitr-target.tsv object-storage-smoke.tsv object-reference.tsv \
  agcore-runtime-upgrade.tsv kubernetes-harness.tsv resilience.tsv; do
  cp "$ROOT/reports/baseline/BASE-002/$file" "$EVIDENCE/$file"
done

bash "$ROOT/scripts/verify-dr-baseline.sh" "$EVIDENCE" "$NFR"

grep -F $'rpo_minutes\t0' "$EVIDENCE/dr-report.tsv" >/dev/null
grep -F $'rto_minutes\t1' "$EVIDENCE/dr-report.tsv" >/dev/null
grep -F $'mysql_pitr\tPASS' "$EVIDENCE/dr-report.tsv" >/dev/null
grep -F $'temporal_restore\tPASS' "$EVIDENCE/dr-report.tsv" >/dev/null
grep -F $'kafka_relationship\tPASS' "$EVIDENCE/dr-report.tsv" >/dev/null
grep -F $'object_reference_consistent\ttrue' "$EVIDENCE/dr-report.tsv" >/dev/null
grep -F $'rolling_upgrade\tPASS\t0' "$EVIDENCE/resilience.tsv" >/dev/null
grep -F $'rollback\tPASS\t0' "$EVIDENCE/resilience.tsv" >/dev/null
test -s "$NFR/timed-recovery.tsv"
test -s "$NFR/恢复演练报告.md"
test -s "$NFR/object-reference.tsv"
test -s "$NFR/mysql-pitr-target.tsv"
test -s "$NFR/kubernetes-harness.tsv"

cp "$EVIDENCE/temporal-dr-report.tsv" "$TMP/temporal-good.tsv"
awk -F '\t' 'BEGIN { OFS="\t" } $1 == "rto_minutes" { $2=121 } { print }' \
  "$TMP/temporal-good.tsv" >"$EVIDENCE/temporal-dr-report.tsv"
if bash "$ROOT/scripts/verify-dr-baseline.sh" "$EVIDENCE" "$NFR" >"$TMP/negative.log" 2>&1; then
  printf 'expected over-threshold RTO to fail\n' >&2
  exit 1
fi
grep -F 'B002-DR-E07' "$TMP/negative.log" >/dev/null

printf 'BASE-002 consolidated DR report PASS\n'
