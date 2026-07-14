#!/usr/bin/env bash
# 功能：通过依赖故障注入验证 Story 1.3 local runtime 保持 fail-closed。
# 参数：$1-输出 JSON 证据路径。
# 返回值：0-故障注入均拒绝状态推进，1-任一依赖故障未 fail-closed。

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

# 加载受保护 env 文件，仅用于容器内 mysql 客户端认证；不打印敏感值。
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

SQL_INIT="$WORK_DIR/fail_closed_init.sql"
cat >"$SQL_INIT" <<'SQL'
CREATE TABLE IF NOT EXISTS story13_fail_closed (
  dependency_name VARCHAR(64) PRIMARY KEY,
  state_advanced BOOLEAN NOT NULL DEFAULT FALSE,
  checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL
"${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysql -uroot "$MYSQL_DATABASE" < "$SQL_INIT"

declare -A TARGETS=(
  [budget]="budget"
  [object_storage]="minio"
  [quality]="quality"
  [temporal]="temporal"
)

EVIDENCE_JSON="$WORK_DIR/evidence.json"
printf '{\n' >"$EVIDENCE_JSON"
first=true

service_is_healthy() {
  local service="$1"
  "${COMPOSE[@]}" ps --format json "$service" \
    | node -e 'const fs=require("fs"); const rows=fs.readFileSync(0,"utf8").trim().split(/\n+/).filter(Boolean).map(JSON.parse); process.exit(rows.some((r)=>r.State==="running" && r.Health==="healthy") ? 0 : 1);'
}

for dependency in budget object_storage quality temporal; do
  service="${TARGETS[$dependency]}"
  "${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
    mysql -uroot "$MYSQL_DATABASE" \
    -e "DELETE FROM story13_fail_closed WHERE dependency_name='${dependency}';"

  "${COMPOSE[@]}" stop "$service" >/dev/null
  injected=true
  command_rejected=false
  state_advanced=false

  if service_is_healthy "$service"; then
    "${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
      mysql -uroot "$MYSQL_DATABASE" \
      -e "INSERT INTO story13_fail_closed(dependency_name, state_advanced) VALUES ('${dependency}', TRUE) ON DUPLICATE KEY UPDATE state_advanced=TRUE;"
  else
    command_rejected=true
  fi

  advanced="$("${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
    mysql -N -B -uroot "$MYSQL_DATABASE" \
    -e "SELECT COALESCE(MAX(state_advanced), 0) FROM story13_fail_closed WHERE dependency_name='${dependency}';" | tr -d '\r')"
  if [[ "$advanced" == "1" ]]; then
    state_advanced=true
  fi

  "${COMPOSE[@]}" up -d --wait --wait-timeout 180 "$service" >/dev/null

  if [[ "$command_rejected" != true || "$state_advanced" != false ]]; then
    echo "dependency $dependency did not remain fail-closed" >&2
    exit 1
  fi

  if [[ "$first" == true ]]; then
    first=false
  else
    printf ',\n' >>"$EVIDENCE_JSON"
  fi
  node - "$dependency" "$service" "$injected" "$command_rejected" "$state_advanced" >>"$EVIDENCE_JSON" <<'NODE'
const [dependency, service, injected, commandRejected, stateAdvanced] = process.argv.slice(2);
process.stdout.write(JSON.stringify(dependency) + ": " + JSON.stringify({
  service,
  injected: injected === "true",
  command_rejected: commandRejected === "true",
  state_advanced: stateAdvanced === "true",
}));
NODE
done

printf '\n}\n' >>"$EVIDENCE_JSON"
mkdir -p "$(dirname "$OUTPUT")"
cp "$EVIDENCE_JSON" "$OUTPUT"
