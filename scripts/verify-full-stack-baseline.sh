#!/usr/bin/env bash
# BASE-002 authoritative full-stack baseline gate.
set -eu

CHECK=all
MANIFEST=
EVIDENCE_DIR=

usage() {
  printf 'usage: %s --manifest FILE --evidence-dir DIR [--check manifest|isolation|compatibility|web|media|resilience|dr|all]\n' "$0" >&2
  exit 64
}

fail() { code=$1; shift; printf '%s %s\n' "$code" "$*" >&2; exit 1; }
pass() { printf '%s PASS\n' "$1"; }

manifest_value() {
  key=$1
  awk -v target="$key:" '$1 == target { sub(/^[^:]+:[[:space:]]*/, ""); gsub(/^[\047\"]|[\047\"]$/, ""); print; exit }' "$MANIFEST"
}

require_value() {
  key=$1
  value=$(manifest_value "$key")
  [ -n "$value" ] || fail B002-E01 "component=$key reason=missing_or_empty"
  case "$value" in TODO|TBD|PLACEHOLDER|pending|PENDING) fail B002-E01 "component=$key value=$value reason=placeholder" ;; esac
  printf '%s\n' "$value"
}

require_file() {
  file=$1
  [ -s "$EVIDENCE_DIR/$file" ] || fail B002-E01 "component=evidence file=$file reason=missing_or_empty"
}

check_manifest() {
  [ "$(require_value schema_version)" = 1 ] || fail B002-E01 'component=schema_version expected=1'
  [ "$(require_value baseline_id)" = BASE-002 ] || fail B002-E01 'component=baseline_id expected=BASE-002'
  [ "$(require_value base_001_status)" = Verified ] || fail B002-E08 "g0_1=$(manifest_value base_001_status) expected=Verified"
  [ "$(require_value ag_core_tool_source_sha)" = 3ad9bb9cf7106560400391b62a7f373f682cf591 ] || fail B002-E03 'component=ag_core_tool_source_sha reason=BASE-001_mismatch'
  [ "$(require_value ag_core_root_dep_version)" = v0.0.1-alpha.3 ] || fail B002-E03 'component=ag_core_root_dep_version reason=BASE-001_mismatch'
  [ "$(require_value ag_core_root_dep_sha)" = 1624c77ab90b12b77191c38005b64d59f8a0029e ] || fail B002-E03 'component=ag_core_root_dep_sha reason=BASE-001_mismatch'
  [ "$(require_value environment_scope)" = integration ] || fail B002-E01 'component=environment_scope expected=integration'
  case "$(require_value internal_prod_status)" in Open|Approved) ;; *) fail B002-E01 'component=internal_prod_status expected=Open_or_Approved' ;; esac
  [ "$(require_value manifest_signed)" = true ] || fail B002-E01 'component=manifest_signed expected=true'
  require_value manifest_approved_by >/dev/null
  [ "$(require_value release_approved)" = true ] || fail B002-E01 'component=release_approved expected=true'

  required='temporal_server_version temporal_go_sdk_version temporal_schema_version mysql_version mysql_image_digest kafka_version kafka_image_digest agsarama_version nacos_version redis_version object_storage_product object_storage_version object_storage_image_digest ffmpeg_version ffmpeg_image_digest node_version node_image_digest package_manager package_manager_version react_version vite_version typescript_version kubernetes_version kubernetes_distribution cni_version csi_version ingress_version otel_collector_version ffprobe_version license_index compatibility_matrix rollback_target'
  for key in $required; do
    value=$(require_value "$key")
    case "$value" in latest|edge|main|master|develop|nightly|*:latest) fail B002-E02 "component=$key image_digest=$value reason=floating_ref" ;; esac
  done

  for key in mysql_image_digest kafka_image_digest object_storage_image_digest ffmpeg_image_digest node_image_digest; do
    value=$(manifest_value "$key")
    printf '%s\n' "$value" | grep -E '^sha256:[0-9a-f]{64}$' >/dev/null 2>&1 || \
      fail B002-E02 "component=$key image_digest=$value reason=not_immutable_digest"
  done

  require_file licenses.tsv
  awk -F '\t' 'NR > 1 && $3 !~ /^approved/ { exit 1 }' "$EVIDENCE_DIR/licenses.tsv" || \
    fail B002-E01 'component=license status=unapproved'
}

check_compatibility() {
  require_file compatibility-matrix.tsv
  bad=$(awk -F '\t' 'NR > 1 && $3 != "PASS" { print $1; exit }' "$EVIDENCE_DIR/compatibility-matrix.tsv")
  [ -z "$bad" ] || fail B002-E03 "component=$bad compatibility=FAIL"
  for component in temporal kafka nacos redis object_storage kubernetes; do
    grep -F "${component}"$'\t' "$EVIDENCE_DIR/compatibility-matrix.tsv" >/dev/null 2>&1 || \
      fail B002-E03 "component=$component compatibility=missing"
  done
}

check_isolation() {
  require_file isolation.tsv
  bad=$(awk -F '\t' 'NR > 1 && ($2 == "" || $3 == "" || $2 == $3) { print $1; exit }' "$EVIDENCE_DIR/isolation.tsv")
  [ -z "$bad" ] || fail B002-E04 "resource=$bad namespace=$bad reason=shared_environment"
  for resource in namespace topic database bucket secret; do
    grep -F "${resource}"$'\t' "$EVIDENCE_DIR/isolation.tsv" >/dev/null 2>&1 || \
      fail B002-E04 "resource=$resource namespace=missing"
  done
}

report_value() { awk -F '\t' -v key="$2" '$1 == key { print $2; exit }' "$1"; }

