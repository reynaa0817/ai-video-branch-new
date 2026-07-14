#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d "/tmp/base002-mysql-pitr.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

bash "$ROOT/scripts/verify-mysql-pitr-baseline.sh" "$TMP"

awk -F '\t' '$1 == "mysql_pitr" && $2 == "PASS" && $3 == 0 && $4 <= 120 { found=1 } END { exit !found }' \
  "$TMP/mysql-pitr.tsv"
grep -q $'fact_count_after_restore\t2' "$TMP/mysql-pitr.tsv"
printf 'BASE-002 MySQL binlog PITR PASS\n'
