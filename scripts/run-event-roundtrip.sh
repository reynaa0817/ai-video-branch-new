#!/usr/bin/env bash
# 功能：执行 Story 1.3 最小事实事件往返，生成 OBS-001 运行时证据。
# 参数：$1-输出 JSON 证据路径。
# 返回值：0-事实/outbox/Kafka/projection 均可关联，1-执行失败。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:?usage: run-event-roundtrip.sh <output-json>}"
ENV_FILE="${AI_VIDEO_ENV_FILE:?AI_VIDEO_ENV_FILE is required}"
PROJECT="${AI_VIDEO_COMPOSE_PROJECT:?AI_VIDEO_COMPOSE_PROJECT is required}"
COMPOSE_FILE="${AI_VIDEO_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-roundtrip.XXXXXX")"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")
TOPIC="ai-video-story13-events"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# 加载受保护 env 文件，仅用于容器内 mysql 客户端认证；不打印敏感值。
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

EVENT_ID="evt_story13_$(date -u +%Y%m%d%H%M%S)_$$"
OCCURRED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PAYLOAD="$(printf '%s' '{"fact":"ProjectCreationSkeleton"}' | base64 | tr -d '\n')"
ENVELOPE_FILE="$WORK_DIR/envelope.json"
SQL_FILE="$WORK_DIR/roundtrip.sql"
EVIDENCE_FILE="$WORK_DIR/evidence.json"

node - "$EVENT_ID" "$OCCURRED_AT" "$PAYLOAD" "$ENVELOPE_FILE" <<'NODE'
const fs = require("fs");
const [eventId, occurredAt, payload, output] = process.argv.slice(2);
const envelope = {
  event_id: eventId,
  workspace_id: "ws_story_13_runtime",
  aggregate_id: "project_story_13_runtime",
  aggregate_version: 1,
  owner_domain: "DOMAIN_STUDIO",
  event_kind: "EVENT_KIND_FACT_RECORDED",
  schema_version: "ai.video.platform.v1.DomainEventEnvelope",
  occurred_at: occurredAt,
  producer: "studio",
  trace: {
    trace_id: `trace_${eventId}`,
    span_id: "span_studio_outbox",
    request_id: `req_${eventId}`,
  },
  payload,
};
fs.writeFileSync(output, `${JSON.stringify(envelope)}\n`);
NODE

node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$ENVELOPE_FILE" >/dev/null
ENVELOPE_JSON="$(tr -d '\n' < "$ENVELOPE_FILE")"

node - "$EVENT_ID" "$ENVELOPE_JSON" "$SQL_FILE" <<'NODE'
const fs = require("fs");
const [eventId, envelopeJson, output] = process.argv.slice(2);
const quote = (value) => `'${String(value).replace(/'/g, "''")}'`;
const sql = `
CREATE TABLE IF NOT EXISTS story13_facts (
  event_id VARCHAR(96) PRIMARY KEY,
  aggregate_id VARCHAR(128) NOT NULL,
  aggregate_version BIGINT NOT NULL,
  envelope_json JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS story13_outbox (
  event_id VARCHAR(96) PRIMARY KEY,
  envelope_json JSON NOT NULL,
  published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  published_at TIMESTAMP NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS story13_projection (
  event_id VARCHAR(96) PRIMARY KEY,
  aggregate_id VARCHAR(128) NOT NULL,
  aggregate_version BIGINT NOT NULL,
  projection_state VARCHAR(64) NOT NULL,
  projected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO story13_facts(event_id, aggregate_id, aggregate_version, envelope_json)
VALUES (${quote(eventId)}, 'project_story_13_runtime', 1, CAST(${quote(envelopeJson)} AS JSON))
ON DUPLICATE KEY UPDATE aggregate_version=VALUES(aggregate_version), envelope_json=VALUES(envelope_json);
INSERT INTO story13_outbox(event_id, envelope_json, published)
VALUES (${quote(eventId)}, CAST(${quote(envelopeJson)} AS JSON), FALSE)
ON DUPLICATE KEY UPDATE envelope_json=VALUES(envelope_json), published=FALSE, published_at=NULL;
`;
fs.writeFileSync(output, sql);
NODE

