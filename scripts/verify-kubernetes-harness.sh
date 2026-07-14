#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ENV_DIR="$ROOT/tests/acceptance/baseline/environments"
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}

grep -q 'kindest/node@sha256:4613778f3cfcd10e615029370f5786704559103cf27bef934597ba562b269661' "$ENV_DIR/kind-config.yaml"
grep -q 'provisioner: hostpath.csi.k8s.io' "$ENV_DIR/kubernetes-smoke.yaml"
grep -q 'storageClassName: ai-video-hostpath-csi' "$ENV_DIR/kubernetes-smoke.yaml"
grep -q 'busybox@sha256:9532d8c39891ca2ecde4d30d7710e01fb739c87a8b9299685c63704296b16028' "$ENV_DIR/kubernetes-smoke.yaml"
if grep -RE 'image:[[:space:]]+[^@[:space:]]+(:latest)?$' "$ENV_DIR"; then
  printf 'floating Kubernetes image found\n' >&2
  exit 1
fi
if grep -RE 'kind:[[:space:]]+Deployment' "$ENV_DIR"; then
  printf 'business Deployment is outside Story 1.2 scope\n' >&2
  exit 1
fi

{
  printf 'field\tvalue\n'
  printf 'static_contract\tPASS\n'
  printf 'kubernetes_version\t1.35.0\n'
  printf 'kind_node_digest\tsha256:4613778f3cfcd10e615029370f5786704559103cf27bef934597ba562b269661\n'
  printf 'csi\thostpath-csi-1.17.0@sha256:e20e2681349cb892bc88d8ab23c6785949bdb7e9b518bf3a261b5f13034f8b3b\n'
  printf 'cluster_execution\tPENDING\n'
} >"$EVIDENCE/kubernetes-harness.tsv"
printf 'BASE-002 Kubernetes harness static contract PASS; cluster execution PENDING\n'
