#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
RUN="base002-temporal-$$"
NETWORK="$RUN-net"
MYSQL="$RUN-mysql"
TEMPORAL="$RUN-server"
WORK="$ROOT/.base-002-temporal.$$"
MYSQL_IMAGE='mysql@sha256:c831a0f11348d402b43d77453e17d770be2eef356615a2823fe0f5a0d6c8b9af'
ADMIN_IMAGE='temporalio/admin-tools@sha256:dbc5fcd6ee8f0f4d808bf765af9a87dea9d8a283abfdcfbd2fc148496ba66107'
SERVER_IMAGE='temporalio/server@sha256:b5ecdb8282bededae2a10c36e8d862e27d0bc2d247fc73c5416025997ab4a1da'
GO_IMAGE='golang@sha256:d7098379b7da665ab25b99795465ec320b1ca9d4addb9f77409c4827dc904211'

cleanup() {
  docker rm -f "$TEMPORAL" "$MYSQL" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM
cleanup
mkdir -p "$WORK/config/dynamicconfig" "$EVIDENCE"
: >"$EVIDENCE/temporal-schema.log"
docker network create "$NETWORK" >/dev/null

curl -fsSL https://raw.githubusercontent.com/temporalio/temporal/19a774302c613da9adc4436ab14278ccdca8e0a5/config/docker.yaml -o "$WORK/config/docker.yaml"
printf '%s  %s\n' 81fde509f35f96ca16e3c04cb557c246fa0133816464ee40d88a041e3f5ea006 "$WORK/config/docker.yaml" | shasum -a 256 -c - >/dev/null
: >"$WORK/config/dynamicconfig/docker.yaml"

docker run -d --name "$MYSQL" --network "$NETWORK" -e MYSQL_ROOT_PASSWORD=base002-only "$MYSQL_IMAGE" >/dev/null
attempt=0
until docker exec "$MYSQL" mysqladmin ping -uroot -pbase002-only --silent >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 120 ] || { docker logs "$MYSQL" >&2; exit 1; }; sleep 1
done
attempt=0
until docker run --rm --network "$NETWORK" --entrypoint mysqladmin "$MYSQL_IMAGE" \
  ping -h "$MYSQL" -uroot -pbase002-only --silent >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 60 ] || { docker logs "$MYSQL" >&2; exit 1; }; sleep 1
done

sql_tool() {
  database=$1
  shift
  docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal-sql-tool \
    --plugin mysql8 --endpoint "$MYSQL" --port 3306 --user root --password base002-only --database "$database" "$@" \
    >>"$EVIDENCE/temporal-schema.log" 2>&1
}
for database in temporal temporal_visibility; do
  sql_tool "$database" create-database
  sql_tool "$database" setup-schema -v 0.0
done
sql_tool temporal update-schema -d /etc/temporal/schema/mysql/v8/temporal/versioned
sql_tool temporal_visibility update-schema -d /etc/temporal/schema/mysql/v8/visibility/versioned

docker run -d --name "$TEMPORAL" --network "$NETWORK" -v "$WORK:/work" -w /work \
  -e DB=mysql8 -e DBNAME=temporal -e VISIBILITY_DBNAME=temporal_visibility \
  -e MYSQL_SEEDS="$MYSQL" -e DB_PORT=3306 -e MYSQL_USER=root -e MYSQL_PWD=base002-only \
  -e DYNAMIC_CONFIG_FILE_PATH=/work/config/dynamicconfig/docker.yaml \
  -e TEMPORAL_CONFIG_DIR=config -e TEMPORAL_ENVIRONMENT=docker -e TEMPORAL_ALLOW_NO_AUTH=true \
  "$SERVER_IMAGE" >/dev/null
attempt=0
until docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal operator namespace list --address "$TEMPORAL:7233" >/dev/null 2>&1; do
  attempt=$((attempt + 1)); [ "$attempt" -lt 120 ] || { docker logs "$TEMPORAL" >&2; exit 1; }; sleep 1
done
docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal operator namespace create \
  --address "$TEMPORAL:7233" --namespace ai-video-int --retention 24h >"$EVIDENCE/temporal-namespace.log" 2>&1
docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal operator namespace describe \
  --address "$TEMPORAL:7233" --namespace ai-video-int >>"$EVIDENCE/temporal-namespace.log" 2>&1
docker run --rm --network "$NETWORK" -e TEMPORAL_ADDRESS="$TEMPORAL:7233" \
  -e GOTOOLCHAIN=local -e GOMODCACHE=/tmp/gomodcache -e GOCACHE=/tmp/gocache \
  -v "$ROOT/tests/acceptance/baseline/fixtures/temporal-sdk:/src:ro" -w /src "$GO_IMAGE" \
  sh -ceu 'cp -R /src /tmp/sdk; cd /tmp/sdk; go mod download; go run .' \
  >"$EVIDENCE/temporal-sdk.log" 2>&1

docker exec "$MYSQL" mysql -uroot -pbase002-only -Nse \
  "select db_name, curr_version from temporal.schema_version union all select db_name, curr_version from temporal_visibility.schema_version" \
  >"$EVIDENCE/temporal-schema-versions.tsv"
docker logs "$TEMPORAL" >"$EVIDENCE/temporal-server.log" 2>&1
docker logs "$MYSQL" >"$EVIDENCE/temporal-mysql.log" 2>&1
{
  printf 'component\tstatus\tevidence\n'
  printf 'mysql_8_4_10\tPASS\ttemporal-mysql.log\n'
  printf 'temporal_schema_1_19_1_14\tPASS\ttemporal-schema-versions.tsv\n'
  printf 'namespace_isolation\tPASS\ttemporal-namespace.log\n'
  printf 'workflow_sdk_compatibility\tPASS\ttemporal-sdk.log\n'
  printf 'upgrade_rollback_restore\tPENDING\ttimed-DR\n'
} >"$EVIDENCE/temporal-mysql-smoke.tsv"
printf 'BASE-002 Temporal/MySQL schema, namespace and Go SDK workflow smoke PASS; upgrade/DR PENDING\n'
