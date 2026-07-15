#!/usr/bin/env bash
# 功能：调用真实 Studio guarded command，并验证依赖故障时应用拒绝且事实状态未推进。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:?usage: verify-fail-closed.sh <output-json>}"
ENV_FILE="${AI_VIDEO_ENV_FILE:?AI_VIDEO_ENV_FILE is required}"
PROJECT="${AI_VIDEO_COMPOSE_PROJECT:?AI_VIDEO_COMPOSE_PROJECT is required}"
COMPOSE_FILE="${AI_VIDEO_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-fail-closed.XXXXXX")"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

cleanup() {
  "${COMPOSE[@]}" up -d --wait --wait-timeout 180 >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

EVIDENCE_JSON="$WORK_DIR/evidence.json"
printf '{\n' >"$EVIDENCE_JSON"
first=true

for spec in \
  'budget|budget' \
  'object_storage|minio' \
  'quality|quality' \
  'temporal|temporal'
do
  dependency="${spec%%|*}"
  service="${spec#*|}"
  control_id="guard_control_${dependency}_$$"
  fault_id="guard_fault_${dependency}_$$"

  "${COMPOSE[@]}" exec -T \
    -e PROBE_COMMAND_ID="$control_id" \
    -e PROBE_DEPENDENCY="$dependency" \
    studio /app/server advance-platform-state >/dev/null
  control_json="$("${COMPOSE[@]}" exec -T -e PROBE_COMMAND_ID="$control_id" studio /app/server inspect-platform-state)"

  "${COMPOSE[@]}" stop "$service" >/dev/null
  set +e
  "${COMPOSE[@]}" exec -T \
    -e PROBE_COMMAND_ID="$fault_id" \
    -e PROBE_DEPENDENCY="$dependency" \
    studio /app/server advance-platform-state >/dev/null 2>&1
  command_rc=$?
  set -e
  fault_json="$("${COMPOSE[@]}" exec -T -e PROBE_COMMAND_ID="$fault_id" studio /app/server inspect-platform-state)"
  "${COMPOSE[@]}" up -d --wait --wait-timeout 180 "$service" >/dev/null

  item_json="$(node - "$dependency" "$service" "$command_rc" "$control_json" "$fault_json" <<'NODE'
const [dependency, service, rcRaw, controlRaw, faultRaw] = process.argv.slice(2);
const control = JSON.parse(controlRaw);
const fault = JSON.parse(faultRaw);
const rc = Number(rcRaw);
if (control.found !== true || control.state_advanced !== true) throw new Error(`${dependency} healthy control did not advance`);
if (rc === 0) throw new Error(`${dependency} fault command was accepted`);
if (fault.found !== false || fault.state_advanced !== false) throw new Error(`${dependency} fault advanced state`);
process.stdout.write(JSON.stringify({service, healthy_control_advanced: true, injected: true, command_rejected: true, state_advanced: false}));
NODE
)"
  if [[ "$first" == true ]]; then first=false; else printf ',\n' >>"$EVIDENCE_JSON"; fi
  printf '  "%s": %s' "$dependency" "$item_json" >>"$EVIDENCE_JSON"
done

printf '\n}\n' >>"$EVIDENCE_JSON"
mkdir -p "$(dirname "$OUTPUT")"
cp "$EVIDENCE_JSON" "$OUTPUT"
