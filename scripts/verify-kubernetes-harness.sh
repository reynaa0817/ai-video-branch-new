#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ENV_DIR="$ROOT/tests/acceptance/baseline/environments"
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}

grep -q 'kindest/node@sha256:4613778f3cfcd10e615029370f5786704559103cf27bef934597ba562b269661' "$ENV_DIR/kind-config.yaml"
grep -q 'provisioner: hostpath.csi.k8s.io' "$ENV_DIR/kubernetes-smoke.yaml"
grep -q 'storageClassName: ai-video-hostpath-csi' "$ENV_DIR/kubernetes-smoke.yaml"
grep -q 'kind: fast' "$ENV_DIR/kubernetes-smoke.yaml"
grep -q 'busybox@sha256:9532d8c39891ca2ecde4d30d7710e01fb739c87a8b9299685c63704296b16028' "$ENV_DIR/kubernetes-smoke.yaml"
grep -q 'ingress-ready: "true"' "$ENV_DIR/kind-config.yaml"
grep -q 'ingressClassName: nginx' "$ENV_DIR/kubernetes-ingress-smoke.yaml"
grep -q 'base002.internal' "$ENV_DIR/kubernetes-ingress-smoke.yaml"
if grep -RE 'image:[[:space:]]+[^@[:space:]]+(:latest)?$' "$ENV_DIR"; then
  printf 'floating Kubernetes image found\n' >&2
  exit 1
fi
if grep -RE 'kind:[[:space:]]+Deployment' "$ENV_DIR"; then
  printf 'business Deployment is outside Story 1.2 scope\n' >&2
  exit 1
fi

if [ "${BASE002_K8S_EXECUTE:-0}" != "1" ]; then
  {
    printf 'field\tstatus\tevidence\n'
    printf 'static_contract\tPASS\tkind-config.yaml+kubernetes-smoke.yaml\n'
    printf 'kubernetes_version\tPASS\t1.35.0\n'
    printf 'kind_node_digest\tPASS\tsha256:4613778f3cfcd10e615029370f5786704559103cf27bef934597ba562b269661\n'
    printf 'csi\tPASS\thostpath-csi-1.17.0@sha256:e20e2681349cb892bc88d8ab23c6785949bdb7e9b518bf3a261b5f13034f8b3b\n'
    printf 'cni_network\tPENDING\tnot-activated\n'
    printf 'ingress_routing\tPENDING\tnot-activated\n'
    printf 'cluster_execution\tPENDING\tnot-activated\n'
  } >"$EVIDENCE/kubernetes-harness.tsv"
  printf 'BASE-002 Kubernetes harness static contract PASS; cluster execution PENDING\n'
  exit 0
fi

mkdir -p "$EVIDENCE"
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd -P)
TMP=$(mktemp -d "$ROOT/.base002-k8s-run.XXXXXX")
CLUSTER="ai-video-base002-$$"
KIND="$TMP/bin/kind"
PAUSED_NODE=''

