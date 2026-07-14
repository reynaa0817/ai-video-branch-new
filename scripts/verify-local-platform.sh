#!/usr/bin/env bash
# 功能：验证 Story 1.3 Compose 配置，并在默认模式执行真实健康、事件往返与 fail-closed 验收。
# 参数：--config-only 仅验证静态 Compose 配置，不得记为 OBS-001 GREEN。
# 返回值：0-所选模式通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/observability/OBS-001"
REPORT_FILE="$REPORT_DIR/result.tsv"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-observability.XXXXXX")"
REPORT_TMP="$WORK_DIR/result.tsv"
MODE="${1:-runtime}"
PROJECT="ai-video-obs-${CI_RUN_ID:-$$}"
ENV_FILE="${AI_VIDEO_ENV_FILE:-$ROOT_DIR/.env.example}"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml")
STARTED=false

cleanup() {
  if [[ -f "$REPORT_TMP" ]]; then
    mkdir -p "$REPORT_DIR"
    cp "$REPORT_TMP" "$REPORT_FILE.$$.tmp"
    mv "$REPORT_FILE.$$.tmp" "$REPORT_FILE"
  fi
  if [[ "$STARTED" == true ]]; then
    "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$REPORT_DIR"
rm -f "$REPORT_DIR/minimal-event-roundtrip.json"
printf "check\tstatus\tdetail\n" > "$REPORT_TMP"

fail() {
  printf "%s\tFAIL\t%s\n" "$1" "$2" | tee -a "$REPORT_TMP" >&2
  exit 1
}

pass() {
  printf "%s\tPASS\t%s\n" "$1" "$2" | tee -a "$REPORT_TMP"
}

not_run() {
  printf "%s\tNOT_RUN\t%s\n" "$1" "$2" | tee -a "$REPORT_TMP"
}

[[ "$MODE" == "runtime" || "$MODE" == "--config-only" ]] || fail "arguments" "usage: verify-local-platform.sh [--config-only]"
for tool in docker node rg; do
  command -v "$tool" >/dev/null 2>&1 || fail "tool-$tool" "$tool is required"
done
docker compose version >/dev/null 2>&1 || fail "compose-tool" "Docker Compose plugin is required"

"${COMPOSE[@]}" config --format json >"$WORK_DIR/compose.json" || fail "compose-config" "docker compose config failed"
if [[ "$MODE" == "runtime" ]]; then
  [[ "$ENV_FILE" != "$ROOT_DIR/.env.example" ]] || fail "runtime-secrets" "set AI_VIDEO_ENV_FILE to a protected non-example env file"
  node - "$WORK_DIR/compose.json" <<'NODE' || fail "runtime-secrets" "runtime credentials still use example/default values"
const fs = require("fs");
const services = JSON.parse(fs.readFileSync(process.argv[2], "utf8")).services ?? {};
const forbidden = new Set(["change-me-local", "minioadmin", "", undefined]);
for (const [service, keys] of Object.entries({mysql: ["MYSQL_ROOT_PASSWORD"], minio: ["MINIO_ROOT_USER", "MINIO_ROOT_PASSWORD"]})) {
  for (const key of keys) if (forbidden.has(services[service]?.environment?.[key])) throw new Error(`${service}.${key} is not protected`);
}
NODE
fi
node - "$WORK_DIR/compose.json" "$ROOT_DIR/contracts/services.yaml" <<'NODE' || fail "compose-policy" "Compose policy validation failed"
const fs = require("fs");
const compose = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const registry = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const services = compose.services ?? {};
const requiredInfra = ["mysql", "temporal", "kafka", "minio", "nacos", "redis"];
for (const name of [...requiredInfra, ...Object.keys(registry.services)]) {
  if (!services[name]) throw new Error(`missing Compose service ${name}`);
}
for (const [name, service] of Object.entries(services)) {
  if (typeof service.image !== "string" || !service.image.startsWith("local.ai-video/")) throw new Error(`${name} must use local.ai-video registry`);
  const tag = service.image.split(":").at(-1);
  if (!tag || tag === "latest" || !/(?:\d|[a-f0-9]{7,})/.test(tag)) throw new Error(`${name} image tag is floating or unversioned`);
  if (service.pull_policy !== "never") throw new Error(`${name} must set pull_policy: never`);
  for (const port of service.ports ?? []) {
    if (port.host_ip !== "127.0.0.1") throw new Error(`${name} published port must bind to 127.0.0.1`);
  }
}
for (const name of requiredInfra) {
  if (!(services[name].healthcheck?.test?.length > 0)) throw new Error(`${name} lacks an executable healthcheck`);
}
const advertised = String(services.kafka.environment?.KAFKA_ADVERTISED_LISTENERS ?? "");
if (!advertised.includes("INTERNAL://kafka:") || !advertised.includes("EXTERNAL://localhost:")) throw new Error("Kafka must advertise separate container and host listeners");
for (const name of Object.keys(registry.services)) {
  const service = services[name];
  const test = service.healthcheck?.test ?? [];
  if (JSON.stringify(test) !== JSON.stringify(["CMD", "/app/server", "health"])) throw new Error(`${name} lacks executable health command`);
  const deps = service.depends_on ?? {};
  if (Array.isArray(deps)) throw new Error(`${name} depends_on must use service_healthy conditions`);
  for (const [dependency, policy] of Object.entries(deps)) {
    if (policy?.condition !== "service_healthy") throw new Error(`${name} dependency ${dependency} must require service_healthy`);
  }
  const volumes = (service.volumes ?? []).map((volume) => String(volume.source ?? volume));
  if (!volumes.some((value) => value.includes("data/logs/app")) || !volumes.some((value) => value.includes("data/logs/error"))) throw new Error(`${name} lacks app/error log volumes`);
  if (String(service.environment?.LOG_RETENTION_DAYS) !== "30") throw new Error(`${name} log retention must be 30 days`);
  const tcpReadiness = String(service.environment?.REQUIRED_TCP_ENDPOINTS ?? "");
  for (const dependency of Object.keys(deps)) {
    if (["mysql", "kafka", "temporal", "minio"].includes(dependency) && !tcpReadiness.includes(`${dependency}=`)) {
      throw new Error(`${name} health command does not probe ${dependency}`);
    }
  }
  if (tcpReadiness && String(service.environment?.READINESS_TIMEOUT_SECONDS ?? "") === "") {
    throw new Error(`${name} readiness timeout must be explicit`);
  }
}
NODE
pass "compose-config" "Compose parses; images are no-pull, host ports are loopback-only, and declared health/log policies are explicit"

for dir in data/mysql data/temporal data/kafka data/minio data/nacos data/redis data/logs/app data/logs/error; do
  [[ -d "$ROOT_DIR/$dir" && -w "$ROOT_DIR/$dir" ]] || fail "data-$dir" "persistent directory is missing or not writable"
done
pass "data-directories" "persistent data and log directories exist and are writable"

if [[ "$MODE" == "--config-only" ]]; then
  not_run "event-roundtrip" "runtime chain was intentionally not executed in config-only mode"
  not_run "dependency-fail-closed" "dependency fault injection was intentionally not executed in config-only mode"
  not_run "OBS-001" "config-only is not runtime evidence and must not be treated as GREEN"
  exit 0
fi

STARTED=true
"${COMPOSE[@]}" up -d --wait --wait-timeout 180 || fail "platform-start" "OBS_PLATFORM_UNAVAILABLE: Compose services did not become healthy"
"${COMPOSE[@]}" ps --format json >"$WORK_DIR/ps.jsonl" || fail "platform-health" "could not inspect Compose health"
node - "$WORK_DIR/ps.jsonl" <<'NODE' || fail "platform-health" "one or more Compose services are not running/healthy"
const fs = require("fs");
const rows = fs.readFileSync(process.argv[2], "utf8").trim().split(/\n+/).filter(Boolean).map((line) => JSON.parse(line));
if (rows.length === 0) throw new Error("no Compose services running");
for (const row of rows) {
  if (row.State !== "running") throw new Error(`${row.Service} is ${row.State}`);
  if (row.Health !== "healthy") throw new Error(`${row.Service} has no healthy readiness result (${row.Health || "missing"})`);
}
NODE
pass "platform-health" "all Compose services are running and declared health checks are healthy"

ROUNDTRIP="$ROOT_DIR/scripts/run-event-roundtrip.sh"
[[ -x "$ROUNDTRIP" ]] || fail "event-roundtrip" "OBS_RUNTIME_NOT_IMPLEMENTED: executable roundtrip driver is missing"
export AI_VIDEO_COMPOSE_PROJECT="$PROJECT"
export AI_VIDEO_COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
export AI_VIDEO_ENV_FILE
"$ROUNDTRIP" "$REPORT_DIR/minimal-event-roundtrip.json" || fail "event-roundtrip" "OBS_EVENT_ROUNDTRIP_FAILED: persistence/outbox/Kafka/projection chain failed"
node - "$REPORT_DIR/minimal-event-roundtrip.json" "$WORK_DIR/roundtrip-envelope.json" <<'NODE' || fail "event-roundtrip" "roundtrip evidence lacks independently correlatable fact/outbox/Kafka/projection proof"
const fs = require("fs");
const evidence = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const required = ["fact", "outbox", "kafka", "projection"];
for (const key of required) if (!evidence[key] || typeof evidence[key] !== "object") throw new Error(`missing ${key} proof`);
const ids = required.map((key) => evidence[key].event_id);
if (ids.some((id) => typeof id !== "string" || id.length === 0) || new Set(ids).size !== 1) throw new Error("event_id does not correlate all stages");
if (!Number.isInteger(evidence.fact.aggregate_version) || evidence.fact.aggregate_version < 1) throw new Error("invalid fact version");
if (evidence.outbox.published !== true || !Number.isInteger(evidence.kafka.partition) || !Number.isInteger(evidence.kafka.offset)) throw new Error("missing publish/offset proof");
if (evidence.projection.aggregate_version !== evidence.fact.aggregate_version) throw new Error("projection version does not match fact version");
if (!evidence.envelope || typeof evidence.envelope !== "object") throw new Error("missing envelope");
fs.writeFileSync(process.argv[3], `${JSON.stringify(evidence.envelope)}\n`);
NODE
node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$WORK_DIR/roundtrip-envelope.json" || fail "event-roundtrip" "roundtrip envelope is invalid"
pass "event-roundtrip" "fact persisted, traversed outbox/Kafka and was observed in the projection view"

FAIL_CLOSED="$ROOT_DIR/scripts/verify-fail-closed.sh"
[[ -x "$FAIL_CLOSED" ]] || fail "dependency-fail-closed" "OBS_FAIL_CLOSED_NOT_IMPLEMENTED: fault-injection driver is missing"
FAIL_CLOSED_EVIDENCE="$WORK_DIR/fail-closed.json"
"$FAIL_CLOSED" "$FAIL_CLOSED_EVIDENCE" || fail "dependency-fail-closed" "Budget/storage/Quality/Temporal dependency loss did not fail closed"
node - "$FAIL_CLOSED_EVIDENCE" <<'NODE' || fail "dependency-fail-closed" "fault-injection evidence is incomplete"
const fs = require("fs");
const evidence = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
for (const dependency of ["budget", "object_storage", "quality", "temporal"]) {
  const item = evidence[dependency];
  if (!item || item.injected !== true || item.command_rejected !== true || item.state_advanced !== false) throw new Error(`${dependency} was not proven fail-closed`);
}
NODE
pass "dependency-fail-closed" "dependency fault injection remained fail-closed"

"${COMPOSE[@]}" logs --no-color >"$WORK_DIR/runtime.log" || fail "redaction" "could not collect runtime logs"
set +e
rg -ni '(secret|password|access[_-]?token|bearer[[:space:]]+|media[_-]?url|prompt[_-]?text|https?://)' "$WORK_DIR/runtime.log" "$REPORT_DIR" "$ROOT_DIR/data/logs" --glob '*.json' --glob '*.log'
redaction_rc=$?
set -e
if [[ $redaction_rc -eq 0 ]]; then
  fail "redaction" "OBS_SENSITIVE_DATA: runtime logs, trace or evidence contains forbidden content"
fi
[[ $redaction_rc -eq 1 ]] || fail "redaction" "redaction scanner could not read all runtime evidence"
pass "redaction" "runtime logs, trace and evidence passed case-insensitive sensitive-data scan"

pass "OBS-001" "Story 1.3 runtime observability and fact-to-projection checks passed"
