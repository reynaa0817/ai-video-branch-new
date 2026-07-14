#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d "/tmp/base002-agcore-upgrade.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

bash "$ROOT/scripts/verify-agcore-runtime-upgrade.sh" "$TMP"

for check in \
  nacos_n_minus_1_sdk nacos_upgrade nacos_rollback \
  redis_n_minus_1_sdk redis_upgrade redis_rollback; do
  awk -F '\t' -v check="$check" '$1 == check && $2 == "PASS" { found=1 } END { exit !found }' \
    "$TMP/agcore-runtime-upgrade.tsv"
done

printf 'BASE-002 ag-core Nacos/Redis N/N-1 upgrade and rollback PASS\n'
