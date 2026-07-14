#!/usr/bin/env bash
# 功能：验证 Story 1.3 的服务边界、Proto 契约和独立 Go Module 构建。
# 参数：无
# 返回值：0-验证通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/contracts/CONTRACT-001"
REPORT_FILE="$REPORT_DIR/result.tsv"

mkdir -p "$REPORT_DIR"
printf "check\tstatus\tdetail\n" > "$REPORT_FILE"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-contract-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

fail() {
  printf "%s\tFAIL\t%s\n" "$1" "$2" | tee -a "$REPORT_FILE" >&2
  exit 1
}

pass() {
  printf "%s\tPASS\t%s\n" "$1" "$2" | tee -a "$REPORT_FILE"
}

PROTO_FILE="$ROOT_DIR/contracts/proto/ai/video/platform/v1/envelope.proto"

grep -q "DOMAIN_UNSPECIFIED = 0" "$PROTO_FILE" || fail "proto-domain-zero" "Domain enum zero value must be DOMAIN_UNSPECIFIED"
grep -q "EVENT_KIND_UNSPECIFIED = 0" "$PROTO_FILE" || fail "proto-event-zero" "EventKind enum zero value must be EVENT_KIND_UNSPECIFIED"
grep -q "reserved 12 to 20" "$PROTO_FILE" || fail "proto-reserved" "Envelope must reserve future field range"
pass "proto-shape" "Envelope enum zero values and reserved fields are present"

node -e '
const fs = require("fs");
const path = process.argv[1];
const data = JSON.parse(fs.readFileSync(path, "utf8"));
const required = ["event_id","workspace_id","aggregate_id","aggregate_version","owner_domain","event_kind","schema_version","occurred_at","producer","trace","payload"];
for (const key of required) {
  if (!(key in data)) throw new Error(`missing ${key}`);
}
if (data.owner_domain === "DOMAIN_UNSPECIFIED") throw new Error("owner domain is unspecified");
' "$ROOT_DIR/contracts/golden/event-envelope.valid.json" || fail "golden-valid" "Valid event golden vector failed schema smoke"
pass "golden-valid" "Valid event golden vector has required fields"

node -e '
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (data.owner_domain !== "DOMAIN_NOT_REGISTERED") throw new Error("negative vector was changed");
' "$ROOT_DIR/contracts/golden/event-envelope.unknown-enum.json" || fail "golden-unknown-enum" "Unknown enum negative vector missing"
pass "golden-unknown-enum" "Unknown enum negative vector is preserved"

node -e '
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (!("prompt_text" in data)) throw new Error("negative unknown field missing");
' "$ROOT_DIR/contracts/golden/event-envelope.unknown-field.json" || fail "golden-unknown-field" "Unknown field negative vector missing"
pass "golden-unknown-field" "Unknown field negative vector is preserved"

SERVICE_PATHS=(
  "api/web-bff"
  "services/studio"
  "services/workflow"
  "services/budget"
  "services/asset"
  "services/model-gateway"
  "services/quality"
  "services/delivery"
  "services/experience-projection"
  "workers/provider-worker"
  "workers/media-worker"
)

for service_path in "${SERVICE_PATHS[@]}"; do
  [[ -f "$ROOT_DIR/$service_path/go.mod" ]] || fail "module-$service_path" "missing go.mod"
  [[ -f "$ROOT_DIR/$service_path/cmd/server/main.go" ]] || fail "module-$service_path" "missing cmd/server/main.go"
  output_name="${service_path//\//-}"
  (cd "$ROOT_DIR/$service_path" && GOWORK=off go build -o "$BUILD_DIR/$output_name" ./cmd/server) || fail "build-$service_path" "GOWORK=off go build failed"
  pass "build-$service_path" "independent Go module builds with GOWORK=off"
done

if rg -n 'github.com/frochyzhang/ai-video/(services|api|workers)/[^"]+/(internal|repository|model|dao)' "$ROOT_DIR/api" "$ROOT_DIR/services" "$ROOT_DIR/workers" >/tmp/story13-forbidden-imports.txt; then
  cat /tmp/story13-forbidden-imports.txt >&2
  fail "forbidden-imports" "cross-service internal/repository/model/dao import detected"
fi
pass "forbidden-imports" "no forbidden cross-service internal imports detected"

if rg -n 'gitlab\.allinfinance\.com/aifgo/ag-core' "$ROOT_DIR/api" "$ROOT_DIR/services" "$ROOT_DIR/workers" "$ROOT_DIR/contracts" >/tmp/story13-gitlab-imports.txt; then
  cat /tmp/story13-gitlab-imports.txt >&2
  fail "canonical-agcore" "legacy GitLab ag-core path detected"
fi
pass "canonical-agcore" "legacy GitLab ag-core path absent"

pass "CONTRACT-001" "Story 1.3 contract boundary checks passed"
