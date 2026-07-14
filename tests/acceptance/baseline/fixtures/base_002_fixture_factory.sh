#!/usr/bin/env bash
# Deterministic local fixture factory for BASE-002 and NFR-DR-001.
set -eu

if [ "$#" -ne 2 ]; then
  printf 'usage: %s CASE_DIR VARIANT\n' "$0" >&2
  exit 64
fi

CASE_DIR=$1
VARIANT=$2
EVIDENCE="$CASE_DIR/evidence"
mkdir -p "$EVIDENCE" "$CASE_DIR/cache" "$CASE_DIR/work"

cat >"$CASE_DIR/baseline-manifest.yaml" <<'YAML'
schema_version: 1
baseline_id: BASE-002
base_001_status: Verified
ag_core_tool_source_sha: 3ad9bb9cf7106560400391b62a7f373f682cf591
ag_core_root_dep_version: v0.0.1-alpha.3
ag_core_root_dep_sha: 1624c77ab90b12b77191c38005b64d59f8a0029e
environment_scope: integration
internal_prod_status: Approved
manifest_signed: true
manifest_approved_by: architecture-sre-owner
release_approved: true
evidence_path: reports/baseline/BASE-002/
temporal_server_version: 1.27.2
temporal_go_sdk_version: 1.37.0
temporal_schema_version: 1.15
mysql_version: 8.4.5
mysql_image_digest: sha256:1111111111111111111111111111111111111111111111111111111111111111
kafka_version: 4.0.0
kafka_image_digest: sha256:2222222222222222222222222222222222222222222222222222222222222222
agsarama_version: v0.0.0-20260701000000-aaaaaaaaaaaa
nacos_version: 3.0.2
redis_version: 8.0.3
object_storage_product: minio
object_storage_version: RELEASE.2025-04-22T22-12-26Z
object_storage_image_digest: sha256:3333333333333333333333333333333333333333333333333333333333333333
ffmpeg_version: 8.1.2
ffmpeg_image_digest: sha256:4444444444444444444444444444444444444444444444444444444444444444
node_version: 24.4.1
node_image_digest: sha256:5555555555555555555555555555555555555555555555555555555555555555
package_manager: pnpm
package_manager_version: 10.13.1
react_version: 19.2.0
vite_version: 8.1.4
typescript_version: 5.8.3
kubernetes_version: 1.35.0
kubernetes_distribution: kind
cni_version: 1.6.2
csi_version: 1.11.0
ingress_version: 1.12.2
otel_collector_version: 0.129.1
ffprobe_version: 8.1.2
license_index: evidence/licenses.tsv
compatibility_matrix: evidence/compatibility-matrix.tsv
rollback_target: BASE-002-previous-verified
YAML

cat >"$EVIDENCE/licenses.tsv" <<'TSV'
component	license	status
temporal	MIT	approved
mysql	GPL-2.0	approved
kafka	Apache-2.0	approved
nacos	Apache-2.0	approved
redis	RSALv2-or-SSPLv1	approved
minio	AGPL-3.0	approved
ffmpeg	GPL-compatible-build-review	approved
node	MIT	approved
kubernetes	Apache-2.0	approved
TSV

cat >"$EVIDENCE/compatibility-matrix.tsv" <<'TSV'
component	combination	status
temporal	server-sdk-schema-mysql	PASS
kafka	broker-agsarama-kraft	PASS
nacos	ag-core-config	PASS
redis	ag-core-cache-loss-semantics	PASS
object_storage	s3-version-encryption-checksum	PASS
kubernetes	distribution-cni-csi-ingress	PASS
TSV

cat >"$EVIDENCE/isolation.tsv" <<'TSV'
resource	integration	internal_prod
namespace	ai-video-int	ai-video-prod
topic	ai-video-int-events	ai-video-prod-events
database	ai_video_int	ai_video_prod
bucket	ai-video-int	ai-video-prod
secret	ai-video-int-secret	ai-video-prod-secret
TSV

cat >"$EVIDENCE/web-build.tsv" <<'TSV'
field	run1	run2
lockfile_digest	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dependency_tree_digest	bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb	bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
artifact_digest	cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc	cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
lockfile_mutated	false	false
license_status	complete	complete
TSV

