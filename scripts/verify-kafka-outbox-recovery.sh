#!/usr/bin/env bash
# 功能：验证 Kafka 故障期间 Studio 仍持久化未发布 outbox，Kafka 恢复后 relay/consumer 自动补偿。

set -euo pipefail

OUTPUT="${1:?usage: verify-kafka-outbox-recovery.sh <output-json>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${AI_VIDEO_ENV_FILE:?AI_VIDEO_ENV_FILE is required}"
PROJECT="${AI_VIDEO_COMPOSE_PROJECT:?AI_VIDEO_COMPOSE_PROJECT is required}"
COMPOSE_FILE="${AI_VIDEO_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-kafka-recovery.XXXXXX")"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

EVENT_ID="evt_story13_recovery_$(date -u +%Y%m%d%H%M%S)_$$"
OCCURRED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ENVELOPE_FILE="$WORK_DIR/envelope.json"
STUDIO_BEFORE="$WORK_DIR/studio-before.json"
STUDIO_AFTER="$WORK_DIR/studio-after.json"
PROJECTION_AFTER="$WORK_DIR/projection-after.json"

node - "$EVENT_ID" "$OCCURRED_AT" "$ENVELOPE_FILE" <<'NODE'
const fs = require("fs");
const [eventId, occurredAt, output] = process.argv.slice(2);
const envelope = {
  event_id: eventId,
  workspace_id: "ws_story_13_runtime",
  aggregate_id: "project_story_13_runtime",
  aggregate_version: 1,
  owner_domain: "studio",
  event_kind: "ProjectCreationSkeleton",
  schema_version: "ai.video.platform.v1.DomainEventEnvelope",
  occurred_at: occurredAt,
  producer: "studio",
  trace: {trace_id: `trace_${eventId}`, span_id: "span_studio_recovery", request_id: `req_${eventId}`},
  payload: Buffer.from(JSON.stringify({fact: "KafkaOutageRecoveryProbe"})).toString("base64"),
};
fs.writeFileSync(output, `${JSON.stringify(envelope)}\n`);
NODE

node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$ENVELOPE_FILE" >/dev/null
ENVELOPE_BASE64="$(base64 <"$ENVELOPE_FILE" | tr -d '\r\n')"

"${COMPOSE[@]}" stop kafka >/dev/null
"${COMPOSE[@]}" exec -T -e PROBE_ENVELOPE_BASE64="$ENVELOPE_BASE64" studio /app/server record-probe >/dev/null
"${COMPOSE[@]}" exec -T -e PROBE_EVENT_ID="$EVENT_ID" studio /app/server inspect-roundtrip >"$STUDIO_BEFORE"
node - "$STUDIO_BEFORE" <<'NODE'
const fs = require("fs");
const studio = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (studio.outbox?.published !== false) throw new Error("outbox was published while Kafka was stopped");
NODE

"${COMPOSE[@]}" up -d --wait --wait-timeout 180 kafka >/dev/null

deadline=$((SECONDS + 60))
while :; do
  if "${COMPOSE[@]}" exec -T -e PROBE_EVENT_ID="$EVENT_ID" studio /app/server inspect-roundtrip >"$STUDIO_AFTER" 2>/dev/null \
    && "${COMPOSE[@]}" exec -T -e PROBE_EVENT_ID="$EVENT_ID" experience-projection /app/server inspect-projection >"$PROJECTION_AFTER" 2>/dev/null; then
    if node - "$STUDIO_AFTER" "$PROJECTION_AFTER" <<'NODE'
const fs = require("fs");
const studio = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const projection = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
if (studio.outbox?.published !== true) process.exit(1);
if (studio.outbox.partition !== projection.partition || studio.outbox.offset !== projection.offset) process.exit(1);
NODE
    then
      break
    fi
  fi
  if (( SECONDS >= deadline )); then
    echo "event $EVENT_ID did not recover after Kafka restart" >&2
    exit 1
  fi
  sleep 1
done

node - "$ENVELOPE_FILE" "$STUDIO_BEFORE" "$STUDIO_AFTER" "$PROJECTION_AFTER" "$OUTPUT" <<'NODE'
const fs = require("fs");
const [envelopePath, beforePath, afterPath, projectionPath, output] = process.argv.slice(2);
const envelope = JSON.parse(fs.readFileSync(envelopePath, "utf8"));
const before = JSON.parse(fs.readFileSync(beforePath, "utf8"));
const after = JSON.parse(fs.readFileSync(afterPath, "utf8"));
const projection = JSON.parse(fs.readFileSync(projectionPath, "utf8"));
const evidence = {
  event_id: envelope.event_id,
  fact_persisted_during_outage: before.fact.event_id === envelope.event_id,
  outbox_unpublished_during_outage: before.outbox.published === false,
  outbox_published_after_recovery: after.outbox.published === true,
  projection_observed_after_recovery: projection.event_id === envelope.event_id,
  kafka: {partition: projection.partition, offset: projection.offset},
};
fs.mkdirSync(require("path").dirname(output), {recursive: true});
fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`);
NODE
