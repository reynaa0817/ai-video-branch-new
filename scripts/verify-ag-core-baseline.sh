#!/usr/bin/env bash
# BASE-001 authoritative ag-core provenance gate.
set -u

CANONICAL_REMOTE=https://github.com/aif-go/ag-core.git
TOOLS='aggo gendb protoc-gen-go-agapi protoc-gen-go-aghertz protoc-gen-go-agkitex protoc-gen-go-agserver protoc-gen-go-agservice'
CHECK=all
MANIFEST=
EVIDENCE_DIR=
REMOTE_URL=
WORK_ROOT=
CHECKOUT=
GO_BIN=
CLEAN_PATH=

usage() {
  printf 'usage: %s --manifest FILE --evidence-dir DIR [--remote-url URL] [--check refs|build|metadata|evidence|all]\n' "$0" >&2
  exit 64
}

fail() {
  code=$1
  shift
  printf '%s %s\n' "$code" "$*" >&2
  exit 1
}

pass() {
  printf '%s PASS\n' "$1"
}

manifest_value() {
  key=$1
  awk -v target="$key:" '
    $1 == target {
      sub(/^[^:]+:[[:space:]]*/, "")
      gsub(/^['\"']|['\"']$/, "")
      print
      exit
    }
  ' "$MANIFEST"
}

require_manifest_value() {
  key=$1
  value=$(manifest_value "$key")
  [ -n "$value" ] || fail B001-E09 "manifest_field=$key reason=missing_or_empty"
  printf '%s\n' "$value"
}

is_sha() {
  printf '%s\n' "$1" | grep -E '^[0-9a-f]{40}$' >/dev/null 2>&1
}

