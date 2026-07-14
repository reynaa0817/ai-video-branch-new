#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
mkdir -p "$EVIDENCE"
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd -P)
RUN="base002-mysql-pitr-$$"
MYSQL="$RUN-mysql"
MYSQL_CLIENT="$RUN-client"
MYSQL_IMAGE='mysql@sha256:c831a0f11348d402b43d77453e17d770be2eef356615a2823fe0f5a0d6c8b9af'
MYSQL_CLIENT_IMAGE='base002/mysql-binlog-client:8.4.10'
PASSWORD='base002-pitr'
TRANSFER=$(mktemp -d "/tmp/$RUN-transfer.XXXXXX")

cleanup() {
  docker rm -f "$MYSQL" "$MYSQL_CLIENT" >/dev/null 2>&1 || true
  rm -rf "$TRANSFER"
}
trap cleanup EXIT HUP INT TERM
cleanup
mkdir -p "$TRANSFER"

docker run -d --name "$MYSQL" -e MYSQL_ROOT_PASSWORD="$PASSWORD" \
  "$MYSQL_IMAGE" --log-bin=mysql-bin --server-id=1 --binlog-format=ROW >/dev/null

attempt=0
until docker exec "$MYSQL" mysql -uroot -p"$PASSWORD" -e 'SELECT 1' >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 180 ] || { printf 'MySQL readiness timeout\n' >&2; exit 1; }
  sleep 1
done

docker build --pull=false -t "$MYSQL_CLIENT_IMAGE" \
  "$ROOT/tests/acceptance/baseline/fixtures/mysql-binlog-client" \
  >"$EVIDENCE/mysql-pitr-client-install.log" 2>&1
docker image inspect "$MYSQL_CLIENT_IMAGE" --format '{{.Id}}' \
  >"$EVIDENCE/mysql-pitr-client-image-id.txt"
docker run -d --name "$MYSQL_CLIENT" "$MYSQL_CLIENT_IMAGE" -c 'sleep infinity' >/dev/null

docker exec "$MYSQL" mysql -uroot -p"$PASSWORD" -e '
  CREATE DATABASE business_meta;
  CREATE TABLE business_meta.facts (
    id BIGINT PRIMARY KEY,
    payload VARCHAR(64) NOT NULL
  );
  INSERT INTO business_meta.facts VALUES (1, "persisted-before-backup");
' >/dev/null 2>&1
docker exec "$MYSQL" sh -c \
  "mysqldump -uroot -p'$PASSWORD' --single-transaction --set-gtid-purged=OFF --databases business_meta > /tmp/business-meta.sql" \
  2>"$EVIDENCE/mysql-pitr-dump.log"
docker exec "$MYSQL" mysql -uroot -p"$PASSWORD" -e 'FLUSH LOGS' >/dev/null 2>&1

docker exec "$MYSQL" mysql -uroot -p"$PASSWORD" -e \
  'INSERT INTO business_meta.facts VALUES (2, "persisted-after-backup");' >/dev/null 2>&1
set -- $(docker exec "$MYSQL" mysql -N -uroot -p"$PASSWORD" -e 'SHOW BINARY LOG STATUS' 2>/dev/null)
BINLOG_FILE=$1
TARGET_POSITION=$2
printf 'binlog_file\t%s\ntarget_position\t%s\n' "$BINLOG_FILE" "$TARGET_POSITION" \
  >"$EVIDENCE/mysql-pitr-target.tsv"

docker exec "$MYSQL" mysql -uroot -p"$PASSWORD" -e 'DELETE FROM business_meta.facts' >/dev/null 2>&1
test "$(docker exec "$MYSQL" mysql -N -uroot -p"$PASSWORD" -e 'SELECT COUNT(*) FROM business_meta.facts' 2>/dev/null | tr -d '\r')" = 0

START_EPOCH=$(date +%s)
docker exec "$MYSQL" mysql -uroot -p"$PASSWORD" -e 'DROP DATABASE business_meta' >/dev/null 2>&1
docker exec "$MYSQL" sh -c "mysql -uroot -p'$PASSWORD' < /tmp/business-meta.sql" \
  >"$EVIDENCE/mysql-pitr-restore.log" 2>&1
docker cp "$MYSQL:/var/lib/mysql/$BINLOG_FILE" "$TRANSFER/binlog" >/dev/null
docker cp "$TRANSFER/binlog" "$MYSQL_CLIENT:/tmp/binlog" >/dev/null
docker exec "$MYSQL_CLIENT" sh -c \
  "mysqlbinlog --stop-position='$TARGET_POSITION' /tmp/binlog > /tmp/replay.sql" \
  >>"$EVIDENCE/mysql-pitr-restore.log" 2>&1
docker cp "$MYSQL_CLIENT:/tmp/replay.sql" "$TRANSFER/replay.sql" >/dev/null
docker cp "$TRANSFER/replay.sql" "$MYSQL:/tmp/replay.sql" >/dev/null
docker exec "$MYSQL" sh -c "mysql -uroot -p'$PASSWORD' < /tmp/replay.sql" \
  >>"$EVIDENCE/mysql-pitr-restore.log" 2>&1
END_EPOCH=$(date +%s)

FACT_COUNT=$(docker exec "$MYSQL" mysql -N -uroot -p"$PASSWORD" \
  -e 'SELECT COUNT(*) FROM business_meta.facts' 2>/dev/null | tr -d '\r')
PAYLOADS=$(docker exec "$MYSQL" mysql -N -uroot -p"$PASSWORD" \
  -e 'SELECT payload FROM business_meta.facts ORDER BY id' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
test "$FACT_COUNT" = 2
test "$PAYLOADS" = 'persisted-before-backup,persisted-after-backup'
RTO_SECONDS=$((END_EPOCH - START_EPOCH))
RTO_MINUTES=$(( (RTO_SECONDS + 59) / 60 ))

docker logs "$MYSQL" >"$EVIDENCE/mysql-pitr-server.log" 2>&1
{
  printf 'check\tstatus\trpo_minutes\trto_minutes\tevidence\n'
  printf 'mysql_pitr\tPASS\t0\t%s\tmysql-pitr-restore.log\n' "$RTO_MINUTES"
  printf 'fact_count_after_restore\t%s\t-\t-\tmysql-pitr-target.tsv\n' "$FACT_COUNT"
  printf 'rto_seconds\t%s\t-\t-\tmysql-pitr-restore.log\n' "$RTO_SECONDS"
} >"$EVIDENCE/mysql-pitr.tsv"

printf 'BASE-002 MySQL binlog PITR PASS (RPO=0m RTO=%ss)\n' "$RTO_SECONDS"