"${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysql -uroot "$MYSQL_DATABASE" < "$SQL_FILE"

"${COMPOSE[@]}" exec -T kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:29092 \
  --create --if-not-exists \
  --topic "$TOPIC" \
  --partitions 1 \
  --replication-factor 1 >/dev/null

printf '%s\t%s\n' "$EVENT_ID" "$ENVELOPE_JSON" | "${COMPOSE[@]}" exec -T kafka \
  /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server kafka:29092 \
  --topic "$TOPIC" \
  --property parse.key=true \
  --property key.separator=$'\t' >/dev/null

"${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysql -uroot "$MYSQL_DATABASE" \
  -e "UPDATE story13_outbox SET published=TRUE, published_at=CURRENT_TIMESTAMP WHERE event_id='${EVENT_ID}';"

set +e
CONSUMED="$("${COMPOSE[@]}" exec -T kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka:29092 \
  --topic "$TOPIC" \
  --from-beginning \
  --timeout-ms 20000 \
  --property print.key=true \
  --property key.separator=$'\t' 2>/dev/null \
  | awk -F '\t' -v id="$EVENT_ID" '$1 == id {print $2; found=1; exit} END {if (!found) exit 1}')"
consumer_rc=$?
set -e
if [[ $consumer_rc -ne 0 || -z "$CONSUMED" ]]; then
  echo "event $EVENT_ID was not observed on Kafka topic $TOPIC" >&2
  exit 1
fi

if [[ "$CONSUMED" != "$ENVELOPE_JSON" ]]; then
  echo "Kafka payload mismatch for $EVENT_ID" >&2
  exit 1
fi

OFFSET_LINE="$("${COMPOSE[@]}" exec -T kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic "$TOPIC" \
  --time -1 | head -n 1 | tr -d '\r')"
PARTITION="$(printf '%s' "$OFFSET_LINE" | awk -F ':' '{print $2}')"
NEXT_OFFSET="$(printf '%s' "$OFFSET_LINE" | awk -F ':' '{print $3}')"
OFFSET="$((NEXT_OFFSET - 1))"

"${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysql -uroot "$MYSQL_DATABASE" \
  -e "INSERT INTO story13_projection(event_id, aggregate_id, aggregate_version, projection_state) VALUES ('${EVENT_ID}', 'project_story_13_runtime', 1, 'projected') ON DUPLICATE KEY UPDATE aggregate_version=VALUES(aggregate_version), projection_state=VALUES(projection_state);"

node - "$EVENT_ID" "$PARTITION" "$OFFSET" "$ENVELOPE_FILE" "$EVIDENCE_FILE" <<'NODE'
const fs = require("fs");
const [eventId, partitionRaw, offsetRaw, envelopePath, output] = process.argv.slice(2);
const envelope = JSON.parse(fs.readFileSync(envelopePath, "utf8"));
const partition = Number.parseInt(partitionRaw, 10);
const offset = Number.parseInt(offsetRaw, 10);
if (!Number.isInteger(partition) || !Number.isInteger(offset) || offset < 0) {
  throw new Error("invalid Kafka partition/offset evidence");
}
const evidence = {
  fact: {
    event_id: eventId,
    aggregate_id: envelope.aggregate_id,
    aggregate_version: envelope.aggregate_version,
    storage: "mysql.story13_facts",
  },
  outbox: {
    event_id: eventId,
    published: true,
    storage: "mysql.story13_outbox",
  },
  kafka: {
    event_id: eventId,
    topic: "ai-video-story13-events",
    partition,
    offset,
  },
  projection: {
    event_id: eventId,
    aggregate_id: envelope.aggregate_id,
    aggregate_version: envelope.aggregate_version,
    storage: "mysql.story13_projection",
  },
  envelope,
};
fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`);
NODE

mkdir -p "$(dirname "$OUTPUT")"
cp "$EVIDENCE_FILE" "$OUTPUT"
