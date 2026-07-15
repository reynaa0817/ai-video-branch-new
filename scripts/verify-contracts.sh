#!/usr/bin/env bash
# 功能：以真实 Proto decoder、breaking 基线和服务注册表验证 Story 1.3 契约边界。
# 参数：无
# 返回值：0-验证通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/contracts/CONTRACT-001"
REPORT_FILE="$REPORT_DIR/result.tsv"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-contract.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$REPORT_DIR"
printf "check\tstatus\tdetail\n" > "$REPORT_FILE"

fail() {
  printf "%s\tFAIL\t%s\n" "$1" "$2" | tee -a "$REPORT_FILE" >&2
  exit 1
}

pass() {
  printf "%s\tPASS\t%s\n" "$1" "$2" | tee -a "$REPORT_FILE"
}

for tool in buf node go rg; do
  command -v "$tool" >/dev/null 2>&1 || fail "tool-$tool" "$tool is required"
done

PROTO_DIR="$ROOT_DIR/contracts/proto"
PROTO_FILE="$PROTO_DIR/ai/video/platform/v1/envelope.proto"
BASELINE_DIR="$ROOT_DIR/contracts/proto-baseline"
MESSAGE_TYPE="ai.video.platform.v1.DomainEventEnvelope"

buf lint "$PROTO_DIR" || fail "proto-lint" "buf lint rejected the v1 contract"
buf build "$PROTO_DIR" -o "$WORK_DIR/current.binpb" || fail "proto-build" "buf could not compile the v1 contract"
buf breaking "$PROTO_DIR" --against "$BASELINE_DIR" || fail "proto-breaking" "CONTRACT_BREAKING_CHANGE: v1 is incompatible with the locked baseline"
pass "proto-schema" "buf lint/build and breaking comparison passed"

decode() {
  local vector="$1"
  local output="$2"
  buf convert "$PROTO_FILE" \
    --type "$MESSAGE_TYPE" \
    --from "$vector#format=json" \
    --to "$output#format=binpb"
}

VALID_VECTOR="$ROOT_DIR/contracts/golden/event-envelope.valid.json"
decode "$VALID_VECTOR" "$WORK_DIR/valid.binpb" || fail "golden-valid-decode" "CONTRACT_INVALID_ENVELOPE: valid vector did not decode"
node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$VALID_VECTOR" || fail "golden-valid-semantics" "CONTRACT_INVALID_ENVELOPE: semantic validation failed"
pass "golden-valid" "valid vector decoded with buf and passed semantic constraints"

if decode "$ROOT_DIR/contracts/golden/event-envelope.unknown-enum.json" "$WORK_DIR/unknown-enum.binpb" >"$WORK_DIR/unknown-enum.out" 2>&1 \
  && node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$ROOT_DIR/contracts/golden/event-envelope.unknown-enum.json" >>"$WORK_DIR/unknown-enum.out" 2>&1; then
  fail "golden-unknown-enum" "CONTRACT_UNKNOWN_ENUM: decoder accepted an unregistered domain"
fi
pass "golden-unknown-enum" "CONTRACT_UNKNOWN_ENUM: buf decoder rejected the vector"

if decode "$ROOT_DIR/contracts/golden/event-envelope.unknown-field.json" "$WORK_DIR/unknown-field.binpb" >"$WORK_DIR/unknown-field.out" 2>&1 \
  && node "$ROOT_DIR/scripts/validate-event-envelope.mjs" "$ROOT_DIR/contracts/golden/event-envelope.unknown-field.json" >>"$WORK_DIR/unknown-field.out" 2>&1; then
  fail "golden-unknown-field" "CONTRACT_UNKNOWN_FIELD: decoder accepted a forbidden field"
fi
pass "golden-unknown-field" "CONTRACT_UNKNOWN_FIELD: buf decoder rejected the vector"

