#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
mkdir -p "$EVIDENCE"
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd -P)
RUN="base002-object-$$"
NETWORK="$RUN-net"
CERTS=''
MINIO_IMAGE='minio/minio@sha256:a1ea29fa28355559ef137d71fc570e508a214ec84ff8083e39bc5428980b015e'
MC_IMAGE='minio/mc@sha256:aead63c77f9db9107f1696fb08ecb0faeda23729cde94b0f663edf4fe09728e3'
NODES="$RUN-minio-1 $RUN-minio-2 $RUN-minio-3 $RUN-minio-4"
ENDPOINTS="https://$RUN-minio-1/data https://$RUN-minio-2/data https://$RUN-minio-3/data https://$RUN-minio-4/data"
KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY'

cleanup() {
  docker rm -f $NODES >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  [ -z "$CERTS" ] || rm -rf "$CERTS"
}
trap cleanup EXIT HUP INT TERM
cleanup
CERTS=$(mktemp -d "$ROOT/.$RUN-certs.XXXXXX")
CERTS=$(CDPATH= cd -- "$CERTS" && pwd -P)
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -subj '/CN=base002-minio' \
  -addext "subjectAltName=DNS:$RUN-minio-1,DNS:$RUN-minio-2,DNS:$RUN-minio-3,DNS:$RUN-minio-4,IP:127.0.0.1" \
  -keyout "$CERTS/private.key" -out "$CERTS/public.crt" >/dev/null 2>&1
chmod 755 "$CERTS"
chmod 644 "$CERTS/private.key" "$CERTS/public.crt"
docker network create "$NETWORK" >/dev/null

for node in $NODES; do
  docker run -d --name "$node" --network "$NETWORK" \
    -e MINIO_ROOT_USER=base002admin -e MINIO_ROOT_PASSWORD=base002-password \
    -v "$CERTS:/certs:ro" \
    "$MINIO_IMAGE" server $ENDPOINTS --console-address :9001 --certs-dir /certs >/dev/null
done

attempt=0
until docker exec "$RUN-minio-1" curl -kfsS https://127.0.0.1:9000/minio/health/ready >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 180 ] || { printf 'distributed MinIO readiness timeout\n' >&2; exit 1; }
  sleep 1
done
attempt=0
until docker run --rm --network "$NETWORK" "$MC_IMAGE" --insecure alias set int \
  "https://$RUN-minio-1:9000" base002admin base002-password >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 180 ] || { printf 'distributed MinIO initialization timeout\n' >&2; exit 1; }
  sleep 1
done

docker run --rm --network "$NETWORK" \
  -v "$EVIDENCE:/evidence" --entrypoint /bin/sh "$MC_IMAGE" -c '
  set -eu
  alias_name=int
  bucket=ai-video-int
  key="$1"
  host="$2"
  export MC_INSECURE=1
  mc alias set "$alias_name" "https://$host:9000" base002admin base002-password >/dev/null
  mc mb --with-versioning "$alias_name/$bucket" >/dev/null

  printf "durable-object-v1" >/tmp/object-v1.txt
  printf "durable-object-v2" >/tmp/object-v2.txt
  mc cp --checksum SHA256 --enc-c "$alias_name/$bucket/secure/object.txt=$key" \
    /tmp/object-v1.txt "$alias_name/$bucket/secure/object.txt" >/dev/null
  mc cp --checksum SHA256 --enc-c "$alias_name/$bucket/secure/object.txt=$key" \
    /tmp/object-v2.txt "$alias_name/$bucket/secure/object.txt" >/dev/null
  mc stat --json --enc-c "$alias_name/$bucket/secure/object.txt=$key" \
    "$alias_name/$bucket/secure/object.txt" >/evidence/object-storage-stat.json
  mc ls --versions "$alias_name/$bucket/secure/object.txt" >/evidence/object-storage-versions.txt
  test "$(wc -l </evidence/object-storage-versions.txt | tr -d " ")" -ge 2

  mc ilm rule add --prefix secure/ --expire-days 30 --noncurrent-expire-days 7 \
    "$alias_name/$bucket" >/dev/null
  mc ilm rule export "$alias_name/$bucket" >/evidence/object-storage-lifecycle.json
  test -s /evidence/object-storage-lifecycle.json

  printf "short-access" >/tmp/share.txt
  mc cp --checksum SHA256 /tmp/share.txt "$alias_name/$bucket/share/object.txt" >/dev/null
  mc share download --expire 5m "$alias_name/$bucket/share/object.txt" >/evidence/object-storage-share.txt
  share_url=""
  while IFS=" " read -r label value rest; do
    if test "$label" = "Share:"; then share_url=$value; fi
  done </evidence/object-storage-share.txt
  test -n "$share_url"
  printf "%s\n" "$share_url" >/evidence/object-storage-share-url.txt

  mc rm "$alias_name/$bucket/secure/object.txt" >/dev/null
  if mc stat --enc-c "$alias_name/$bucket/secure/object.txt=$key" "$alias_name/$bucket/secure/object.txt" >/dev/null 2>&1; then
    exit 1
  fi
  mc undo "$alias_name/$bucket/secure/object.txt" >/dev/null
  mc cp --enc-c "$alias_name/$bucket/secure/object.txt=$key" \
    "$alias_name/$bucket/secure/object.txt" /tmp/restored.txt >/dev/null
  set -- $(sha256sum /tmp/object-v2.txt); expected_restore=$1
  set -- $(sha256sum /tmp/restored.txt); test "$1" = "$expected_restore"
  printf "delete-marker-hidden=PASS\nundo-restored-current-version=PASS\n" \
    >/evidence/object-storage-delete-restore.txt

  printf "delete-proof" >/tmp/delete.txt
  mc cp /tmp/delete.txt "$alias_name/$bucket/delete/object.txt" >/dev/null
  mc rm --versions --force "$alias_name/$bucket/delete/object.txt" >/dev/null
  mc ls --versions "$alias_name/$bucket/delete/object.txt" >/tmp/deleted-versions.txt
  if test -s /tmp/deleted-versions.txt; then
    exit 1
  fi
  printf "all-delete-object-versions-absent=PASS\n" >/evidence/object-storage-deletion-proof.txt
  set -- $(sha256sum /tmp/object-v2.txt)
  printf "%s\n" "$1" >/evidence/object-storage-expected.sha256
