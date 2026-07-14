#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
RUN="base002-kafka-$$"
NETWORK="$RUN-net"
IMAGE='apache/kafka@sha256:3f7b939115cd4872e9cee9369d80bd69712fde55f9902f46d793f64848dedc75'
KAFKA_BIN=/opt/kafka/bin

cleanup() {
  docker rm -f "$RUN-1" "$RUN-2" "$RUN-3" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
cleanup
docker network create "$NETWORK" >/dev/null

voters="1@$RUN-1:19093,2@$RUN-2:19093,3@$RUN-3:19093"
for node in 1 2 3; do
  name="$RUN-$node"
  docker run -d --name "$name" --network "$NETWORK" \
    -e KAFKA_NODE_ID="$node" -e KAFKA_PROCESS_ROLES=broker,controller \
    -e KAFKA_LISTENERS=PLAINTEXT://:19092,CONTROLLER://:19093 \
    -e KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://$name:19092" \
    -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS="$voters" \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=3 \
    -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3 \
    -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=2 \
    -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
    -e KAFKA_HEAP_OPTS='-Xms256m -Xmx256m' \
    -e CLUSTER_ID=4L6g3nShT-eMCtK--X86sw "$IMAGE" >/dev/null
done

bootstrap="$RUN-1:19092,$RUN-2:19092,$RUN-3:19092"
attempt=0
until docker exec "$RUN-1" "$KAFKA_BIN/kafka-metadata-quorum.sh" --bootstrap-server "$bootstrap" describe --status >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 120 ] || { docker logs "$RUN-1" >&2; exit 1; }; sleep 1
done

docker exec "$RUN-1" "$KAFKA_BIN/kafka-topics.sh" --bootstrap-server "$bootstrap" --create \
  --topic ai-video-int-events --partitions 3 --replication-factor 3 --config min.insync.replicas=2 >/dev/null
docker exec "$RUN-1" "$KAFKA_BIN/kafka-topics.sh" --bootstrap-server "$bootstrap" --create \
  --topic ai-video-int-events.dlq --partitions 3 --replication-factor 3 --config min.insync.replicas=2 >/dev/null
describe=$(docker exec "$RUN-1" "$KAFKA_BIN/kafka-topics.sh" --bootstrap-server "$bootstrap" --describe --topic ai-video-int-events)
printf '%s\n' "$describe" >"$EVIDENCE/kafka-rf3-topic.txt"
printf '%s\n' "$describe" | grep -q 'ReplicationFactor: 3'
printf '%s\n' "$describe" | grep -q 'min.insync.replicas=2'

printf 'persisted-fact-before-fault\n' | docker exec -i "$RUN-1" "$KAFKA_BIN/kafka-console-producer.sh" \
  --bootstrap-server "$bootstrap" --topic ai-video-int-events --producer-property acks=all >/dev/null
leader=$(printf '%s\n' "$describe" | awk '/Partition: 0/ { for (i=1; i<=NF; i++) if ($i == "Leader:") { print $(i+1); exit } }')
[ -n "$leader" ]
client=1
[ "$leader" != 1 ] || client=2
docker stop "$RUN-$leader" >/dev/null

attempt=0
until printf 'persisted-fact-during-fault\n' | docker exec -i "$RUN-$client" "$KAFKA_BIN/kafka-console-producer.sh" \
  --bootstrap-server "$bootstrap" --topic ai-video-int-events --producer-property acks=all \
  --producer-property max.block.ms=5000 >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 30 ] || exit 1; sleep 1
done
count=$(docker exec "$RUN-$client" "$KAFKA_BIN/kafka-console-consumer.sh" --bootstrap-server "$bootstrap" \
  --topic ai-video-int-events --from-beginning --group base002-fault --max-messages 2 --timeout-ms 15000 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = 2 ]

docker start "$RUN-$leader" >/dev/null
attempt=0
until docker exec "$RUN-$leader" "$KAFKA_BIN/kafka-broker-api-versions.sh" --bootstrap-server "$bootstrap" >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 60 ] || exit 1; sleep 1
done
for node in 1 2 3; do docker logs "$RUN-$node" >"$EVIDENCE/kafka-rf3-node-$node.log" 2>&1; done
{
  printf 'field\tvalue\n'
  printf 'brokers\t3\n'
  printf 'replication_factor\t3\n'
  printf 'min_insync_replicas\t2\n'
  printf 'produce_consume\tPASS\n'
  printf 'leader_failure\tPASS\n'
  printf 'dlq_topic\tPASS\n'
  printf 'rebalance_two_consumers\tPENDING\n'
} >"$EVIDENCE/kafka-rf3-smoke.tsv"
printf 'BASE-002 Kafka RF3/minISR2 leader-failure smoke PASS; two-consumer rebalance PENDING\n'
