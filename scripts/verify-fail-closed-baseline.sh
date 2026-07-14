#!/usr/bin/env bash
# Execute four independent dependency faults before the paid provider boundary.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
FIXTURE="$ROOT/tests/acceptance/baseline/fixtures/fail-closed"
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
GO_IMAGE='golang@sha256:d7098379b7da665ab25b99795465ec320b1ca9d4addb9f77409c4827dc904211'
UID_VALUE=$(id -u)
GID_VALUE=$(id -g)

mkdir -p "$EVIDENCE"
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd -P)
OUT="$EVIDENCE/fail-closed"
mkdir -p "$OUT"
for scenario in budget_unavailable object_store_unavailable \
  quality_gate_unavailable orchestrator_unavailable all_available; do
  scenario_out="$OUT/$scenario"
  rm -rf "$scenario_out"
  mkdir -p "$scenario_out"
  docker run --rm --network none --user "$UID_VALUE:$GID_VALUE" \
    -e GOTOOLCHAIN=local -e GOCACHE=/tmp/gocache -e HOME=/tmp \
    -v "$FIXTURE:/src:ro" -v "$scenario_out:/evidence" -w /src "$GO_IMAGE" \
    sh -ceu 'go test ./...; go run . --scenario "$1" --out /evidence' sh "$scenario" \
    >"$scenario_out/execution.log" 2>&1
done

for scenario in budget_unavailable object_store_unavailable \
  quality_gate_unavailable orchestrator_unavailable; do
  scenario_out="$OUT/$scenario"
  cmp "$scenario_out/facts-before.json" "$scenario_out/facts-after.json"
  [ "$(wc -l <"$scenario_out/paid-events.tsv" | tr -d ' ')" = 1 ]
  awk -F '\t' -v scenario="$scenario" '
    NR == 2 && $1 == scenario && $2 == "PASS" && $3 == 0 &&
      $4 == "NOT_CALLED" && $5 ~ /^DEPENDENCY_UNAVAILABLE:/ { ok=1 }
    END { exit !ok }
  ' "$scenario_out/result.tsv"
done
awk -F '\t' 'NR == 2 && $1 == "all_available" && $2 == "CONTROL_PASS" &&
  $3 == 1 && $4 == "CALLED" { ok=1 } END { exit !ok }' \
  "$OUT/all_available/result.tsv"

for scenario in rolling_upgrade rollback; do
  awk -F '\t' -v scenario="$scenario" '$1 == scenario && $2 == "PASS" && $3 == 0 { ok=1 }
    END { exit !ok }' "$EVIDENCE/resilience.tsv"
done

{
  printf 'scenario\tstatus\tpaid_progress\n'
  for scenario in budget_unavailable object_store_unavailable \
    quality_gate_unavailable orchestrator_unavailable; do
    printf '%s\tPASS\t0\n' "$scenario"
  done
  printf 'rolling_upgrade\tPASS\t0\n'
  printf 'rollback\tPASS\t0\n'
} >"$EVIDENCE/resilience.tsv"

{
  printf 'scenario\tstatus\tpaid_progress\tprovider_submit\tdenial\tfact_digest\n'
  for scenario in budget_unavailable object_store_unavailable \
    quality_gate_unavailable orchestrator_unavailable all_available; do
    awk 'NR == 2' "$OUT/$scenario/result.tsv"
  done
} >"$EVIDENCE/fail-closed-smoke.tsv"

printf 'BASE-002 four-dependency executable fail-closed harness PASS\n'
