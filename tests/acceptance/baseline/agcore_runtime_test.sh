#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d "/tmp/base002-agcore-runtime.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

bash "$ROOT/scripts/verify-agcore-runtime-baseline.sh" "$TMP"

assert_pass() {
  check=$1
  awk -F '\t' -v check="$check" '$1 == check && $2 == "PASS" { found=1 } END { exit !found }' \
    "$TMP/agcore-runtime-smoke.tsv"
}

assert_pass nacos_agnacos_compatibility
assert_pass nacos_agconf_layering
assert_pass nacos_config_snapshot
assert_pass nacos_failure_semantics
assert_pass redis_agredis_compatibility
assert_pass redis_cache_loss_semantics
assert_pass redis_fact_source_unchanged

test -s "$TMP/nacos-config-snapshot.sha256"
test -s "$TMP/agcore-runtime.log"

printf 'BASE-002 ag-core Nacos/Redis compatibility and loss semantics PASS\n'
