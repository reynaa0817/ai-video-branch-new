#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d "$ROOT/.base002-kubernetes.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

BASE002_K8S_EXECUTE=1 bash "$ROOT/scripts/verify-kubernetes-harness.sh" "$TMP"

for field in cluster_execution cni_network ingress_routing csi_pvc pod_recovery \
  csi_pod_restart node_failure_recovery; do
  awk -F '\t' -v field="$field" '$1 == field && $2 == "PASS" { found=1 } END { exit !found }' \
    "$TMP/kubernetes-harness.tsv"
done

test -s "$TMP/kubernetes-nodes.txt"
test -s "$TMP/kubernetes-storage.txt"
printf 'BASE-002 Kubernetes 1.35 kind/CSI fault and recovery PASS\n'
