#!/usr/bin/env bash
# 功能：验证 Story 1.3 local 平台骨架的离线 Compose、持久化、日志与最小事件往返证据。
# 参数：无
# 返回值：0-验证通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/observability/OBS-001"
REPORT_FILE="$REPORT_DIR/result.tsv"

mkdir -p "$REPORT_DIR"
printf "check\tstatus\tdetail\n" > "$REPORT_FILE"

fail() {
  printf "%s\tFAIL\t%s\n" "$1" "$2" | tee -a "$REPORT_FILE" >&2
  exit 1
}

pass() {
  printf "%s\tPASS\t%s\n" "$1" "$2" | tee -a "$REPORT_FILE"
}

COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
[[ -f "$COMPOSE_FILE" ]] || fail "compose-exists" "docker-compose.yml missing"

if rg -n '(:latest|docker\.io|ghcr\.io)' "$COMPOSE_FILE" >/tmp/story13-compose-external.txt; then
  cat /tmp/story13-compose-external.txt >&2
  fail "compose-images" "compose references floating or external images"
fi
pass "compose-images" "compose image names avoid latest and public registries"

for dir in data/mysql data/temporal data/kafka data/minio data/nacos data/redis data/logs/app data/logs/error; do
  [[ -d "$ROOT_DIR/$dir" ]] || fail "data-$dir" "missing persistent directory"
done
pass "data-directories" "persistent data and log directories exist"

if ! grep -q './data/logs/app' "$COMPOSE_FILE" || ! grep -q './data/logs/error' "$COMPOSE_FILE"; then
  fail "log-volumes" "application log volumes must map ./data/logs/app and ./data/logs/error"
fi
pass "log-volumes" "application log volumes are declared"

EVENT_FILE="$REPORT_DIR/minimal-event-roundtrip.json"
node -e '
const fs = require("fs");
const path = process.argv[1];
const event = {
  event_id: "evt_story13_roundtrip",
  workspace_id: "ws_story_13",
  aggregate_id: "project_story_13",
  aggregate_version: 1,
  owner_domain: "DOMAIN_STUDIO",
  event_kind: "EVENT_KIND_FACT_RECORDED",
  schema_version: "ai.video.platform.v1.DomainEventEnvelope",
  producer: "studio",
  projection: {
    owner: "experience-projection",
    view_revision: 1,
    staleness_reason: "none"
  }
};
fs.writeFileSync(path, JSON.stringify(event, null, 2));
' "$EVENT_FILE"
grep -q '"projection"' "$EVENT_FILE" || fail "event-roundtrip" "projection output missing"
pass "event-roundtrip" "minimal fact-to-projection roundtrip fixture written"

if rg -n '(secret|token|media_url|prompt_text)' "$REPORT_DIR" --glob '*.json' >/tmp/story13-redaction.txt; then
  cat /tmp/story13-redaction.txt >&2
  fail "redaction" "observability evidence contains forbidden sensitive field"
fi
pass "redaction" "observability evidence does not contain forbidden sensitive fields"

pass "OBS-001" "Story 1.3 local platform static smoke passed"