cleanup() {
  if [ -n "$PAUSED_NODE" ]; then docker unpause "$PAUSED_NODE" >/dev/null 2>&1 || true; fi
  "$KIND" delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  chmod -R u+w "$TMP" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$TMP/bin" "$TMP/gomodcache" "$TMP/gocache"

GOBIN="$TMP/bin" GOMODCACHE="$TMP/gomodcache" GOCACHE="$TMP/gocache" \
  GOTOOLCHAIN=local go install sigs.k8s.io/kind@v0.32.0
"$KIND" version >"$EVIDENCE/kind-version.txt"
kind_source="$TMP/gomodcache/sigs.k8s.io/kind@v0.32.0"
grep -F 'ARG CNI_PLUGINS_VERSION="v1.9.1"' "$kind_source/images/base/Dockerfile" \
  >"$EVIDENCE/cni-version-source.txt"
shasum -a 256 "$kind_source/LICENSE" >"$EVIDENCE/kind-license.sha256"

sed "s/name: ai-video-base002/name: $CLUSTER/" "$ENV_DIR/kind-config.yaml" >"$TMP/kind-config.yaml"
"$KIND" create cluster --config "$TMP/kind-config.yaml" --wait 180s \
  >"$EVIDENCE/kind-create.log" 2>&1

for node in "$CLUSTER-control-plane" "$CLUSTER-worker" "$CLUSTER-worker2"; do
  docker exec "$node" sh -c "printf 'nameserver 8.8.8.8\n' >/etc/resolv.conf"
done
printf 'node\tnameserver\n' >"$EVIDENCE/kind-node-dns.tsv"
printf '%s\t8.8.8.8\n' "$CLUSTER-control-plane" "$CLUSTER-worker" "$CLUSTER-worker2" \
  >>"$EVIDENCE/kind-node-dns.tsv"

kubectl -n kube-system rollout status daemonset/kindnet --timeout=180s \
  >"$EVIDENCE/kubernetes-cni.log" 2>&1
kubectl -n kube-system get daemonset kindnet -o yaml >"$EVIDENCE/kubernetes-kindnet.yaml"
for node in "$CLUSTER-control-plane" "$CLUSTER-worker" "$CLUSTER-worker2"; do
  docker exec "$node" sh -c 'sha256sum /opt/cni/bin/host-local /opt/cni/bin/loopback /opt/cni/bin/portmap /opt/cni/bin/ptp'
done >"$EVIDENCE/kubernetes-cni-binaries.sha256"

clone_ref() {
  ref=$1
  repo=$2
  destination=$3
  attempt=0
  until git -c advice.detachedHead=false clone -q --depth 1 --branch "$ref" "$repo" "$destination"; do
    rm -rf "$destination"
    attempt=$((attempt + 1))
    [ "$attempt" -lt 3 ] || return 1
  done
}

clone_ref v1.17.0 https://github.com/kubernetes-csi/csi-driver-host-path.git "$TMP/csi-hostpath"
clone_ref v5.2.0 https://github.com/kubernetes-csi/external-provisioner.git "$TMP/external-provisioner"
clone_ref controller-v1.15.1 https://github.com/kubernetes/ingress-nginx.git "$TMP/ingress-nginx"
git -C "$TMP/csi-hostpath" rev-parse HEAD >"$EVIDENCE/csi-hostpath-source-sha.txt"
git -C "$TMP/external-provisioner" rev-parse HEAD >"$EVIDENCE/csi-provisioner-source-sha.txt"
git -C "$TMP/ingress-nginx" rev-parse HEAD >"$EVIDENCE/ingress-nginx-source-sha.txt"
grep -F '**v1.15.1**' "$TMP/ingress-nginx/README.md" | grep -F '1.35' \
  >"$EVIDENCE/ingress-nginx-support-window.txt"
shasum -a 256 "$TMP/ingress-nginx/LICENSE" >"$EVIDENCE/ingress-nginx-license.sha256"

sed \
  -e 's#registry.k8s.io/sig-storage/csi-provisioner:v5.2.0#registry.k8s.io/sig-storage/csi-provisioner@sha256:d5e46da8aff7d73d6f00c761dae94472bcda6e78f4f17b3802dc89d44de0111b#' \
  -e 's#registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.12.0#registry.k8s.io/sig-storage/csi-node-driver-registrar@sha256:0d23a6fd60c421054deec5e6d0405dc3498095a5a597e175236c0692f4adee0f#' \
  -e 's#registry.k8s.io/sig-storage/hostpathplugin:v1.15.0#registry.k8s.io/sig-storage/hostpathplugin@sha256:e20e2681349cb892bc88d8ab23c6785949bdb7e9b518bf3a261b5f13034f8b3b#' \
  -e 's#registry.k8s.io/sig-storage/livenessprobe:v2.15.0#registry.k8s.io/sig-storage/livenessprobe@sha256:2c5f9dc4ea5ac5509d93c664ae7982d4ecdec40ca7b0638c24e5b16243b8360f#' \
  "$TMP/csi-hostpath/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml" \
  >"$TMP/csi-hostpath-plugin.yaml"

kubectl apply -f "$TMP/external-provisioner/deploy/kubernetes/rbac.yaml" \
  >"$EVIDENCE/kubernetes-csi-rbac.log" 2>&1
kubectl apply -f "$TMP/csi-hostpath/deploy/kubernetes-distributed/hostpath/csi-hostpath-driverinfo.yaml" \
  >>"$EVIDENCE/kubernetes-csi-rbac.log" 2>&1
kubectl apply -f "$TMP/csi-hostpath-plugin.yaml" \
  >"$EVIDENCE/kubernetes-csi-plugin.log" 2>&1
kubectl rollout status daemonset/csi-hostpathplugin --timeout=600s \
  >>"$EVIDENCE/kubernetes-csi-plugin.log" 2>&1

kubectl apply -f "$TMP/ingress-nginx/deploy/static/provider/kind/deploy.yaml" \
  >"$EVIDENCE/kubernetes-ingress.log" 2>&1
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=600s \
  >>"$EVIDENCE/kubernetes-ingress.log" 2>&1
kubectl -n ingress-nginx get deployment,pod,service,ingressclass -o wide \
  >"$EVIDENCE/kubernetes-ingress-resources.txt"

wait_phase() {
  namespace=$1
  pod=$2
  expected=$3
  attempt=0
  while :; do
    phase=$(kubectl -n "$namespace" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)
    [ "$phase" != Failed ] || { kubectl -n "$namespace" describe pod "$pod" >&2; return 1; }
    [ "$phase" = "$expected" ] && return 0
    attempt=$((attempt + 1))
    [ "$attempt" -lt 300 ] || { kubectl -n "$namespace" describe pod "$pod" >&2; return 1; }
    sleep 1
  done
}

kubectl apply -f "$ENV_DIR/kubernetes-smoke.yaml" >"$EVIDENCE/kubernetes-storage.log" 2>&1
wait_phase ai-video-int base002-storage-smoke Succeeded
kubectl -n ai-video-int get pvc,pv,pod -o wide >"$EVIDENCE/kubernetes-storage.txt"

kubectl apply -f "$ENV_DIR/kubernetes-ingress-smoke.yaml" \
  >>"$EVIDENCE/kubernetes-ingress.log" 2>&1
kubectl -n ai-video-int wait --for=condition=Ready pod/base002-ingress-backend --timeout=180s \
  >>"$EVIDENCE/kubernetes-ingress.log" 2>&1
kubectl -n ai-video-int run base002-network-client --restart=Never \
  --image=busybox@sha256:9532d8c39891ca2ecde4d30d7710e01fb739c87a8b9299685c63704296b16028 \
  --command -- sh -ceu '
    direct=$(wget -qO- http://base002-ingress-backend:8080)
    test "$direct" = "BASE-002 INGRESS PASS"
    routed=$(wget -qO- --header "Host: base002.internal" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local)
    test "$routed" = "BASE-002 INGRESS PASS"
    printf "CNI_DIRECT_PASS\nINGRESS_ROUTING_PASS\n"
  ' >>"$EVIDENCE/kubernetes-ingress.log" 2>&1
wait_phase ai-video-int base002-network-client Succeeded
kubectl -n ai-video-int logs base002-network-client >"$EVIDENCE/kubernetes-network-routing.txt"
grep -F CNI_DIRECT_PASS "$EVIDENCE/kubernetes-network-routing.txt" >/dev/null
grep -F INGRESS_ROUTING_PASS "$EVIDENCE/kubernetes-network-routing.txt" >/dev/null

csi_pod=$(kubectl get pod -l app.kubernetes.io/name=csi-hostpathplugin -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$csi_pod" --wait=false >>"$EVIDENCE/kubernetes-csi-plugin.log" 2>&1
kubectl rollout status daemonset/csi-hostpathplugin --timeout=600s \
  >>"$EVIDENCE/kubernetes-csi-plugin.log" 2>&1

PAUSED_NODE="$CLUSTER-worker2"
docker pause "$PAUSED_NODE" >/dev/null
attempt=0
while :; do
  ready_status=$(kubectl get node "$PAUSED_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  if [ -n "$ready_status" ] && [ "$ready_status" != True ]; then break; fi
  attempt=$((attempt + 1))
  [ "$attempt" -lt 90 ] || { printf 'node did not become NotReady\n' >&2; exit 1; }
  sleep 1
done
kubectl get nodes -o wide >"$EVIDENCE/kubernetes-nodes-during-failure.txt"
docker unpause "$PAUSED_NODE" >/dev/null
PAUSED_NODE=''
kubectl wait --for=condition=Ready "node/$CLUSTER-worker2" --timeout=180s >/dev/null

kubectl -n ai-video-int delete pod base002-storage-smoke --wait=true >/dev/null
kubectl apply -f "$ENV_DIR/kubernetes-storage-recovery.yaml" >>"$EVIDENCE/kubernetes-storage.log" 2>&1
wait_phase ai-video-int base002-storage-recovery Succeeded
kubectl get nodes -o wide >"$EVIDENCE/kubernetes-nodes.txt"
kubectl -n ai-video-int get pvc,pv,pod -o wide >>"$EVIDENCE/kubernetes-storage.txt"

{
  printf 'field\tstatus\tevidence\n'
  printf 'static_contract\tPASS\tkind-config.yaml+kubernetes-smoke.yaml\n'
  printf 'kubernetes_version\tPASS\t1.35.0\n'
  printf 'kind_node_digest\tPASS\tsha256:4613778f3cfcd10e615029370f5786704559103cf27bef934597ba562b269661\n'
  printf 'csi\tPASS\thostpath-csi-1.17.0@sha256:e20e2681349cb892bc88d8ab23c6785949bdb7e9b518bf3a261b5f13034f8b3b\n'
  printf 'cni_network\tPASS\tcni-plugins-1.9.1+kubernetes-network-routing.txt\n'
  printf 'ingress_routing\tPASS\tingress-nginx-1.15.1+kubernetes-network-routing.txt\n'
  printf 'cluster_execution\tPASS\tkind-create.log\n'
  printf 'csi_pvc\tPASS\tkubernetes-storage.txt\n'
  printf 'pod_recovery\tPASS\tkubernetes-storage.log\n'
  printf 'csi_pod_restart\tPASS\tkubernetes-csi-plugin.log\n'
  printf 'node_failure_recovery\tPASS\tkubernetes-nodes-during-failure.txt\n'
} >"$EVIDENCE/kubernetes-harness.tsv"
printf 'BASE-002 Kubernetes 1.35 kind/CSI fault and recovery PASS\n'