REGISTRY="$ROOT_DIR/contracts/services.yaml"
node - "$REGISTRY" >"$WORK_DIR/services.tsv" <<'NODE' || fail "service-registry" "service registry validation failed"
const fs = require("fs");
const registry = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (registry.schema_version !== 1 || !registry.services || typeof registry.services !== "object") throw new Error("invalid registry schema");
const paths = new Set();
const facts = new Map();
for (const [name, service] of Object.entries(registry.services)) {
  if (!name || typeof service.path !== "string" || !service.path) throw new Error(`invalid service ${name}`);
  if (paths.has(service.path)) throw new Error(`duplicate service path ${service.path}`);
  paths.add(service.path);
  if (typeof service.may_write_business_facts !== "boolean" || !Array.isArray(service.owns_facts)) throw new Error(`invalid ownership fields for ${name}`);
  const isCore = service.kind === "core-fact-service";
  if (isCore !== service.may_write_business_facts) throw new Error(`fact writer mismatch for ${name}`);
  if (isCore !== (service.owns_facts.length > 0)) throw new Error(`fact ownership mismatch for ${name}`);
  for (const fact of service.owns_facts) {
    if (facts.has(fact)) throw new Error(`${fact} is owned by both ${facts.get(fact)} and ${name}`);
    facts.set(fact, name);
  }
  process.stdout.write(`${name}\t${service.path}\t${service.kind}\t${service.may_write_business_facts}\n`);
}
if (Object.keys(registry.services).length !== 11) throw new Error("Story 1.3 requires exactly 11 registered modules");
NODE
pass "service-registry" "registry has 11 unique modules and single-owner business facts"

find "$ROOT_DIR/api" "$ROOT_DIR/services" "$ROOT_DIR/workers" -name go.mod -type f -print \
  | while IFS= read -r module_file; do
      relative="${module_file#"$ROOT_DIR/"}"
      printf '%s\n' "${relative%/go.mod}"
    done | sort >"$WORK_DIR/discovered-modules.txt"
cut -f2 "$WORK_DIR/services.tsv" | sort >"$WORK_DIR/registered-modules.txt"
if ! cmp -s "$WORK_DIR/discovered-modules.txt" "$WORK_DIR/registered-modules.txt"; then
  diff -u "$WORK_DIR/registered-modules.txt" "$WORK_DIR/discovered-modules.txt" >&2 || true
  fail "registry-completeness" "registered modules differ from go.mod discovery"
fi
pass "registry-completeness" "every discovered independent module is registered exactly once"

while IFS=$'\t' read -r service_name service_path service_kind may_write; do
  [[ -f "$ROOT_DIR/$service_path/go.mod" ]] || fail "module-$service_name" "missing go.mod"
  [[ -f "$ROOT_DIR/$service_path/cmd/server/main.go" ]] || fail "module-$service_name" "missing cmd/server/main.go"
  output_name="${service_path//\//-}"
  (cd "$ROOT_DIR/$service_path" && GOWORK=off go test ./... && GOWORK=off go build ./... && GOWORK=off go build -o "$WORK_DIR/$output_name" ./cmd/server) || fail "build-$service_name" "GOWORK=off go test/build ./... failed"
  "$WORK_DIR/$output_name" contract >"$WORK_DIR/$service_name.json" || fail "contract-$service_name" "contract command failed"
  node - "$WORK_DIR/$service_name.json" "$service_name" "$service_kind" "$may_write" <<'NODE' || fail "identity-$service_name" "binary identity does not match registry"
const fs = require("fs");
const [file, name, kind, mayWrite] = process.argv.slice(2);
const value = JSON.parse(fs.readFileSync(file, "utf8"));
if (value.service_name !== name || value.service_kind !== kind || value.fact_owner !== (mayWrite === "true") || value.status !== "contract-boundary-ok") process.exit(1);
NODE
  health_dir="$WORK_DIR/health-$service_name"
  mkdir -p "$health_dir"
  APP_LOG_DIR="$health_dir/app" ERROR_LOG_DIR="$health_dir/error" LOG_RETENTION_DAYS=30 \
    "$WORK_DIR/$output_name" health >"$health_dir/ready.json" || fail "health-$service_name" "health command without external dependencies should be ready"
  node - "$health_dir/ready.json" "$health_dir/app" <<'NODE' || fail "health-$service_name" "ready health output or app log is invalid"
const fs = require("fs");
const path = require("path");
const [healthFile, appDir] = process.argv.slice(2);
const health = JSON.parse(fs.readFileSync(healthFile, "utf8"));
if (health.status !== "ready" || !health.trace?.trace_id || !health.trace?.span_id || !health.trace?.request_id) throw new Error("missing ready trace health");
const today = new Date().toISOString().slice(0, 10);
const logPath = path.join(appDir, `app-${today}.log`);
if (!fs.existsSync(logPath)) throw new Error("missing dated app log");
const entry = JSON.parse(fs.readFileSync(logPath, "utf8").trim().split(/\n/).at(-1));
if (entry.level !== "info" || entry.service !== health.service_name || !entry.trace_id) throw new Error("invalid app log entry");
NODE
  node - "$health_dir/app" <<'NODE'