cat >"$EVIDENCE/media-report.tsv" <<'TSV'
field	value
playable	true
width	1080
height	1920
fps	30
container	mp4
video_codec	h264
audio_codec	aac
audio_hz	48000
subtitle_burned	true
subtitle_file	true
chinese_font	true
ai_label	true
metadata	true
TSV

cat >"$EVIDENCE/resilience.tsv" <<'TSV'
scenario	status	paid_progress
budget_unavailable	PASS	0
object_store_unavailable	PASS	0
quality_gate_unavailable	PASS	0
orchestrator_unavailable	PASS	0
rolling_upgrade	PASS	0
rollback	PASS	0
TSV

cat >"$EVIDENCE/dr-report.tsv" <<'TSV'
field	value
rpo_minutes	4
rto_minutes	90
mysql_pitr	PASS
temporal_restore	PASS
kafka_relationship	PASS
object_reference_consistent	true
TSV

cat >"$EVIDENCE/gate-decision.tsv" <<'TSV'
gate	status
g0_1	Verified
g0_2	Verified
story_1_3_allowed	true
TSV

printf '%s\n' 'owner=architecture-sre-owner approved=true' >"$EVIDENCE/owner-and-approval.txt"
printf '%s\n' 'rollback=BASE-002-previous-verified preserve_failed_candidate=true' >"$EVIDENCE/rollback.md"

replace_manifest_value() {
  key=$1
  value=$2
  awk -v target="$key:" -v replacement="$key: $value" '$1 == target { print replacement; next } { print }' \
    "$CASE_DIR/baseline-manifest.yaml" >"$CASE_DIR/baseline-manifest.yaml.next"
  mv "$CASE_DIR/baseline-manifest.yaml.next" "$CASE_DIR/baseline-manifest.yaml"
}

case "$VARIANT" in
  valid) ;;
  missing_field) replace_manifest_value temporal_server_version '' ;;
  floating_ref) replace_manifest_value ffmpeg_image_digest latest ;;
  incompatible_stack)
    awk 'BEGIN { FS=OFS="\t" } $1 == "temporal" { $3="FAIL" } { print }' "$EVIDENCE/compatibility-matrix.tsv" >"$EVIDENCE/compatibility-matrix.tsv.next"
    mv "$EVIDENCE/compatibility-matrix.tsv.next" "$EVIDENCE/compatibility-matrix.tsv"
    ;;
  shared_environment)
    awk 'BEGIN { FS=OFS="\t" } $1 == "namespace" { $3=$2 } { print }' "$EVIDENCE/isolation.tsv" >"$EVIDENCE/isolation.tsv.next"
    mv "$EVIDENCE/isolation.tsv.next" "$EVIDENCE/isolation.tsv"
    ;;
  unsafe_progress)
    awk 'BEGIN { FS=OFS="\t" } $1 == "budget_unavailable" { $2="FAIL"; $3=1 } { print }' "$EVIDENCE/resilience.tsv" >"$EVIDENCE/resilience.tsv.next"
    mv "$EVIDENCE/resilience.tsv.next" "$EVIDENCE/resilience.tsv"
    ;;
  invalid_media)
    awk 'BEGIN { FS=OFS="\t" } $1 == "width" { $2=720 } $1 == "ai_label" { $2="false" } { print }' "$EVIDENCE/media-report.tsv" >"$EVIDENCE/media-report.tsv.next"
    mv "$EVIDENCE/media-report.tsv.next" "$EVIDENCE/media-report.tsv"
    ;;
  dr_threshold)
    awk 'BEGIN { FS=OFS="\t" } $1 == "rpo_minutes" { $2=8 } { print }' "$EVIDENCE/dr-report.tsv" >"$EVIDENCE/dr-report.tsv.next"
    mv "$EVIDENCE/dr-report.tsv.next" "$EVIDENCE/dr-report.tsv"
    ;;
  premature_release)
    awk 'BEGIN { FS=OFS="\t" } $1 == "g0_2" { $2="Open" } { print }' "$EVIDENCE/gate-decision.tsv" >"$EVIDENCE/gate-decision.tsv.next"
    mv "$EVIDENCE/gate-decision.tsv.next" "$EVIDENCE/gate-decision.tsv"
    ;;
  *) printf 'unknown BASE-002 fixture variant: %s\n' "$VARIANT" >&2; exit 65 ;;
esac