check_web() {
  require_file web-build.tsv
  bad=$(awk -F '\t' 'NR > 1 && ($2 != $3) { print $1; exit }' "$EVIDENCE_DIR/web-build.tsv")
  [ -z "$bad" ] || fail B002-E03 "component=web field=$bad reason=double_run_mismatch"
  grep -F $'lockfile_mutated\tfalse\tfalse' "$EVIDENCE_DIR/web-build.tsv" >/dev/null 2>&1 || \
    fail B002-E03 'component=web field=lockfile_mutated expected=false'
  grep -F $'license_status\tcomplete\tcomplete' "$EVIDENCE_DIR/web-build.tsv" >/dev/null 2>&1 || \
    fail B002-E03 'component=web field=license_status expected=complete'
}

check_media() {
  require_file media-report.tsv
  file="$EVIDENCE_DIR/media-report.tsv"
  [ "$(report_value "$file" playable)" = true ] || fail B002-E06 'media=playable expected=true'
  [ "$(report_value "$file" width)" = 1080 ] || fail B002-E06 "media=width actual=$(report_value "$file" width) expected=1080"
  [ "$(report_value "$file" height)" = 1920 ] || fail B002-E06 "media=height actual=$(report_value "$file" height) expected=1920"
  [ "$(report_value "$file" fps)" = 30 ] || fail B002-E06 "media=fps actual=$(report_value "$file" fps) expected=30"
  [ "$(report_value "$file" container)" = mp4 ] || fail B002-E06 'media=container expected=mp4'
  [ "$(report_value "$file" video_codec)" = h264 ] || fail B002-E06 'media=video_codec expected=h264'
  [ "$(report_value "$file" audio_codec)" = aac ] || fail B002-E06 'media=audio_codec expected=aac'
  [ "$(report_value "$file" audio_hz)" = 48000 ] || fail B002-E06 'media=audio_hz expected=48000'
  for field in subtitle_burned subtitle_file chinese_font ai_label metadata; do
    [ "$(report_value "$file" "$field")" = true ] || fail B002-E06 "media=$field expected=true"
  done
}

check_resilience() {
  require_file resilience.tsv
  bad=$(awk -F '\t' 'NR > 1 && ($2 != "PASS" || $3 != 0) { print $1 "\t" $2 "\t" $3; exit }' "$EVIDENCE_DIR/resilience.tsv")
  [ -z "$bad" ] || fail B002-E05 \
    "scenario=$(printf '%s' "$bad" | cut -f1) status=$(printf '%s' "$bad" | cut -f2) paid_progress=$(printf '%s' "$bad" | cut -f3) expected_status=PASS expected_paid_progress=0"
  for scenario in budget_unavailable object_store_unavailable quality_gate_unavailable orchestrator_unavailable rolling_upgrade rollback; do
    grep -F "${scenario}"$'\t' "$EVIDENCE_DIR/resilience.tsv" >/dev/null 2>&1 || \
      fail B002-E05 "scenario=$scenario paid_progress=missing"
  done
}

check_dr() {
  require_file dr-report.tsv
  file="$EVIDENCE_DIR/dr-report.tsv"
  rpo=$(report_value "$file" rpo_minutes)
  rto=$(report_value "$file" rto_minutes)
  [ -n "$rpo" ] && [ "$rpo" -le 5 ] 2>/dev/null || fail B002-E07 "rpo_minutes=$rpo expected_max=5"
  [ -n "$rto" ] && [ "$rto" -le 120 ] 2>/dev/null || fail B002-E07 "rto_minutes=$rto expected_max=120"
  for field in mysql_pitr temporal_restore kafka_relationship; do
    [ "$(report_value "$file" "$field")" = PASS ] || fail B002-E07 "$field=$(report_value "$file" "$field") expected=PASS"
  done
  [ "$(report_value "$file" object_reference_consistent)" = true ] || fail B002-E07 'object_reference_consistent=false'
}

check_aggregate() {
  require_file gate-decision.tsv
  file="$EVIDENCE_DIR/gate-decision.tsv"
  [ "$(report_value "$file" g0_1)" = Verified ] || fail B002-E08 "g0_1=$(report_value "$file" g0_1)"
  [ "$(report_value "$file" g0_2)" = Verified ] || fail B002-E08 "g0_2=$(report_value "$file" g0_2)"
  [ "$(report_value "$file" story_1_3_allowed)" = true ] || fail B002-E08 'story_1_3_allowed=false'
  [ "$(manifest_value internal_prod_status)" = Approved ] || fail B002-E08 'internal_prod_status=Open'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest) [ "$#" -ge 2 ] || usage; MANIFEST=$2; shift 2 ;;
    --evidence-dir) [ "$#" -ge 2 ] || usage; EVIDENCE_DIR=$2; shift 2 ;;
    --check) [ "$#" -ge 2 ] || usage; CHECK=$2; shift 2 ;;
    *) usage ;;
  esac
done

[ -r "$MANIFEST" ] || fail B002-E01 "component=manifest file=$MANIFEST reason=missing"
[ -d "$EVIDENCE_DIR" ] || fail B002-E01 "component=evidence directory=$EVIDENCE_DIR reason=missing"

case "$CHECK" in
  manifest) check_manifest; pass BASE-002-P01 ;;
  isolation) check_isolation; pass BASE-002-P02 ;;
  compatibility) check_compatibility; pass BASE-002-P03 ;;
  web) check_web; pass BASE-002-P04 ;;
  media) check_media; pass BASE-002-P05 ;;
  resilience) check_resilience; pass BASE-002-P06 ;;
  dr) check_dr; pass NFR-DR-001-S01 ;;
  all)
    check_manifest
    check_compatibility
    check_isolation
    check_web
    check_media
    check_resilience
    check_dr
    check_aggregate
    pass BASE-002
    ;;
  *) usage ;;
esac
