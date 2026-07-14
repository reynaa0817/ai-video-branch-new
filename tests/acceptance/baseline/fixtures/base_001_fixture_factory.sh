#!/usr/bin/env bash
# Deterministic local fixture factory for BASE-001.
set -eu

if [ "$#" -ne 2 ]; then
  printf 'usage: %s CASE_DIR VARIANT\n' "$0" >&2
  exit 64
fi

CASE_DIR=$1
VARIANT=$2
SOURCE_SNAPSHOT_SHA=7bc2f4561a9284728cb92b15b9ae9ee760abfa5c
TOOL_SOURCE_SHA=1111111111111111111111111111111111111111
ROOT_DEP_SHA=2222222222222222222222222222222222222222
TOOL_SOURCE_REF=refs/tags/ag-core-tools-v0.1.0
ROOT_DEP_VERSION=v0.1.0
TOOLS='aggo gendb protoc-gen-go-agapi protoc-gen-go-aghertz protoc-gen-go-agkitex protoc-gen-go-agserver protoc-gen-go-agservice'

mkdir -p \
  "$CASE_DIR/remote.git" \
  "$CASE_DIR/build/bin" \
  "$CASE_DIR/metadata" \
  "$CASE_DIR/cache/gomod" \
  "$CASE_DIR/cache/go-build" \
  "$CASE_DIR/evidence/metadata" \
  "$CASE_DIR/evidence/environment"

cat >"$CASE_DIR/baseline-manifest.yaml" <<YAML
schema_version: 1
baseline_id: BASE-001
source_snapshot_sha: $SOURCE_SNAPSHOT_SHA
canonical_remote: https://github.com/aif-go/ag-core.git
tool_source_ref: $TOOL_SOURCE_REF
tool_source_sha: $TOOL_SOURCE_SHA
root_dep_version: $ROOT_DEP_VERSION
root_dep_sha: $ROOT_DEP_SHA
go_version: go1.25.1
image_digest: sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
gotoolchain: local
goproxy: https://proxy.golang.org,direct
gosumdb: sum.golang.org
network_policy: canonical-remote-and-go-proxy-only
gomodcache_policy: isolated
gocache_policy: isolated
manifest_signed: true
manifest_approved_by: platform-release-owner
dual_sha_difference_approved: true
release_approved: true
ref_protection_required: true
evidence_path: reports/baseline/BASE-001/
YAML

cat >"$CASE_DIR/remote-resolution.tsv" <<TSV
tool_source_ref	$TOOL_SOURCE_REF	$TOOL_SOURCE_SHA
root_dep_version	$ROOT_DEP_VERSION	$ROOT_DEP_SHA
TSV

cat >"$CASE_DIR/ref-protection.tsv" <<TSV
tool_source_ref	$TOOL_SOURCE_REF	protected=true	force_move=false
root_dep_version	$ROOT_DEP_VERSION	protected=true	force_move=false
TSV

: >"$CASE_DIR/build-results.tsv"
for tool in $TOOLS; do
  source_command=$tool
  if [ "$tool" = "gendb" ]; then
    source_command=gen-go-db
  fi

  printf '%s\tpresent\t%s\n' "$tool" "$CASE_DIR/build/bin/$tool" >>"$CASE_DIR/build-results.tsv"
  printf '#!/usr/bin/env sh\nexit 0\n' >"$CASE_DIR/build/bin/$tool"
  chmod +x "$CASE_DIR/build/bin/$tool"
  cat >"$CASE_DIR/metadata/$tool.txt" <<META
$CASE_DIR/build/bin/$tool: go1.25.1
	path	github.com/aif-go/ag-core/tool/cmd/$source_command
	mod	github.com/aif-go/ag-core/tool/cmd/$source_command	(devel)
	dep	github.com/aif-go/ag-core	$ROOT_DEP_VERSION
	build	vcs=git
	build	vcs.revision=$TOOL_SOURCE_SHA
	build	vcs.modified=false
META
  cp "$CASE_DIR/metadata/$tool.txt" "$CASE_DIR/evidence/metadata/$tool.txt"
done

