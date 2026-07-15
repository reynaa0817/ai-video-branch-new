#!/usr/bin/env bash
# 功能：对已存在或全新的 local MySQL volume 幂等应用 Story 1.3 owner schema 与最小权限账号。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${AI_VIDEO_ENV_FILE:?AI_VIDEO_ENV_FILE is required}"
PROJECT="${AI_VIDEO_COMPOSE_PROJECT:?AI_VIDEO_COMPOSE_PROJECT is required}"
COMPOSE_FILE="${AI_VIDEO_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
STUDIO_SCHEMA="$ROOT_DIR/services/studio/internal/repository/migrations/001-story13-platform.sql"
PROJECTION_SCHEMA="$ROOT_DIR/services/experience-projection/internal/repository/migrations/001-story13-projection.sql"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

[[ -r "$STUDIO_SCHEMA" ]] || { echo "schema file is missing: $STUDIO_SCHEMA" >&2; exit 1; }
[[ -r "$PROJECTION_SCHEMA" ]] || { echo "schema file is missing: $PROJECTION_SCHEMA" >&2; exit 1; }

"${COMPOSE[@]}" exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE"' <"$STUDIO_SCHEMA"
"${COMPOSE[@]}" exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE"' <"$PROJECTION_SCHEMA"

"${COMPOSE[@]}" exec -T mysql sh <<'SH'
set -eu
case "${MYSQL_DATABASE:-}" in
  *[!A-Za-z0-9_]*|'') echo "invalid MYSQL_DATABASE" >&2; exit 1 ;;
esac
for value in "${STUDIO_DB_PASSWORD:-}" "${PROJECTION_DB_PASSWORD:-}"; do
  case "$value" in
    *[!A-Za-z0-9_.:@#%+=-]*|'') echo "invalid app database password" >&2; exit 1 ;;
  esac
done
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE" <<SQL
CREATE USER IF NOT EXISTS 'studio_app'@'%' IDENTIFIED BY '$STUDIO_DB_PASSWORD';
ALTER USER 'studio_app'@'%' IDENTIFIED BY '$STUDIO_DB_PASSWORD';
CREATE USER IF NOT EXISTS 'projection_app'@'%' IDENTIFIED BY '$PROJECTION_DB_PASSWORD';
ALTER USER 'projection_app'@'%' IDENTIFIED BY '$PROJECTION_DB_PASSWORD';
GRANT SELECT, INSERT, UPDATE ON \`${MYSQL_DATABASE}\`.STORY13_FACT TO 'studio_app'@'%';
GRANT SELECT, INSERT, UPDATE ON \`${MYSQL_DATABASE}\`.STORY13_OUTBOX TO 'studio_app'@'%';
GRANT SELECT, INSERT, UPDATE ON \`${MYSQL_DATABASE}\`.STORY13_GUARDED_COMMAND TO 'studio_app'@'%';
GRANT SELECT, INSERT, UPDATE ON \`${MYSQL_DATABASE}\`.STORY13_PROJECTION TO 'projection_app'@'%';
FLUSH PRIVILEGES;
SQL
SH
