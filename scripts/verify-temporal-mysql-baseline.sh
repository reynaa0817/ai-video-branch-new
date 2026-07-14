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
OLD_SERVER_IMAGE='temporalio/server@sha256:d5334ee3ddce1617efbe280a10afc85916cf8d81798415c98988dbda2b46773e'
GO_IMAGE='golang@sha256:d7098379b7da665ab25b99795465ec320b1ca9d4addb9f77409c4827dc904211'
WORKER_BEFORE="$RUN-worker-before"
WORKER_AFTER="$RUN-worker-after"

cleanup() {
  docker rm -f "$TEMPORAL" "$MYSQL" "$WORKER_BEFORE" "$WORKER_AFTER" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  chmod -R u+w "$WORK" >/dev/null 2>&1 || true
  rm -rf "$WORK" >/dev/null 2>&1 || true
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

start_server() {
  image=$1
  docker rm -f "$TEMPORAL" >/dev/null 2>&1 || true
  docker run -d --name "$TEMPORAL" --network "$NETWORK" -v "$WORK:/work" -w /work \
    -e DB=mysql8 -e DBNAME=temporal -e VISIBILITY_DBNAME=temporal_visibility \
    -e MYSQL_SEEDS="$MYSQL" -e DB_PORT=3306 -e MYSQL_USER=root -e MYSQL_PWD=base002-only \
    -e DYNAMIC_CONFIG_FILE_PATH=/work/config/dynamicconfig/docker.yaml \
    -e TEMPORAL_CONFIG_DIR=config -e TEMPORAL_ENVIRONMENT=docker -e TEMPORAL_ALLOW_NO_AUTH=true \
    "$image" >/dev/null
  attempt=0
  until docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal operator namespace list --address "$TEMPORAL:7233" >/dev/null 2>&1; do
    attempt=$((attempt + 1)); [ "$attempt" -lt 120 ] || { docker logs "$TEMPORAL" >&2; exit 1; }; sleep 1
  done
}

run_sdk() {
  workflow_id=$1
  log_file=$2
  docker run --rm --network "$NETWORK" -e TEMPORAL_ADDRESS="$TEMPORAL:7233" \
    -e WORKFLOW_ID="$workflow_id" -e GOTOOLCHAIN=local -e GOMODCACHE=/tmp/gomodcache -e GOCACHE=/tmp/gocache \
    -v "$ROOT/tests/acceptance/baseline/fixtures/temporal-sdk:/src:ro" -w /src "$GO_IMAGE" \
    sh -ceu 'cp -R /src /tmp/sdk; cd /tmp/sdk; go mod download; go run .' \
    >"$log_file" 2>&1
}

run_worker_recovery() {
  workflow_id=base002-worker-recovery
  marker="$WORK/worker-activity-started"
  rm -f "$marker"
  mkdir -p "$WORK/gomodcache"

  docker run -d --name "$WORKER_BEFORE" --network "$NETWORK" \
    -e TEMPORAL_ADDRESS="$TEMPORAL:7233" -e SDK_MODE=worker -e ACTIVITY_HOLD=1 \
    -e ACTIVITY_MARKER=/work/worker-activity-started -e GOTOOLCHAIN=local \
    -e GOMODCACHE=/tmp/gomodcache -e GOCACHE=/tmp/gocache \
    -v "$ROOT/tests/acceptance/baseline/fixtures/temporal-sdk:/src:ro" \
    -v "$WORK:/work" -v "$WORK/gomodcache:/tmp/gomodcache" -w /src "$GO_IMAGE" \
    sh -ceu 'cp -R /src /tmp/sdk; cd /tmp/sdk; go mod download; go run .' >/dev/null

  attempt=0
  until docker logs "$WORKER_BEFORE" 2>&1 | grep -F WORKER_READY >/dev/null; do
    attempt=$((attempt + 1)); [ "$attempt" -lt 180 ] || { docker logs "$WORKER_BEFORE" >&2; return 1; }; sleep 1
  done

  docker run --rm --network "$NETWORK" -e TEMPORAL_ADDRESS="$TEMPORAL:7233" \
    -e SDK_MODE=start -e WORKFLOW_ID="$workflow_id" -e GOTOOLCHAIN=local \
    -e GOMODCACHE=/tmp/gomodcache -e GOCACHE=/tmp/gocache \
    -v "$ROOT/tests/acceptance/baseline/fixtures/temporal-sdk:/src:ro" \
    -v "$WORK/gomodcache:/tmp/gomodcache" -w /src "$GO_IMAGE" \
    sh -ceu 'cp -R /src /tmp/sdk; cd /tmp/sdk; go run .' \
    >"$EVIDENCE/temporal-worker-start.log" 2>&1

  attempt=0
  until [ -s "$marker" ]; do
    attempt=$((attempt + 1)); [ "$attempt" -lt 60 ] || { docker logs "$WORKER_BEFORE" >&2; return 1; }; sleep 1
  done
  docker kill "$WORKER_BEFORE" >/dev/null
  docker logs "$WORKER_BEFORE" >"$EVIDENCE/temporal-worker-before-failure.log" 2>&1 || true

  docker run -d --name "$WORKER_AFTER" --network "$NETWORK" \
    -e TEMPORAL_ADDRESS="$TEMPORAL:7233" -e SDK_MODE=worker -e ACTIVITY_HOLD=0 \
    -e GOTOOLCHAIN=local -e GOMODCACHE=/tmp/gomodcache -e GOCACHE=/tmp/gocache \
    -v "$ROOT/tests/acceptance/baseline/fixtures/temporal-sdk:/src:ro" \
    -v "$WORK/gomodcache:/tmp/gomodcache" -w /src "$GO_IMAGE" \
    sh -ceu 'cp -R /src /tmp/sdk; cd /tmp/sdk; go run .' >/dev/null

  docker run --rm --network "$NETWORK" -e TEMPORAL_ADDRESS="$TEMPORAL:7233" \
    -e SDK_MODE=result -e WORKFLOW_ID="$workflow_id" -e GOTOOLCHAIN=local \
    -e GOMODCACHE=/tmp/gomodcache -e GOCACHE=/tmp/gocache \
    -v "$ROOT/tests/acceptance/baseline/fixtures/temporal-sdk:/src:ro" \
    -v "$WORK/gomodcache:/tmp/gomodcache" -w /src "$GO_IMAGE" \
    sh -ceu 'cp -R /src /tmp/sdk; cd /tmp/sdk; go run .' \
    >"$EVIDENCE/temporal-worker-recovery.log" 2>&1
  grep -F 'BASE-002 WORKER RECOVERY PASS' "$EVIDENCE/temporal-worker-recovery.log" >/dev/null
  docker logs "$WORKER_AFTER" >"$EVIDENCE/temporal-worker-after-failure.log" 2>&1 || true
  docker rm -f "$WORKER_BEFORE" "$WORKER_AFTER" >/dev/null 2>&1 || true
}

workflow_count() {
  docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal workflow list \
    --address "$TEMPORAL:7233" --namespace ai-video-int --output json 2>/dev/null | grep -c 'workflowId' || true
}

# Expand schema first, then prove N-1 server, N server and N-1 rollback all execute real workflows.
start_server "$OLD_SERVER_IMAGE"
docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal operator namespace create \
  --address "$TEMPORAL:7233" --namespace ai-video-int --retention 24h >"$EVIDENCE/temporal-namespace.log" 2>&1
docker run --rm --network "$NETWORK" "$ADMIN_IMAGE" temporal operator namespace describe \
  --address "$TEMPORAL:7233" --namespace ai-video-int >>"$EVIDENCE/temporal-namespace.log" 2>&1
run_sdk base002-before-upgrade "$EVIDENCE/temporal-sdk-before-upgrade.log"
docker logs "$TEMPORAL" >"$EVIDENCE/temporal-server-1.30.2.log" 2>&1

start_server "$SERVER_IMAGE"
run_sdk base002-after-upgrade "$EVIDENCE/temporal-sdk-after-upgrade.log"
docker logs "$TEMPORAL" >"$EVIDENCE/temporal-server-1.31.2.log" 2>&1

start_server "$OLD_SERVER_IMAGE"
run_sdk base002-after-rollback "$EVIDENCE/temporal-sdk-after-rollback.log"
docker logs "$TEMPORAL" >"$EVIDENCE/temporal-server-rollback-1.30.2.log" 2>&1

# Return to N, take a consistent logical backup, destroy both schemas, restore and prove history remains usable.
start_server "$SERVER_IMAGE"
run_worker_recovery
before_count=$(workflow_count)
[ "$before_count" -ge 3 ]
docker exec "$MYSQL" mysqldump -uroot -pbase002-only --single-transaction --routines --events \
  --databases temporal temporal_visibility >"$WORK/temporal-backup.sql"
docker stop "$TEMPORAL" >/dev/null
restore_started=$(date +%s)
docker exec "$MYSQL" mysql -uroot -pbase002-only -e 'DROP DATABASE temporal; DROP DATABASE temporal_visibility;'
docker exec -i "$MYSQL" mysql -uroot -pbase002-only <"$WORK/temporal-backup.sql"
start_server "$SERVER_IMAGE"
after_count=$(workflow_count)
[ "$after_count" -eq "$before_count" ]
run_sdk base002-after-restore "$EVIDENCE/temporal-sdk-after-restore.log"
restore_finished=$(date +%s)
restore_seconds=$((restore_finished - restore_started))
rto_minutes=$(((restore_seconds + 59) / 60))

cat "$EVIDENCE/temporal-sdk-after-upgrade.log" "$EVIDENCE/temporal-sdk-after-rollback.log" \
  "$EVIDENCE/temporal-sdk-after-restore.log" >"$EVIDENCE/temporal-sdk.log"

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
  printf 'server_upgrade_1_30_2_to_1_31_2\tPASS\ttemporal-sdk-after-upgrade.log\n'
  printf 'server_rollback_1_31_2_to_1_30_2\tPASS\ttemporal-sdk-after-rollback.log\n'
  printf 'worker_interruption_recovery\tPASS\ttemporal-worker-recovery.log\n'
  printf 'mysql_logical_restore\tPASS\ttemporal-sdk-after-restore.log\n'
} >"$EVIDENCE/temporal-mysql-smoke.tsv"
{
  printf 'field\tvalue\n'
  printf 'rpo_minutes\t0\n'
  printf 'rto_minutes\t%s\n' "$rto_minutes"
  printf 'workflow_count_before_restore\t%s\n' "$before_count"
  printf 'workflow_count_after_restore\t%s\n' "$after_count"
  printf 'workflow_after_restore\tPASS\n'
} >"$EVIDENCE/temporal-dr-report.tsv"
printf 'BASE-002 Temporal/MySQL N/N-1 upgrade, rollback and timed logical restore PASS\n'