' sh "$KEY" "$RUN-minio-1"

docker run --rm --network "$NETWORK" -v "$EVIDENCE:/evidence" \
  --entrypoint /bin/sh "$MINIO_IMAGE" -c '
  set -eu
  url=$(cat /evidence/object-storage-share-url.txt)
  test -n "$url"
  test "$(curl -kfsS "$url")" = short-access
'

docker stop "$RUN-minio-1" >/dev/null
docker logs "$RUN-minio-1" >"$EVIDENCE/object-storage-failed-node.log" 2>&1

docker run --rm --network "$NETWORK" \
  -v "$EVIDENCE:/evidence" --entrypoint /bin/sh "$MC_IMAGE" -c '
  set -eu
  key="$1"
  host="$2"
  export MC_INSECURE=1
  mc alias set surviving "https://$host:9000" base002admin base002-password >/dev/null
  mc cp --enc-c "surviving/ai-video-int/secure/object.txt=$key" \
    surviving/ai-video-int/secure/object.txt /tmp/surviving.txt >/dev/null
  set -- $(sha256sum /tmp/surviving.txt)
  actual=$1
  expected=$(cat /evidence/object-storage-expected.sha256)
  test "$actual" = "$expected"
  printf "attempt_id\tobject_key\texpected_sha256\trecovered_sha256\tstatus\n" \
    >/evidence/object-reference.tsv
  printf "base002-dr-001\tsecure/object.txt\t%s\t%s\tPASS\n" "$expected" "$actual" \
    >>/evidence/object-reference.tsv
  mc admin info surviving >/evidence/object-storage-cluster-after-failure.txt
' sh "$KEY" "$RUN-minio-2"

for node in $NODES; do
  docker logs "$node" >"$EVIDENCE/object-storage-$node.log" 2>&1 || true
done

{
  printf 'check\tstatus\tevidence\n'
  printf 'encryption\tPASS\tobject-storage-stat.json\n'
  printf 'checksum\tPASS\tobject-storage-expected.sha256\n'
  printf 'versioning\tPASS\tobject-storage-versions.txt\n'
  printf 'lifecycle\tPASS\tobject-storage-lifecycle.json\n'
  printf 'short_term_access\tPASS\tobject-storage-share.txt\n'
  printf 'delete_marker_restore\tPASS\tobject-storage-delete-restore.txt\n'
  printf 'deletion_proof\tPASS\tobject-storage-deletion-proof.txt\n'
  printf 'failure_domain_read\tPASS\tobject-storage-cluster-after-failure.txt\n'
} >"$EVIDENCE/object-storage-smoke.tsv"

printf 'BASE-002 object storage security, lifecycle, deletion and failure-domain PASS\n'
