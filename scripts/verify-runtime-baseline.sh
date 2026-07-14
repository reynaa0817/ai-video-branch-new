#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
RUN="base002-$$"
NETWORK="$RUN-net"
REDIS="$RUN-redis"
MINIO="$RUN-minio"
KAFKA="$RUN-kafka"
NACOS="$RUN-nacos"
MC_IMAGE='minio/mc@sha256:aead63c77f9db9107f1696fb08ecb0faeda23729cde94b0f663edf4fe09728e3'

cleanup() {
  docker rm -f "$REDIS" "$MINIO" "$KAFKA" "$NACOS" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
cleanup
docker network create "$NETWORK" >/dev/null

probe() {
  label=$1
  shift
  attempt=0
  until "$@" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 120 ] || { printf '%s readiness timeout\n' "$label" >&2; return 1; }
    sleep 1
  done
}

docker run -d --name "$REDIS" --network "$NETWORK" \
  redis@sha256:77cb4599f0121142e25139cea1aafaf45fe765c74a0a41b38f4a4ea9fc8cb846 \
  redis-server --save '' --appendonly no >/dev/null
probe redis docker exec "$REDIS" redis-cli ping
docker exec "$REDIS" redis-cli set ephemeral-cache not-a-business-fact >/dev/null
docker exec "$REDIS" redis-cli del ephemeral-cache >/dev/null
[ "$(docker exec "$REDIS" redis-cli exists ephemeral-cache | tr -d '\r')" = 0 ]
docker logs "$REDIS" >"$EVIDENCE/runtime-redis.log" 2>&1

docker run -d --name "$MINIO" --network "$NETWORK" \
  -e MINIO_ROOT_USER=base002admin -e MINIO_ROOT_PASSWORD=base002-password \
  minio/minio@sha256:a1ea29fa28355559ef137d71fc570e508a214ec84ff8083e39bc5428980b015e server /data >/dev/null
probe minio docker exec "$MINIO" curl -fsS http://127.0.0.1:9000/minio/health/ready
docker run --rm --network "$NETWORK" --entrypoint /bin/sh -e MINIO_HOST="$MINIO" "$MC_IMAGE" -c '
  set -eu
  mc alias set int "http://$MINIO_HOST:9000" base002admin base002-password >/dev/null
  mc mb --with-versioning int/ai-video-int >/dev/null
  printf 'base002-object' >/tmp/object.txt
  mc cp /tmp/object.txt int/ai-video-int/golden/object.txt >/dev/null
  mc stat --json int/ai-video-int/golden/object.txt >/tmp/stat.json
  mc cp int/ai-video-int/golden/object.txt /tmp/downloaded.txt >/dev/null
  mc retention info int/ai-video-int/golden/object.txt >/dev/null 2>&1 || true
  set -- $(sha256sum /tmp/object.txt); original_sha=$1
  set -- $(sha256sum /tmp/downloaded.txt); test "$original_sha" = "$1"
  mc version info int/ai-video-int >/tmp/version.txt
  test -s /tmp/version.txt
'
docker logs "$MINIO" >"$EVIDENCE/runtime-minio.log" 2>&1

docker run -d --name "$KAFKA" --network "$NETWORK" \
  apache/kafka@sha256:3f7b939115cd4872e9cee9369d80bd69712fde55f9902f46d793f64848dedc75 >/dev/null
probe kafka docker exec "$KAFKA" /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
docker exec "$KAFKA" /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic ai-video-int-events --partitions 3 --replication-factor 1 >/dev/null
printf 'persisted-fact-1\npersisted-fact-2\n' | docker exec -i "$KAFKA" \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic ai-video-int-events >/dev/null
count=$(docker exec "$KAFKA" /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic ai-video-int-events --from-beginning --max-messages 2 --timeout-ms 10000 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = 2 ]
docker exec "$KAFKA" /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic ai-video-int-events.dlq --partitions 3 --replication-factor 1 >/dev/null
docker logs "$KAFKA" >"$EVIDENCE/runtime-kafka.log" 2>&1

docker run -d --name "$NACOS" --network "$NETWORK" -e MODE=standalone \
  -e NACOS_AUTH_TOKEN=YmFzZTAwMi1uYWNvcy1hdXRoLXRva2VuLW11c3QtYmUtYXQtbGVhc3QtMzItYnl0ZXM= \
  -e NACOS_AUTH_IDENTITY_KEY=base002 -e NACOS_AUTH_IDENTITY_VALUE=base002-secret \
  -e JVM_XMS=512m -e JVM_XMX=512m -e JVM_XMN=256m \
  nacos/nacos-server@sha256:de4fc59c2c3b2a6f87d30265c5d3c8b549316c17575ce2b32eab8d02a8be26dd >/dev/null
probe nacos sh -c "docker logs '$NACOS' 2>&1 | grep -Eq 'Nacos (Server API )?started successfully'"
docker logs "$NACOS" >"$EVIDENCE/runtime-nacos.log" 2>&1

{
  printf 'component\tstatus\tevidence\n'
  printf 'redis\tPASS\truntime-redis.log\n'
  printf 'object_storage\tPASS\truntime-minio.log\n'
  printf 'kafka\tPASS-SINGLE-NODE\truntime-kafka.log\n'
  printf 'nacos\tPASS\truntime-nacos.log\n'
  printf 'temporal_mysql\tPENDING\tmanual-schema-and-workflow-smoke\n'
} >"$EVIDENCE/runtime-smoke.tsv"
printf 'BASE-002 runtime smoke PASS (Temporal/MySQL and Kafka RF3 remain pending)\n'