const fs = require("fs");
const path = require("path");
const dir = process.argv[2];
fs.mkdirSync(dir, {recursive: true});
for (const [name, days] of [["expired.log", 31], ["retained.log", 29]]) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, "retention-probe\n");
  const stamp = new Date(Date.now() - days * 86400_000);
  fs.utimesSync(file, stamp, stamp);
}
NODE
  APP_LOG_DIR="$health_dir/app" ERROR_LOG_DIR="$health_dir/error" LOG_RETENTION_DAYS=30 \
    "$WORK_DIR/$output_name" health >/dev/null || fail "retention-$service_name" "health could not execute retention policy"
  [[ ! -e "$health_dir/app/expired.log" && -e "$health_dir/app/retained.log" ]] \
    || fail "retention-$service_name" "30-day retention boundary was not enforced"
  set +e
  APP_LOG_DIR=/dev/null ERROR_LOG_DIR=/dev/null LOG_RETENTION_DAYS=30 \
    "$WORK_DIR/$output_name" health >/dev/null 2>"$health_dir/log-failure.stderr"
  log_failure_rc=$?
  set -e
  [[ $log_failure_rc -ne 0 ]] || fail "log-failure-$service_name" "structured log write failure was ignored"
  set +e
  APP_LOG_DIR="$health_dir/app" ERROR_LOG_DIR="$health_dir/error" LOG_RETENTION_DAYS=30 REQUIRED_DEPENDENCY_ENDPOINTS="missing=127.0.0.1:1" \
    "$WORK_DIR/$output_name" health >"$health_dir/not-ready.json" 2>"$health_dir/not-ready.stderr"
  not_ready_rc=$?
  set -e
  [[ $not_ready_rc -ne 0 ]] || fail "health-$service_name" "unreachable dependency did not fail readiness"
  node - "$health_dir/not-ready.json" "$health_dir/error" <<'NODE' || fail "health-$service_name" "not-ready health output or error log is invalid"
const fs = require("fs");
const path = require("path");
const [healthFile, errorDir] = process.argv.slice(2);
const health = JSON.parse(fs.readFileSync(healthFile, "utf8"));
if (health.status !== "not_ready" || health.dependencies?.[0]?.status !== "not_ready") throw new Error("missing not_ready dependency status");
const today = new Date().toISOString().slice(0, 10);
const logPath = path.join(errorDir, `error-${today}.log`);
if (!fs.existsSync(logPath)) throw new Error("missing dated error log");
const entry = JSON.parse(fs.readFileSync(logPath, "utf8").trim().split(/\n/).at(-1));
if (entry.level !== "error" || entry.service !== health.service_name || !entry.trace_id) throw new Error("invalid error log entry");
NODE
  pass "build-$service_name" "all packages build independently and runtime identity matches registry"
  pass "health-$service_name" "health readiness, trace fields, app log and error log fail-closed checks passed"
  pass "retention-$service_name" "30-day retention boundary and log-write failure are executable"
done <"$WORK_DIR/services.tsv"

DOCKERFILE="$ROOT_DIR/deploy/images/go-service.Dockerfile"
[[ -f "$DOCKERFILE" ]] || fail "image-entry" "shared Go service Dockerfile missing"
grep -q 'ARG SERVICE_PATH' "$DOCKERFILE" || fail "image-entry" "Dockerfile does not expose SERVICE_PATH"
grep -q 'GOWORK=off go build ./\.\.\.' "$DOCKERFILE" || fail "image-entry" "Dockerfile does not compile all module packages"
pass "image-entry" "shared image entry builds every registered independent module"

node "$ROOT_DIR/scripts/check-service-boundaries.mjs" || fail "service-boundaries" "cross-service private import or shared SQL table detected"
pass "service-boundaries" "cross-service private imports and shared business tables are absent"

set +e
rg -n 'gitlab\.allinfinance\.com/aifgo/ag-core' "$ROOT_DIR/api" "$ROOT_DIR/services" "$ROOT_DIR/workers" "$ROOT_DIR/contracts" >"$WORK_DIR/legacy-imports.txt"
rg_status=$?
set -e
if [[ $rg_status -eq 0 ]]; then
  cat "$WORK_DIR/legacy-imports.txt" >&2
  fail "canonical-agcore" "legacy GitLab ag-core path detected"
elif [[ $rg_status -gt 1 ]]; then
  fail "canonical-agcore" "rg failed while scanning canonical imports"
fi
pass "canonical-agcore" "legacy GitLab ag-core path absent"

pass "CONTRACT-001" "Story 1.3 executable contract boundary checks passed"
