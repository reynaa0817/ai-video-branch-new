#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
mkdir -p "$EVIDENCE"
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd)
FIXTURE="$ROOT/tests/acceptance/baseline/fixtures/agcore-runtime"
RUN="base002-agcore-upgrade-$$"
NACOS="$RUN-nacos"
REDIS="$RUN-redis"
NACOS_VOLUME="$RUN-nacos-data"
REDIS_VOLUME="$RUN-redis-data"
NACOS_OLD='nacos/nacos-server@sha256:8987908cb94ed5f9d30522a64493d35732a6c05f216d667a7addb022f3d92e80'
NACOS_CURRENT='nacos/nacos-server@sha256:de4fc59c2c3b2a6f87d30265c5d3c8b549316c17575ce2b32eab8d02a8be26dd'
REDIS_OLD='redis@sha256:315270d166080f537bbdf1b489b603aaaa213cb55a544acfa51feb7481abb1c0'
REDIS_CURRENT='redis@sha256:77cb4599f0121142e25139cea1aafaf45fe765c74a0a41b38f4a4ea9fc8cb846'

cleanup() {
  docker rm -f "$NACOS" "$REDIS" >/dev/null 2>&1 || true
  docker volume rm -f "$NACOS_VOLUME" "$REDIS_VOLUME" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
cleanup
docker volume create "$NACOS_VOLUME" >/dev/null
docker volume create "$REDIS_VOLUME" >/dev/null

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

start_nacos() {
  image=$1
  docker run -d --name "$NACOS" -p 127.0.0.1::8848 \
    -v "$NACOS_VOLUME:/home/nacos/data" \
    -e MODE=standalone \
    -e NACOS_AUTH_TOKEN=YmFzZTAwMi1uYWNvcy1hdXRoLXRva2VuLW11c3QtYmUtYXQtbGVhc3QtMzItYnl0ZXM= \
    -e NACOS_AUTH_IDENTITY_KEY=base002 -e NACOS_AUTH_IDENTITY_VALUE=base002-secret \
    -e JVM_XMS=512m -e JVM_XMX=512m -e JVM_XMN=256m \
    "$image" >/dev/null
  probe nacos sh -c "docker logs '$NACOS' 2>&1 | grep -Eq 'Nacos (Server API )?started successfully'"
  docker port "$NACOS" 8848/tcp | awk -F: 'NR == 1 { print $NF }'
}

stop_nacos() {
  phase=$1
  docker logs "$NACOS" >"$EVIDENCE/agcore-nacos-$phase.log" 2>&1
  docker stop "$NACOS" >/dev/null
  docker rm "$NACOS" >/dev/null
}

run_nacos_phase() {
  port=$1
  action=$2
  (
    cd "$FIXTURE"
    MODE=nacos-phase PHASE_ACTION="$action" \
      CONFIG_CONTENT='app:\n  feature: upgrade-preserved\n  owner: sre\n' \
      NACOS_ADDR="127.0.0.1:$port" GOTOOLCHAIN=local go run .
  )
}

start_redis() {
  image=$1
  docker run -d --name "$REDIS" -p 127.0.0.1::6379 -v "$REDIS_VOLUME:/data" \
    "$image" redis-server --appendonly yes --appendfsync always >/dev/null
  probe redis docker exec "$REDIS" redis-cli ping
  docker port "$REDIS" 6379/tcp | awk -F: 'NR == 1 { print $NF }'
}

stop_redis() {
  phase=$1
  docker logs "$REDIS" >"$EVIDENCE/agcore-redis-$phase.log" 2>&1
  docker stop "$REDIS" >/dev/null
  docker rm "$REDIS" >/dev/null
}

run_redis_phase() {
  port=$1
  action=$2
  items=$3
  (
    cd "$FIXTURE"
    MODE=redis-phase PHASE_ACTION="$action" CACHE_ITEMS="$items" \
      REDIS_ADDR="127.0.0.1:$port" GOTOOLCHAIN=local go run .
  )
}

{
  nacos_port=$(start_nacos "$NACOS_OLD")
  run_nacos_phase "$nacos_port" publish
  stop_nacos n-minus-1

  nacos_port=$(start_nacos "$NACOS_CURRENT")
  run_nacos_phase "$nacos_port" assert
  stop_nacos current

  nacos_port=$(start_nacos "$NACOS_OLD")
  run_nacos_phase "$nacos_port" assert
  stop_nacos rollback

  redis_port=$(start_redis "$REDIS_OLD")
  run_redis_phase "$redis_port" write 'base002:before=v1'
  stop_redis n-minus-1

  redis_port=$(start_redis "$REDIS_CURRENT")
  run_redis_phase "$redis_port" write 'base002:before=v1,base002:after=v2'
  stop_redis current

  redis_port=$(start_redis "$REDIS_OLD")
  run_redis_phase "$redis_port" assert 'base002:before=v1,base002:after=v2'
  stop_redis rollback
} >"$EVIDENCE/agcore-runtime-upgrade.log" 2>&1

{
  printf 'check\tstatus\tevidence\n'
  printf 'nacos_n_minus_1_sdk\tPASS\tagcore-runtime-upgrade.log\n'
  printf 'nacos_upgrade\tPASS\tagcore-runtime-upgrade.log\n'
  printf 'nacos_rollback\tPASS\tagcore-runtime-upgrade.log\n'
  printf 'redis_n_minus_1_sdk\tPASS\tagcore-runtime-upgrade.log\n'
  printf 'redis_upgrade\tPASS\tagcore-runtime-upgrade.log\n'
  printf 'redis_rollback\tPASS\tagcore-runtime-upgrade.log\n'
} >"$EVIDENCE/agcore-runtime-upgrade.tsv"

printf 'BASE-002 ag-core Nacos/Redis N/N-1 upgrade and rollback PASS\n'
