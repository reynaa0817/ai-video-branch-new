#!/usr/bin/env bash
# 功能：通过 Studio 应用命令、Outbox/Kafka 和 Experience Projection 消费者执行真实最小事件往返。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:?usage: run-event-roundtrip.sh <output-json>}"
ENV_FILE="${AI_VIDEO_ENV_FILE:?AI_VIDEO_ENV_FILE is required}"
PROJECT="${AI_VIDEO_COMPOSE_PROJECT:?AI_VIDEO_COMPOSE_PROJECT is required}"
COMPOSE_FILE="${AI_VIDEO_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-roundtrip.XXXXXX")"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

EVENT_ID="evt_story13_$(date -u +%Y%m%d%H%M%S)_$$"
OCCURRED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ENVELOPE_FILE="$WORK_DIR/envelope.json"
STUDIO_FILE="$WORK_DIR/studio.json"
PROJECTION_FILE="$WORK_DIR/projection.json"

node - "$EVENT_ID" "$OCCURRED_AT" "$ENVELOPE_FILE" <<'NODE'
const fs = require("fs");
const [eventId, occurredAt, output] = process.argv.slice(2);
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
  trace: {trace_id: `trace_${eventId}`, span_id: "span_studio_outbox", request_id: `req_${eventId}`},
  payload: Buffer.from(JSON.stringify({fact: "PlatformRoundtripProbe"})).toString("base64"),
};
fs.writeFileSync(output, `${JSON.stringify(envelope)}\n`);
NODE

node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$ENVELOPE_FILE" >/dev/null
ENVELOPE_BASE64="$(base64 <"$ENVELOPE_FILE" | tr -d '\r\n')"

"${COMPOSE[@]}" exec -T -e PROBE_ENVELOPE_BASE64="$ENVELOPE_BASE64" studio /app/server record-probe >/dev/null

deadline=$((SECONDS + 45))
while :; do
  if "${COMPOSE[@]}" exec -T -e PROBE_EVENT_ID="$EVENT_ID" studio /app/server inspect-roundtrip >"$STUDIO_FILE" 2>/dev/null \
    && "${COMPOSE[@]}" exec -T -e PROBE_EVENT_ID="$EVENT_ID" experience-projection /app/server inspect-projection >"$PROJECTION_FILE" 2>/dev/null; then
    if node - "$STUDIO_FILE" "$PROJECTION_FILE" <<'NODE'
const fs = require("fs");
const studio = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const projection = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
if (studio.outbox?.published !== true) process.exit(1);
if (!Number.isInteger(studio.outbox.partition) || !Number.isInteger(studio.outbox.offset) || studio.outbox.offset < 0) process.exit(1);
if (studio.outbox.partition !== projection.partition || studio.outbox.offset !== projection.offset) process.exit(1);
NODE
    then
      break
    fi
  fi
  if (( SECONDS >= deadline )); then
    echo "event $EVENT_ID was not published and projected before timeout" >&2
    exit 1
  fi
  sleep 1
done

node - "$ENVELOPE_FILE" "$STUDIO_FILE" "$PROJECTION_FILE" "$OUTPUT" <<'NODE'
const fs = require("fs");
const [envelopePath, studioPath, projectionPath, output] = process.argv.slice(2);
const envelope = JSON.parse(fs.readFileSync(envelopePath, "utf8"));
const studio = JSON.parse(fs.readFileSync(studioPath, "utf8"));
const projection = JSON.parse(fs.readFileSync(projectionPath, "utf8"));
if (!studio.outbox.published) throw new Error("outbox was not acknowledged");
if (studio.outbox.partition !== projection.partition || studio.outbox.offset !== projection.offset) {
  throw new Error("producer acknowledgement does not match consumed Kafka record");
}
if (projection.trace_id !== envelope.trace.trace_id || projection.span_id !== envelope.trace.span_id || projection.request_id !== envelope.trace.request_id) {
  throw new Error("trace correlation was not propagated through the projection consumer");
}
if (studio.fact.workspace_id !== envelope.workspace_id || projection.workspace_id !== envelope.workspace_id) throw new Error("workspace identity was not preserved");
if (studio.fact.envelope_digest !== projection.envelope_digest || studio.outbox.envelope_digest !== projection.envelope_digest) throw new Error("envelope digest mismatch");
const evidence = {
  fact: studio.fact,
  outbox: studio.outbox,
  kafka: {event_id: envelope.event_id, topic: "ai-video-story13-events", partition: projection.partition, offset: projection.offset},
  projection,
  envelope,
};
fs.mkdirSync(require("path").dirname(output), {recursive: true});
fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`);
NODE
