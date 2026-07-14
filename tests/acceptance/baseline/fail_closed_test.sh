#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d "$ROOT/.base002-fail-closed.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

cp "$ROOT/reports/baseline/BASE-002/resilience.tsv" "$TMP/resilience.tsv"
bash "$ROOT/scripts/verify-fail-closed-baseline.sh" "$TMP"

for scenario in budget_unavailable object_store_unavailable \
  quality_gate_unavailable orchestrator_unavailable; do
  awk -F '\t' -v scenario="$scenario" \
    '$1 == scenario && $2 == "PASS" && $3 == 0 { ok=1 } END { exit !ok }' \
    "$TMP/resilience.tsv"
  test -s "$TMP/fail-closed/$scenario/facts-before.json"
  cmp "$TMP/fail-closed/$scenario/facts-before.json" \
    "$TMP/fail-closed/$scenario/facts-after.json"
  test "$(wc -l <"$TMP/fail-closed/$scenario/paid-events.tsv" | tr -d ' ')" = 1
  awk -F '\t' 'NR == 2 && $4 == "NOT_CALLED" { ok=1 } END { exit !ok }' \
    "$TMP/fail-closed/$scenario/result.tsv"
done

awk -F '\t' 'NR == 2 && $1 == "all_available" && $2 == "CONTROL_PASS" &&
  $3 == 1 && $4 == "CALLED" { ok=1 } END { exit !ok }' \
  "$TMP/fail-closed/all_available/result.tsv"
bash "$ROOT/scripts/verify-full-stack-baseline.sh" \
  --manifest "$ROOT/reports/baseline/BASE-002/baseline-manifest.yaml" \
  --evidence-dir "$TMP" --check resilience

printf 'BASE-002 executable fail-closed fault harness PASS\n'
