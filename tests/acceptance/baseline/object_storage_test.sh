#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d "$ROOT/.base002-object-storage.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

bash "$ROOT/scripts/verify-object-storage-baseline.sh" "$TMP"

for check in encryption checksum versioning lifecycle short_term_access \
  delete_marker_restore deletion_proof failure_domain_read; do
  awk -F '\t' -v check="$check" '$1 == check && $2 == "PASS" { found=1 } END { exit !found }' \
    "$TMP/object-storage-smoke.tsv"
done

test -s "$TMP/object-storage-versions.txt"
test -s "$TMP/object-storage-lifecycle.json"
test -s "$TMP/object-storage-deletion-proof.txt"
awk -F '\t' 'NR == 2 && $1 == "base002-dr-001" && $2 == "secure/object.txt" && \
  $3 == $4 && $5 == "PASS" { found=1 } END { exit !found }' "$TMP/object-reference.tsv"
printf 'BASE-002 object storage security, lifecycle, deletion and failure-domain PASS\n'
