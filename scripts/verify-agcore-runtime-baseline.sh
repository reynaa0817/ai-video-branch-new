#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
mkdir -p "$EVIDENCE"
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd)
FIXTURE="$ROOT/tests/acceptance/baseline/fixtures/agcore-runtime"
RUN="base002-agcore-$$"
REDIS="$RUN-redis"
NACOS="$RUN-nacos"
TMP=$(mktemp -d "/tmp/$RUN.XXXXXX")
REDIS_IMAGE='redis@sha256:77cb4599f0121142e25139cea1aafaf45fe765c74a0a41b38f4a4ea9fc8cb846'
NACOS_IMAGE='nacos/nacos-server@sha256:de4fc59c2c3b2a6f87d30265c5d3c8b549316c17575ce2b32eab8d02a8be26dd'

cleanup() {
  docker rm -f "$REDIS" "$NACOS" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT HUP INT TERM
cleanup
mkdir -p "$TMP"

probe() {
  label=$1
  shift
  attempt=0
  until "$@" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 180 ] || { printf '%s readiness timeout\n' "$label" >&2; return 1; }
    sleep 1
  done
}

docker run -d --name "$REDIS" -p 127.0.0.1::6379 "$REDIS_IMAGE" \
  redis-server --save '' --appendonly no >/dev/null
probe redis docker exec "$REDIS" redis-cli ping
REDIS_PORT=$(docker port "$REDIS" 6379/tcp | awk -F: 'NR == 1 { print $NF }')

docker run -d --name "$NACOS" -p 127.0.0.1::8848 \
  -e MODE=standalone \
  -e NACOS_AUTH_TOKEN=YmFzZTAwMi1uYWNvcy1hdXRoLXRva2VuLW11c3QtYmUtYXQtbGVhc3QtMzItYnl0ZXM= \
  -e NACOS_AUTH_IDENTITY_KEY=base002 -e NACOS_AUTH_IDENTITY_VALUE=base002-secret \
  -e JVM_XMS=512m -e JVM_XMX=512m -e JVM_XMN=256m \
  "$NACOS_IMAGE" >/dev/null
probe nacos sh -c "docker logs '$NACOS' 2>&1 | grep -Eq 'Nacos (Server API )?started successfully'"
NACOS_PORT=$(docker port "$NACOS" 8848/tcp | awk -F: 'NR == 1 { print $NF }')

printf 'attempt_id=base002-agcore-runtime\nfact_id=durable-fact-001\nstate=persisted\n' >"$TMP/business-facts.txt"
READY_FILE="$TMP/fixture.ready"
CONTINUE_FILE="$TMP/continue"

(
  cd "$FIXTURE"
  EVIDENCE_DIR="$EVIDENCE" \
  FACT_FILE="$TMP/business-facts.txt" \
  READY_FILE="$READY_FILE" \
  CONTINUE_FILE="$CONTINUE_FILE" \
  NACOS_ADDR="127.0.0.1:$NACOS_PORT" \
  REDIS_ADDR="127.0.0.1:$REDIS_PORT" \
  GOTOOLCHAIN=local go run .
) >"$EVIDENCE/agcore-runtime.log" 2>&1 &
FIXTURE_PID=$!

fixture_attempt=0
until test -s "$READY_FILE"; do
  if ! kill -0 "$FIXTURE_PID" >/dev/null 2>&1; then
    wait "$FIXTURE_PID" || true
    cat "$EVIDENCE/agcore-runtime.log" >&2
    exit 1
  fi
  fixture_attempt=$((fixture_attempt + 1))
  [ "$fixture_attempt" -lt 180 ] || { printf 'fixture readiness timeout\n' >&2; exit 1; }
  sleep 1
done

docker logs "$NACOS" >"$EVIDENCE/agcore-nacos.log" 2>&1
docker rm -f "$NACOS" >/dev/null

docker logs "$REDIS" >"$EVIDENCE/agcore-redis-before-loss.log" 2>&1
docker rm -f "$REDIS" >/dev/null
docker run -d --name "$REDIS" -p "127.0.0.1:$REDIS_PORT:6379" "$REDIS_IMAGE" \
  redis-server --save '' --appendonly no >/dev/null
probe replacement-redis docker exec "$REDIS" redis-cli ping
printf 'continue\n' >"$CONTINUE_FILE"

if ! wait "$FIXTURE_PID"; then
  cat "$EVIDENCE/agcore-runtime.log" >&2
  exit 1
fi
docker logs "$REDIS" >"$EVIDENCE/agcore-redis-after-loss.log" 2>&1

assert_log() {
  key=$1
  grep -F "$key=PASS" "$EVIDENCE/agcore-runtime.log" >/dev/null
}
assert_log NACOS_AGNACOS_COMPATIBILITY
assert_log NACOS_AGCONF_LAYERING
assert_log NACOS_CONFIG_SNAPSHOT
assert_log NACOS_FAILURE_SEMANTICS
assert_log REDIS_AGREDIS_COMPATIBILITY
assert_log REDIS_CACHE_LOSS_SEMANTICS
assert_log REDIS_FACT_SOURCE_UNCHANGED

{
  printf 'check\tstatus\tevidence\n'
  printf 'nacos_agnacos_compatibility\tPASS\tagcore-runtime.log\n'
  printf 'nacos_agconf_layering\tPASS\tagcore-runtime.log\n'
  printf 'nacos_config_snapshot\tPASS\tnacos-config-snapshot.sha256\n'
  printf 'nacos_failure_semantics\tPASS\tagcore-runtime.log\n'
  printf 'redis_agredis_compatibility\tPASS\tagcore-runtime.log\n'
  printf 'redis_cache_loss_semantics\tPASS\tagcore-redis-after-loss.log\n'
  printf 'redis_fact_source_unchanged\tPASS\tagcore-runtime.log\n'
} >"$EVIDENCE/agcore-runtime-smoke.tsv"

printf 'BASE-002 ag-core Nacos/Redis compatibility and loss semantics PASS\n'