resolve_remote_ref() {
  label=$1
  ref=$2
  if [ "${BASE001_TEST_MODE:-0}" = 1 ]; then
    awk -F '\t' -v expected="$label" '$1 == expected { print $3; exit }' \
      "$BASE001_FIXTURE_ROOT/remote-resolution.tsv"
    return
  fi

  if is_sha "$ref"; then
    probe=$(mktemp -d "${TMPDIR:-/tmp}/base-001-ref.XXXXXX") || return 1
    git init -q "$probe" || { rm -rf "$probe"; return 1; }
    git -C "$probe" remote add origin "$REMOTE_URL" || { rm -rf "$probe"; return 1; }
    git -C "$probe" fetch -q --depth=1 origin "$ref" || { rm -rf "$probe"; return 1; }
    resolved=$(git -C "$probe" rev-parse FETCH_HEAD) || { rm -rf "$probe"; return 1; }
    rm -rf "$probe"
    printf '%s\n' "$resolved"
    return
  fi

  lookup=$ref
  case "$lookup" in
    refs/*) ;;
    *) lookup="refs/tags/$lookup" ;;
  esac
  resolved=$(git ls-remote --exit-code "$REMOTE_URL" "$lookup" "$lookup^{}" 2>/dev/null) || return 1
  peeled=$(printf '%s\n' "$resolved" | awk '$2 ~ /\^\{\}$/ { print $1; exit }')
  if [ -n "$peeled" ]; then
    printf '%s\n' "$peeled"
  else
    printf '%s\n' "$resolved" | awk 'NR == 1 { print $1 }'
  fi
}

check_manifest_contract() {
  schema_version=$(require_manifest_value schema_version)
  baseline_id=$(require_manifest_value baseline_id)
  canonical_remote=$(require_manifest_value canonical_remote)
  tool_source_ref=$(require_manifest_value tool_source_ref)
  tool_source_sha=$(require_manifest_value tool_source_sha)
  root_dep_version=$(require_manifest_value root_dep_version)
  root_dep_sha=$(require_manifest_value root_dep_sha)

  [ "$schema_version" = 1 ] || fail B001-E09 "schema_version=$schema_version expected=1"
  [ "$baseline_id" = BASE-001 ] || fail B001-E09 "baseline_id=$baseline_id expected=BASE-001"
  [ "$canonical_remote" = "$CANONICAL_REMOTE" ] || \
    fail B001-E01 "canonical_remote=$canonical_remote expected=$CANONICAL_REMOTE"
  is_sha "$tool_source_sha" || fail B001-E02 "tool_source_sha=$tool_source_sha reason=invalid_sha"
  is_sha "$root_dep_sha" || fail B001-E02 "root_dep_sha=$root_dep_sha reason=invalid_sha"
}

check_refs() {
  check_manifest_contract
  tool_source_ref=$(manifest_value tool_source_ref)
  tool_source_sha=$(manifest_value tool_source_sha)
  root_dep_version=$(manifest_value root_dep_version)
  root_dep_sha=$(manifest_value root_dep_sha)

  actual_tool_sha=$(resolve_remote_ref tool_source_ref "$tool_source_ref") || \
    fail B001-E01 "tool_source_ref=$tool_source_ref remote=$REMOTE_URL reason=not_resolvable"
  [ -n "$actual_tool_sha" ] || \
    fail B001-E01 "tool_source_ref=$tool_source_ref remote=$REMOTE_URL reason=not_resolvable"
  [ "$actual_tool_sha" = "$tool_source_sha" ] || \
    fail B001-E02 "tool_source_ref=$tool_source_ref expected_sha=$tool_source_sha actual_sha=$actual_tool_sha"

  actual_root_sha=$(resolve_remote_ref root_dep_version "$root_dep_version") || \
    fail B001-E01 "root_dep_version=$root_dep_version remote=$REMOTE_URL reason=not_resolvable"
  [ -n "$actual_root_sha" ] || \
    fail B001-E01 "root_dep_version=$root_dep_version remote=$REMOTE_URL reason=not_resolvable"
  [ "$actual_root_sha" = "$root_dep_sha" ] || \
    fail B001-E02 "root_dep_version=$root_dep_version expected_sha=$root_dep_sha actual_sha=$actual_root_sha"
}

check_environment_contract() {
  for key in go_version image_digest gotoolchain goproxy gosumdb network_policy gomodcache_policy gocache_policy; do
    value=$(manifest_value "$key")
    [ -n "$value" ] || fail B001-E08 "$key=missing manifest=$MANIFEST"
  done
  [ "$(manifest_value gotoolchain)" = local ] || \
    fail B001-E08 "gotoolchain=$(manifest_value gotoolchain) expected=local"

  if [ "${BASE001_TEST_MODE:-0}" = 1 ]; then
    [ -r "$EVIDENCE_DIR/environment/build-contract.env" ] || \
      fail B001-E08 "image_digest=$(manifest_value image_digest) environment_contract=missing"
  fi
}

prepare_real_checkout() {
  command -v git >/dev/null 2>&1 || fail B001-E08 'git=missing'
  command -v go >/dev/null 2>&1 || fail B001-E08 'go=missing'
  GO_BIN=$(command -v go)
  CLEAN_PATH=$(dirname "$GO_BIN"):/usr/bin:/bin:/usr/sbin:/sbin
  WORK_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/base-001-gate.XXXXXX") || fail B001-E08 'work_root=create_failed'
  trap cleanup_work_root EXIT HUP INT TERM
  CHECKOUT="$WORK_ROOT/ag-core"
  git init -q "$CHECKOUT" || fail B001-E01 "remote=$REMOTE_URL reason=git_init_failed"
  git -C "$CHECKOUT" remote add origin "$REMOTE_URL"
  git -C "$CHECKOUT" fetch -q --depth=1 origin "$(manifest_value tool_source_ref)" || \
    fail B001-E01 "tool_source_ref=$(manifest_value tool_source_ref) reason=fetch_failed"
  git -C "$CHECKOUT" checkout -q --detach FETCH_HEAD || fail B001-E01 'checkout=failed'
  actual=$(git -C "$CHECKOUT" rev-parse HEAD)
  [ "$actual" = "$(manifest_value tool_source_sha)" ] || \
    fail B001-E02 "tool_source_ref=$(manifest_value tool_source_ref) expected_sha=$(manifest_value tool_source_sha) actual_sha=$actual"
  [ -z "$(git -C "$CHECKOUT" status --porcelain)" ] || fail B001-E07 'vcs.modified=true checkout=dirty'
}

cleanup_work_root() {
  if [ -n "${WORK_ROOT:-}" ] && [ -d "$WORK_ROOT" ]; then
    chmod -R u+w "$WORK_ROOT" 2>/dev/null || true
    rm -rf "$WORK_ROOT"
  fi
}

tool_source_dir() {
  case "$1" in
    gendb) printf '%s\n' tool/cmd/gen-go-db ;;
    *) printf 'tool/cmd/%s\n' "$1" ;;
  esac
}

check_fixture_build() {
  [ ! -e "$BASE001_FIXTURE_ROOT/go.work" ] || fail B001-E04 "go.work=$BASE001_FIXTURE_ROOT/go.work reason=local_masking"
  for tool in $TOOLS; do
    result=$(awk -F '\t' -v target="$tool" '$1 == target { print $2; exit }' "$BASE001_FIXTURE_ROOT/build-results.tsv")
    [ "$result" = present ] && [ -x "$BASE001_FIXTURE_ROOT/build/bin/$tool" ] || \
      fail B001-E05 "tool=$tool expected_binary=$BASE001_FIXTURE_ROOT/build/bin/$tool"
  done
}

check_real_build() {
  prepare_real_checkout
  checkout=$CHECKOUT
  mkdir -p "$EVIDENCE_DIR/metadata" "$EVIDENCE_DIR/environment" "$WORK_ROOT/bin" "$WORK_ROOT/gomod" "$WORK_ROOT/gocache"
  go_version=$("$GO_BIN" version | awk '{ print $3 }')
  [ "$go_version" = "$(manifest_value go_version)" ] || \
    fail B001-E08 "go_version=$go_version expected=$(manifest_value go_version)"
  {
    printf 'GO_VERSION=%s\n' "$go_version"
    printf 'IMAGE_DIGEST=%s\n' "$(manifest_value image_digest)"
    printf 'GOTOOLCHAIN=local\nGOPROXY=%s\nGOSUMDB=%s\nGOWORK=off\n' "$(manifest_value goproxy)" "$(manifest_value gosumdb)"
    printf 'GOMODCACHE=%s\nGOCACHE=%s\n' "$WORK_ROOT/gomod" "$WORK_ROOT/gocache"
  } >"$EVIDENCE_DIR/environment/build-contract.env"
  : >"$EVIDENCE_DIR/build.log"
  : >"$EVIDENCE_DIR/module-downloads.log"

  for tool in $TOOLS; do
    source_dir=$(tool_source_dir "$tool")
    module_dir="$checkout/$source_dir"
    [ -r "$module_dir/go.mod" ] || fail B001-E05 "tool=$tool module=$source_dir reason=go_mod_missing"
    printf 'tool=%s module=%s action=build_start\n' "$tool" "$source_dir" >>"$EVIDENCE_DIR/build.log"
    (
      cd "$module_dir" || exit 1
      env -i HOME="${HOME:-/tmp}" PATH="$CLEAN_PATH" GOFLAGS=-modcacherw GOTOOLCHAIN=local GOWORK=off \
        GOPROXY="$(manifest_value goproxy)" GOSUMDB="$(manifest_value gosumdb)" \
        GOMODCACHE="$WORK_ROOT/gomod" GOCACHE="$WORK_ROOT/gocache" \
        "$GO_BIN" mod download -x
      env -i HOME="${HOME:-/tmp}" PATH="$CLEAN_PATH" GOFLAGS=-modcacherw GOTOOLCHAIN=local GOWORK=off \
        GOPROXY="$(manifest_value goproxy)" GOSUMDB="$(manifest_value gosumdb)" \
        GOMODCACHE="$WORK_ROOT/gomod" GOCACHE="$WORK_ROOT/gocache" \
        "$GO_BIN" build -mod=readonly -o "$WORK_ROOT/bin/$tool" .
    ) >>"$EVIDENCE_DIR/build.log" 2>>"$EVIDENCE_DIR/module-downloads.log" || \
      fail B001-E05 "tool=$tool module=$source_dir reason=isolated_build_failed"
    [ -x "$WORK_ROOT/bin/$tool" ] || fail B001-E05 "tool=$tool reason=binary_missing"
    printf 'tool=%s module=%s result=PASS\n' "$tool" "$source_dir" >>"$EVIDENCE_DIR/build.log"
    metadata_tmp="$WORK_ROOT/$tool.metadata"
    "$GO_BIN" version -m "$WORK_ROOT/bin/$tool" >"$metadata_tmp" || \
      fail B001-E07 "tool=$tool metadata=unreadable"
    sed 's/[[:space:]]*$//' "$metadata_tmp" >"$EVIDENCE_DIR/metadata/$tool.txt" || \
      fail B001-E07 "tool=$tool metadata=normalization_failed"
  done
  BASE001_METADATA_ROOT="$EVIDENCE_DIR/metadata"
  export BASE001_METADATA_ROOT
}

check_build() {
  check_environment_contract
  if [ "${BASE001_TEST_MODE:-0}" = 1 ]; then
    check_fixture_build
  else
    check_real_build
  fi
}

check_metadata() {
  metadata_root=${BASE001_METADATA_ROOT:-${BASE001_FIXTURE_ROOT:-}/metadata}
  [ -d "$metadata_root" ] || fail B001-E07 "metadata_root=$metadata_root reason=missing"
  tool_source_sha=$(manifest_value tool_source_sha)
  root_dep_version=$(manifest_value root_dep_version)
  root_dep_sha=$(manifest_value root_dep_sha)
  dual_approved=$(manifest_value dual_sha_difference_approved)
  if [ "$tool_source_sha" != "$root_dep_sha" ] && [ "$dual_approved" != true ]; then
    fail B001-E06 "tool_source_sha=$tool_source_sha root_dep_sha=$root_dep_sha dual_sha_difference_approved=$dual_approved"
  fi

  for tool in $TOOLS; do
    file="$metadata_root/$tool.txt"
    [ -r "$file" ] || fail B001-E07 "tool=$tool metadata=missing"
    if grep -F 'gitlab.allinfinance.com/aifgo/ag-core' "$file" >/dev/null 2>&1; then
      fail B001-E03 "tool=$tool forbidden_path=gitlab.allinfinance.com/aifgo/ag-core metadata=$file"
    fi
    if grep -E '^[[:space:]]*replace[[:space:]]+github.com/aif-go/ag-core[[:space:]]+' "$file" >/dev/null 2>&1; then
      fail B001-E04 "tool=$tool replace=github.com/aif-go/ag-core go.work=forbidden reason=local_masking"
    fi
    grep -F 'vcs.modified=false' "$file" >/dev/null 2>&1 || \
      fail B001-E07 "tool=$tool vcs.modified=missing_or_true"
    grep -F "vcs.revision=$tool_source_sha" "$file" >/dev/null 2>&1 || \
      fail B001-E07 "tool=$tool vcs.revision=missing_or_mismatch expected=$tool_source_sha"

    case "$tool" in
      protoc-gen-go-*)
        grep -E "^[[:space:]]*dep[[:space:]]+github.com/aif-go/ag-core[[:space:]]+$root_dep_version([[:space:]]|$)" "$file" >/dev/null 2>&1 || \
          fail B001-E06 "tool=$tool root_dep_version=$root_dep_version root_dep_sha=$root_dep_sha reason=metadata_mismatch"
        ;;
    esac
  done
}

check_evidence() {
  check_environment_contract
  [ "$(manifest_value release_approved)" = true ] || fail B001-E09 "release_approved=$(manifest_value release_approved)"
  [ "$(manifest_value manifest_signed)" = true ] || fail B001-E09 "manifest_signed=$(manifest_value manifest_signed)"
  [ -n "$(manifest_value manifest_approved_by)" ] || fail B001-E09 'manifest_approved_by=missing'
  [ "$(manifest_value ref_protection_required)" = true ] || fail B001-E09 'ref_protection_required=false'

  for file in manifest-signature.txt ref-protection.txt rollback.md traceability.md owner-and-time.txt negative-results.log build.log module-downloads.log; do
    [ -s "$EVIDENCE_DIR/$file" ] || fail B001-E09 "evidence_file=$file reason=missing_or_empty"
  done
  for tool in $TOOLS; do
    [ -s "$EVIDENCE_DIR/metadata/$tool.txt" ] || fail B001-E07 "tool=$tool evidence_metadata=missing"
  done

  if [ "${BASE001_TEST_MODE:-0}" = 1 ]; then
    grep -F 'protected=true' "$BASE001_FIXTURE_ROOT/ref-protection.tsv" >/dev/null 2>&1 || \
      fail B001-E09 'ref_protection=missing protected=true'
    if grep -F 'force_move=true' "$BASE001_FIXTURE_ROOT/ref-protection.tsv" >/dev/null 2>&1; then
      fail B001-E09 'ref_protection=invalid force_move=true'
    fi
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest) [ "$#" -ge 2 ] || usage; MANIFEST=$2; shift 2 ;;
    --evidence-dir) [ "$#" -ge 2 ] || usage; EVIDENCE_DIR=$2; shift 2 ;;
    --remote-url) [ "$#" -ge 2 ] || usage; REMOTE_URL=$2; shift 2 ;;
    --check) [ "$#" -ge 2 ] || usage; CHECK=$2; shift 2 ;;
    *) usage ;;
  esac
done

[ -r "$MANIFEST" ] || fail B001-E09 "manifest=$MANIFEST reason=missing"
[ -n "$EVIDENCE_DIR" ] || usage
REMOTE_URL=${REMOTE_URL:-$(manifest_value canonical_remote)}

case "$CHECK" in
  refs) check_refs; pass BASE-001-P01 ;;
  build) check_build; pass BASE-001-P02 ;;
  metadata) check_metadata; pass BASE-001-P03 ;;
  evidence) check_evidence; pass BASE-001-P04 ;;
  all)
    if [ "${BASE001_TEST_MODE:-0}" = 1 ]; then
      # Deterministic fixtures classify provenance faults before their deliberately
      # inconsistent synthetic ref table can collapse them into a generic E02.
      check_metadata
      check_refs
      check_build
    else
      check_refs
      check_build
      check_metadata
    fi
    check_evidence
    pass BASE-001
    ;;
  *) usage ;;
esac