cat >"$CASE_DIR/evidence/environment/build-contract.env" <<ENV
GO_VERSION=go1.25.1
IMAGE_DIGEST=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
GOTOOLCHAIN=local
GOPROXY=https://proxy.golang.org,direct
GOSUMDB=sum.golang.org
GOWORK=off
GOMODCACHE=isolated
GOCACHE=isolated
ENV
printf '%s\n' 'module downloads and checksums captured' >"$CASE_DIR/evidence/module-downloads.log"
printf '%s\n' 'seven tools built from isolated fixture checkout' >"$CASE_DIR/evidence/build.log"
printf '%s\n' 'signed=true approved_by=platform-release-owner' >"$CASE_DIR/evidence/manifest-signature.txt"
printf '%s\n' 'protected=true force_move=false owner=platform-release-owner' >"$CASE_DIR/evidence/ref-protection.txt"
printf '%s\n' 'rollback uses the previous verified immutable ref; never move a failed ref' >"$CASE_DIR/evidence/rollback.md"
printf '%s\n' 'G0-1 -> reports/baseline/BASE-001/' >"$CASE_DIR/evidence/traceability.md"
printf '%s\n' 'owner=platform-release-owner verified_at=2026-07-14T00:00:00Z' >"$CASE_DIR/evidence/owner-and-time.txt"
printf '%s\n' 'negative fixture evidence is generated per isolated case' >"$CASE_DIR/evidence/negative-results.log"

replace_manifest_value() {
  key=$1
  value=$2
  input="$CASE_DIR/baseline-manifest.yaml"
  output="$CASE_DIR/baseline-manifest.yaml.next"
  awk -v target="$key:" -v replacement="$key: $value" '
    $1 == target { print replacement; next }
    { print }
  ' "$input" >"$output"
  mv "$output" "$input"
}

case "$VARIANT" in
  valid)
    ;;
  missing_ref)
    awk '$1 != "tool_source_ref"' "$CASE_DIR/remote-resolution.tsv" >"$CASE_DIR/remote-resolution.tsv.next"
    mv "$CASE_DIR/remote-resolution.tsv.next" "$CASE_DIR/remote-resolution.tsv"
    ;;
  sha_mismatch)
    cat >"$CASE_DIR/remote-resolution.tsv" <<TSV
tool_source_ref	$TOOL_SOURCE_REF	3333333333333333333333333333333333333333
root_dep_version	$ROOT_DEP_VERSION	$ROOT_DEP_SHA
TSV
    ;;
  legacy_gitlab)
    printf '\tdep\tgitlab.allinfinance.com/aifgo/ag-core\tv0.0.1-alpha.2\n' \
      >>"$CASE_DIR/metadata/protoc-gen-go-agapi.txt"
    ;;
  local_masking)
    printf '\treplace\tgithub.com/aif-go/ag-core\t%s/local/ag-core\n' "$CASE_DIR" \
      >>"$CASE_DIR/metadata/protoc-gen-go-aghertz.txt"
    printf 'go 1.25.0\nuse ./local/ag-core\n' >"$CASE_DIR/go.work"
    ;;
  missing_gendb)
    rm -f "$CASE_DIR/build/bin/gendb"
    awk '$1 != "gendb"' "$CASE_DIR/build-results.tsv" >"$CASE_DIR/build-results.tsv.next"
    mv "$CASE_DIR/build-results.tsv.next" "$CASE_DIR/build-results.tsv"
    printf 'gen-go-db\tpresent\t%s\n' "$CASE_DIR/build/bin/gen-go-db" >>"$CASE_DIR/build-results.tsv"
    ;;
  provenance_mismatch)
    replace_manifest_value root_dep_sha 4444444444444444444444444444444444444444
    replace_manifest_value dual_sha_difference_approved false
    ;;
  invalid_vcs)
    awk '
      index($0, "build\tvcs.revision=") == 0 &&
      index($0, "build\tvcs.modified=") == 0 { print }
      index($0, "build\tvcs.modified=") > 0 { print "\tbuild\tvcs.modified=true" }
    ' "$CASE_DIR/metadata/protoc-gen-go-agkitex.txt" >"$CASE_DIR/metadata/protoc-gen-go-agkitex.txt.next"
    mv "$CASE_DIR/metadata/protoc-gen-go-agkitex.txt.next" "$CASE_DIR/metadata/protoc-gen-go-agkitex.txt"
    ;;
  unfrozen_environment)
    replace_manifest_value image_digest ''
    rm -f "$CASE_DIR/evidence/environment/build-contract.env"
    ;;
  unprotected_release)
    replace_manifest_value release_approved false
    replace_manifest_value manifest_signed false
    cat >"$CASE_DIR/ref-protection.tsv" <<TSV
tool_source_ref	$TOOL_SOURCE_REF	protected=false	force_move=true
root_dep_version	$ROOT_DEP_VERSION	protected=false	force_move=true
TSV
    ;;
  *)
    printf 'unknown BASE-001 fixture variant: %s\n' "$VARIANT" >&2
    exit 65
    ;;
esac
